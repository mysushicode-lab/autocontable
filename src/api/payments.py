"""Stripe payment integration

References:
- Stripe Checkout: https://docs.stripe.com/api/checkout/sessions/create
- Stripe Webhooks: https://docs.stripe.com/webhooks
- Stripe Subscriptions: https://docs.stripe.com/billing/subscriptions/overview

NOTE: This file is named payments.py instead of stripe.py to avoid
conflict with the `stripe` package import.
"""
import os
import logging
from datetime import datetime
from decimal import Decimal

import src.config  # noqa: F401
import stripe
from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel
from src.api.auth import get_current_user
from src.storage.database import db
from src.storage.models import Organization, Affiliate, Referral, ReferralStatus

logger = logging.getLogger(__name__)
router = APIRouter()

# Initialize Stripe with the secret key from environment
stripe.api_key = os.getenv('STRIPE_SECRET_KEY')
STRIPE_WEBHOOK_SECRET = os.getenv('STRIPE_WEBHOOK_SECRET', '')

# Plan hierarchy for determining upgrade vs downgrade
PLAN_ORDER = ['free', 'starter', 'pro', 'reseau']


class CreateCheckoutSessionRequest(BaseModel):
    plan_type: str  # 'pro' or other plan types


# ---------------------------------------------------------------------------
# Webhook handling
# ---------------------------------------------------------------------------

@router.post("/webhook")
async def stripe_webhook(request: Request):
    """Handle Stripe webhook events.

    Reference: https://docs.stripe.com/webhooks/signature
    """
    payload = await request.body()
    sig_header = request.headers.get('stripe-signature')

    if not STRIPE_WEBHOOK_SECRET:
        raise HTTPException(status_code=500, detail="Secret webhook non configuré")

    try:
        event = stripe.Webhook.construct_event(
            payload, sig_header, STRIPE_WEBHOOK_SECRET
        )
    except ValueError:
        raise HTTPException(status_code=400, detail="Payload invalide")
    except stripe.error.SignatureVerificationError:
        raise HTTPException(status_code=400, detail="Signature invalide")

    session = db.get_session()
    try:
        event_type = event['type']
        data = event['data']['object']

        if event_type == 'checkout.session.completed':
            handle_checkout_completed(data, session)
        elif event_type in ('customer.subscription.created', 'customer.subscription.updated'):
            handle_subscription_active(data, session)
        elif event_type == 'customer.subscription.deleted':
            handle_subscription_deleted(data, session)
        elif event_type == 'invoice.paid':
            handle_invoice_paid(data, session)
        elif event_type == 'invoice.payment_failed':
            handle_payment_failed(data, session)

        session.commit()
        return {"status": "success"}
    except Exception as e:
        session.rollback()
        logger.error(f"Stripe Webhook error: {e}")
        raise HTTPException(status_code=500, detail="Échec du traitement du webhook")
    finally:
        session.close()


def handle_checkout_completed(session_data, session):
    """Handle checkout.session.completed event."""
    org_id = session_data.get('metadata', {}).get('organization_id')
    customer_id = session_data.get('customer')
    subscription_id = session_data.get('subscription')  # ID de l'abonnement créé

    if org_id and customer_id:
        org = session.query(Organization).filter(Organization.id == int(org_id)).first()
        if org:
            org.stripe_customer_id = customer_id
            if subscription_id:
                org.stripe_subscription_id = subscription_id  # ✅ Sauvegarder subscription_id


def handle_subscription_active(subscription, session):
    """Handle customer.subscription.created/updated event."""
    org_id = subscription.get('metadata', {}).get('organization_id')
    subscription_id = subscription.get('id')

    if not org_id:
        # Fall back to looking up by customer id
        customer_id = subscription.get('customer')
        if customer_id:
            org = session.query(Organization).filter(
                Organization.stripe_customer_id == customer_id
            ).first()
        else:
            org = None
    else:
        org = session.query(Organization).filter(Organization.id == int(org_id)).first()

    if org:
        status = subscription.get('status')
        if status in ('active', 'trialing'):
            plan = subscription.get('metadata', {}).get('plan_type', 'pro')
            org.plan_type = plan
            org.is_trial_active = False
            if subscription_id:
                org.stripe_subscription_id = subscription_id

            # Lifecycle: payment confirmed → paying sequence
            from src.scheduler.lifecycle_engine import on_payment_confirmed
            on_payment_confirmed(session, organization_id=org.id)


def handle_subscription_deleted(subscription, session):
    """Handle customer.subscription.deleted event."""
    subscription_id = subscription.get('id')
    org_id = subscription.get('metadata', {}).get('organization_id')

    if not org_id:
        customer_id = subscription.get('customer')
        org = session.query(Organization).filter(
            Organization.stripe_customer_id == customer_id
        ).first() if customer_id else None
    else:
        org = session.query(Organization).filter(Organization.id == int(org_id)).first()

    if org:
        org.plan_type = 'free'
        org.is_trial_active = False
        if org.stripe_subscription_id == subscription_id:
            org.stripe_subscription_id = None

        # Lifecycle: subscription cancelled → churned sequence
        from src.scheduler.lifecycle_engine import on_subscription_cancelled
        on_subscription_cancelled(session, organization_id=org.id)


def handle_payment_failed(invoice_data, session):
    """Handle invoice.payment_failed — trigger payment_failed_1/2/3 email based on attempt count."""
    customer_id = invoice_data.get('customer')
    attempt = invoice_data.get('attempt_count', 1)
    if not customer_id:
        return
    org = session.query(Organization).filter(
        Organization.stripe_customer_id == customer_id
    ).first()
    if org:
        from src.scheduler.lifecycle_engine import on_payment_failed
        on_payment_failed(session, organization_id=org.id, attempt=attempt)


def handle_invoice_paid(invoice_data, session):
    """Handle invoice.paid — transfer affiliate commission via Stripe Connect."""
    customer_id = invoice_data.get('customer')
    amount_paid = invoice_data.get('amount_paid', 0)
    if not customer_id or amount_paid <= 0:
        return

    org = session.query(Organization).filter(
        Organization.stripe_customer_id == customer_id
    ).first()
    if not org:
        return

    referral = session.query(Referral).filter(
        Referral.referred_org_id == org.id,
        Referral.status.in_([ReferralStatus.CONVERTED, ReferralStatus.PENDING]),
    ).first()
    if not referral:
        return

    affiliate = session.query(Affiliate).filter(
        Affiliate.id == referral.affiliate_id,
        Affiliate.is_active == True,
        Affiliate.stripe_onboarding_complete == True,
    ).first()
    if not affiliate or not affiliate.stripe_account_id:
        return

    payment_amount = Decimal(amount_paid) / Decimal(100)
    commission = int(payment_amount * Decimal(str(affiliate.commission_rate)) * 100)
    if commission <= 0:
        return

    try:
        stripe.Transfer.create(
            amount=commission,
            currency="eur",
            destination=affiliate.stripe_account_id,
            description=f"Commission affiliation - Org {org.id}",
            metadata={
                "affiliate_id": str(affiliate.id),
                "referral_id": str(referral.id),
                "org_id": str(org.id),
            },
        )
        if referral.status == ReferralStatus.PENDING:
            referral.status = ReferralStatus.CONVERTED
            referral.converted_at = datetime.utcnow()
            referral.commission_amount = payment_amount * Decimal(str(affiliate.commission_rate))
            affiliate.total_earned = (affiliate.total_earned or 0) + referral.commission_amount

        affiliate.total_paid = (affiliate.total_paid or 0) + Decimal(commission) / Decimal(100)
        referral.status = ReferralStatus.PAID
        logger.info(f"Transferred {commission} cents to affiliate {affiliate.id}")
    except stripe.error.StripeError as e:
        logger.error(f"Affiliate transfer failed: {e}")


# ---------------------------------------------------------------------------
# Checkout session
# ---------------------------------------------------------------------------

@router.get("/verify-session/{session_id}")
async def verify_checkout_session(
    session_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Verify a checkout session and update the organization's plan.

    Used as a fallback when webhooks are not configured. The frontend calls this
    after returning from Stripe Checkout to immediately update the plan status.

    Reference: https://docs.stripe.com/api/checkout/sessions/retrieve
    """
    if not stripe.api_key:
        raise HTTPException(status_code=500, detail="Stripe n'est pas configuré")

    db_session = db.get_session()
    try:
        # Retrieve the checkout session from Stripe
        checkout_session = stripe.checkout.Session.retrieve(session_id)

        # Verify it belongs to this organization
        org_id_from_meta = checkout_session.get('metadata', {}).get('organization_id')
        if org_id_from_meta and int(org_id_from_meta) != current_user["organization_id"]:
            raise HTTPException(status_code=403, detail="Cette session n'appartient pas à cette organisation")

        org = db_session.query(Organization).filter(
            Organization.id == current_user["organization_id"]
        ).first()
        if not org:
            raise HTTPException(status_code=404, detail="Organisation introuvable")

        # Save customer id if not yet set
        customer_id = checkout_session.get('customer')
        if customer_id and not org.stripe_customer_id:
            org.stripe_customer_id = customer_id

        payment_status = checkout_session.get('payment_status')
        status = checkout_session.get('status')

        # If payment is successful, upgrade the plan
        if payment_status == 'paid' or status == 'complete':
            plan_from_meta = checkout_session.get('metadata', {}).get('plan_type', 'pro')
            org.plan_type = plan_from_meta
            org.is_trial_active = False
            db_session.commit()
            return {
                "status": "success",
                "plan_type": org.plan_type,
                "payment_status": payment_status,
            }

        return {
            "status": "pending",
            "plan_type": org.plan_type,
            "payment_status": payment_status,
        }

    except stripe.error.StripeError as e:
        msg = getattr(e, 'user_message', None) or str(e)
        raise HTTPException(status_code=400, detail=f"Erreur Stripe : {msg}")
    except HTTPException:
        raise
    except Exception:
        logger.exception("Unexpected error in verify_checkout_session")
        raise HTTPException(status_code=500, detail="Erreur interne du serveur")
    finally:
        db_session.close()


@router.post("/create-checkout-session")
async def create_checkout_session(
    request: CreateCheckoutSessionRequest,
    current_user: dict = Depends(get_current_user)
):
    """Create/Modify Stripe subscription (upgrade/downgrade sans double facturation).

    - Si pas d'abonnement actif → Checkout classique
    - Si abonnement actif → Modification avec proration
    """
    if not stripe.api_key:
        raise HTTPException(status_code=500, detail="Stripe n'est pas configuré (STRIPE_SECRET_KEY manquant)")

    PRICE_MAP = {
        "starter": os.getenv("STRIPE_PRICE_STARTER_MONTHLY", ""),
        "pro": os.getenv("STRIPE_PRICE_PRO_MONTHLY", ""),
        "reseau": os.getenv("STRIPE_PRICE_RESEAU", ""),
    }
    price_id = PRICE_MAP.get(request.plan_type, "")
    if not price_id or not price_id.startswith('price_'):
        raise HTTPException(
            status_code=400,
            detail=f"Plan '{request.plan_type}' invalide ou Price ID non configuré dans .env",
        )

    db_session = db.get_session()
    try:
        org = db_session.query(Organization).filter(
            Organization.id == current_user["organization_id"]
        ).first()

        if not org:
            raise HTTPException(status_code=404, detail="Organisation introuvable")

        # Create or reuse Stripe customer
        if org.stripe_customer_id:
            customer_id = org.stripe_customer_id
        else:
            customer = stripe.Customer.create(
                email=current_user.get("email"),
                name=org.name,
                metadata={"organization_id": str(org.id)},
                idempotency_key=f"customer-create-org-{org.id}",
            )
            customer_id = customer.id
            org.stripe_customer_id = customer_id
            db_session.commit()

        frontend_url = os.getenv("FRONTEND_URL", "http://localhost:3000")

        # CAS 1 : Abonnement actif → Modifier (pas de double facturation)
        if org.stripe_subscription_id:
            try:
                subscription = stripe.Subscription.retrieve(org.stripe_subscription_id)

                # Determine if this is an upgrade or downgrade
                current_plan = org.plan_type or 'free'
                current_idx = PLAN_ORDER.index(current_plan) if current_plan in PLAN_ORDER else 0
                new_idx = PLAN_ORDER.index(request.plan_type) if request.plan_type in PLAN_ORDER else 0
                is_downgrade = new_idx < current_idx

                # For downgrade: schedule change at period end
                if is_downgrade:
                    schedule = stripe.SubscriptionSchedule.create(
                        from_subscription=subscription.id
                    )
                    stripe.SubscriptionSchedule.modify(
                        schedule.id,
                        end_behavior='release',
                        phases=[
                            {
                                'items': [{'price': subscription['items']['data'][0]['price']['id'], 'quantity': 1}],
                                'start_date': subscription['current_period_start'],
                                'end_date': subscription['current_period_end'],
                            },
                            {
                                'items': [{'price': price_id, 'quantity': 1}],
                                'metadata': {'organization_id': str(org.id), 'plan_type': request.plan_type},
                            },
                        ],
                    )
                    # Don't change plan in DB yet — webhook will do it when period ends
                    return {
                        "success": True,
                        "message": "Plan changera à la fin de la période en cours",
                        "downgrade_at": subscription['current_period_end']
                    }

                # For upgrade: modify immediately with prorations
                updated_subscription = stripe.Subscription.modify(
                    org.stripe_subscription_id,
                    items=[{
                        'id': subscription['items']['data'][0].id,
                        'price': price_id,
                    }],
                    proration_behavior='create_prorations',  # Standard proration behavior
                    metadata={
                        'organization_id': str(org.id),
                        'plan_type': request.plan_type,
                    }
                )

                # Update DB immediately for upgrades
                org.plan_type = request.plan_type
                db_session.commit()

                return {
                    "success": True,
                    "message": "Abonnement modifié avec succès (proration appliquée)",
                    "subscription_id": updated_subscription.id
                }

            except stripe.error.InvalidRequestError:
                # Subscription invalide/annulé → passer au Checkout
                org.stripe_subscription_id = None
                db_session.commit()

        # CAS 2 : Pas d'abonnement actif → Checkout classique
        checkout_session = stripe.checkout.Session.create(
            customer=customer_id,
            mode='subscription',
            line_items=[{'price': price_id, 'quantity': 1}],
            success_url=f'{frontend_url}/settings?tab=plan&session_id={{CHECKOUT_SESSION_ID}}',
            cancel_url=f'{frontend_url}/settings?tab=plan',
            metadata={
                'organization_id': str(org.id),
                'plan_type': request.plan_type,
            },
            subscription_data={
                'metadata': {
                    'organization_id': str(org.id),
                    'plan_type': request.plan_type,
                }
            },
        )

        return {"session_id": checkout_session.id, "url": checkout_session.url}

    except stripe.error.StripeError as e:
        msg = getattr(e, 'user_message', None) or str(e)
        logger.error(f"Stripe StripeError: {msg}")
        raise HTTPException(status_code=400, detail=f"Erreur Stripe : {msg}")
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Unexpected error in create_checkout_session")
        raise HTTPException(status_code=500, detail="Erreur interne du serveur")
    finally:
        db_session.close()


@router.post("/cancel-subscription")
async def cancel_subscription(current_user: dict = Depends(get_current_user)):
    """Cancel subscription at end of billing period (graceful).

    Uses cancel_at_period_end to let users continue using the service
    until the end of their paid period.
    """
    db_session = db.get_session()
    try:
        org = db_session.query(Organization).filter(
            Organization.id == current_user["organization_id"]
        ).first()

        if not org:
            raise HTTPException(status_code=404, detail="Organisation introuvable")

        if not org.stripe_subscription_id:
            raise HTTPException(status_code=400, detail="Aucun abonnement actif à annuler")

        # Cancel at period end (graceful cancellation)
        subscription = stripe.Subscription.modify(
            org.stripe_subscription_id,
            cancel_at_period_end=True
        )

        return {
            "success": True,
            "message": "Abonnement annulé en fin de période",
            "cancel_at": subscription.get('current_period_end')
        }

    except stripe.error.StripeError as e:
        msg = getattr(e, 'user_message', None) or str(e)
        logger.error(f"Stripe cancel error: {msg}")
        raise HTTPException(status_code=400, detail=f"Erreur Stripe : {msg}")
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Unexpected error in cancel_subscription")
        raise HTTPException(status_code=500, detail="Erreur interne du serveur")
    finally:
        db_session.close()


# ---------------------------------------------------------------------------
# Customer portal / payment methods / invoices
# ---------------------------------------------------------------------------

@router.post("/create-portal-session")
async def create_portal_session(current_user: dict = Depends(get_current_user)):
    """Create a Stripe Billing Portal session.

    Reference: https://docs.stripe.com/api/customer_portal/sessions/create
    """
    db_session = db.get_session()
    try:
        org = db_session.query(Organization).filter(
            Organization.id == current_user["organization_id"]
        ).first()

        if not org or not org.stripe_customer_id:
            raise HTTPException(status_code=404, detail="Aucun client Stripe trouvé")

        frontend_url = os.getenv("FRONTEND_URL", "http://localhost:3000")
        portal_session = stripe.billing_portal.Session.create(
            customer=org.stripe_customer_id,
            return_url=f'{frontend_url}/settings/Facturation',
        )
        return {"url": portal_session.url}
    except stripe.error.StripeError as e:
        msg = getattr(e, 'user_message', None) or str(e)
        raise HTTPException(status_code=400, detail=f"Erreur Stripe : {msg}")
    finally:
        db_session.close()


@router.get("/payment-methods")
async def get_payment_methods(current_user: dict = Depends(get_current_user)):
    """List card payment methods for the organization's Stripe customer."""
    db_session = db.get_session()
    try:
        org = db_session.query(Organization).filter(
            Organization.id == current_user["organization_id"]
        ).first()

        if not org or not org.stripe_customer_id:
            return {"payment_methods": []}

        payment_methods = stripe.PaymentMethod.list(
            customer=org.stripe_customer_id,
            type='card',
        )

        return {
            "payment_methods": [
                {
                    "id": pm.id,
                    "last4": pm.card.last4,
                    "brand": pm.card.brand,
                    "exp_month": pm.card.exp_month,
                    "exp_year": pm.card.exp_year,
                }
                for pm in payment_methods.data
            ]
        }
    except stripe.error.StripeError as e:
        msg = getattr(e, 'user_message', None) or str(e)
        raise HTTPException(status_code=400, detail=f"Erreur Stripe : {msg}")
    finally:
        db_session.close()


@router.get("/invoices")
async def get_invoices(current_user: dict = Depends(get_current_user)):
    """List Stripe invoices for the organization."""
    db_session = db.get_session()
    try:
        org = db_session.query(Organization).filter(
            Organization.id == current_user["organization_id"]
        ).first()

        if not org or not org.stripe_customer_id:
            return {"invoices": []}

        invoices = stripe.Invoice.list(
            customer=org.stripe_customer_id,
            limit=10,
        )

        return {
            "invoices": [
                {
                    "id": inv.id,
                    "number": inv.number,
                    "amount": (inv.amount_paid or 0) / 100,
                    "currency": inv.currency,
                    "date": inv.created,
                    "status": inv.status,
                    "hosted_invoice_url": inv.hosted_invoice_url,
                    "invoice_pdf": inv.invoice_pdf,
                }
                for inv in invoices.data
            ]
        }
    except stripe.error.StripeError as e:
        msg = getattr(e, 'user_message', None) or str(e)
        raise HTTPException(status_code=400, detail=f"Erreur Stripe : {msg}")
    finally:
        db_session.close()
