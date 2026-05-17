"""Stripe payment integration

References:
- Stripe Checkout: https://docs.stripe.com/api/checkout/sessions/create
- Stripe Webhooks: https://docs.stripe.com/webhooks
- Stripe Subscriptions: https://docs.stripe.com/billing/subscriptions/overview

NOTE: This file is named payments.py instead of stripe.py to avoid
conflict with the `stripe` package import.
"""
import os
import stripe
from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel
from src.api.auth import get_current_user
from src.storage.database import db
from src.storage.models import Organization

router = APIRouter()

# Initialize Stripe with the secret key from environment
stripe.api_key = os.getenv('STRIPE_SECRET_KEY')
STRIPE_WEBHOOK_SECRET = os.getenv('STRIPE_WEBHOOK_SECRET', '')


class CreateCheckoutSessionRequest(BaseModel):
    plan_type: str  # 'pro' or other plan types


@router.get("/debug")
async def debug_stripe():
    """Debug endpoint to check Stripe configuration"""
    return {
        "stripe_secret_key_set": bool(stripe.api_key),
        "stripe_pro_price_id": os.getenv('STRIPE_PRO_PRICE_ID'),
        "frontend_url": os.getenv('FRONTEND_URL'),
        "webhook_secret_set": bool(STRIPE_WEBHOOK_SECRET),
    }


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
        raise HTTPException(status_code=500, detail="Webhook secret not configured")

    try:
        event = stripe.Webhook.construct_event(
            payload, sig_header, STRIPE_WEBHOOK_SECRET
        )
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid payload")
    except stripe.error.SignatureVerificationError:
        raise HTTPException(status_code=400, detail="Invalid signature")

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

        session.commit()
        return {"status": "success"}
    except Exception as e:
        session.rollback()
        print(f"[Stripe Webhook] Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        session.close()


def handle_checkout_completed(session_data, session):
    """Handle checkout.session.completed event."""
    org_id = session_data.get('metadata', {}).get('organization_id')
    customer_id = session_data.get('customer')
    if org_id and customer_id:
        org = session.query(Organization).filter(Organization.id == int(org_id)).first()
        if org:
            org.stripe_customer_id = customer_id


def handle_subscription_active(subscription, session):
    """Handle customer.subscription.created/updated event."""
    org_id = subscription.get('metadata', {}).get('organization_id')
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
            org.plan_type = 'paid'
            org.is_trial_active = False


def handle_subscription_deleted(subscription, session):
    """Handle customer.subscription.deleted event."""
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


def handle_invoice_paid(invoice, session):
    """Handle invoice.paid event."""
    # Placeholder for future notifications/logging
    pass


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
        raise HTTPException(status_code=500, detail="Stripe is not configured")

    db_session = db.get_session()
    try:
        # Retrieve the checkout session from Stripe
        checkout_session = stripe.checkout.Session.retrieve(session_id)

        # Verify it belongs to this organization
        org_id_from_meta = checkout_session.get('metadata', {}).get('organization_id')
        if org_id_from_meta and int(org_id_from_meta) != current_user["organization_id"]:
            raise HTTPException(status_code=403, detail="Session does not belong to this organization")

        org = db_session.query(Organization).filter(
            Organization.id == current_user["organization_id"]
        ).first()
        if not org:
            raise HTTPException(status_code=404, detail="Organization not found")

        # Save customer id if not yet set
        customer_id = checkout_session.get('customer')
        if customer_id and not org.stripe_customer_id:
            org.stripe_customer_id = customer_id

        payment_status = checkout_session.get('payment_status')
        status = checkout_session.get('status')

        # If payment is successful, upgrade the plan
        if payment_status == 'paid' or status == 'complete':
            org.plan_type = 'paid'
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
        raise HTTPException(status_code=400, detail=f"Stripe error: {msg}")
    except HTTPException:
        raise
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db_session.close()


@router.post("/create-checkout-session")
async def create_checkout_session(
    request: CreateCheckoutSessionRequest,
    current_user: dict = Depends(get_current_user)
):
    """Create a Stripe Checkout Session for plan upgrade.

    Reference: https://docs.stripe.com/api/checkout/sessions/create
    """
    if not stripe.api_key:
        raise HTTPException(status_code=500, detail="Stripe is not configured (STRIPE_SECRET_KEY missing)")

    price_id = os.getenv('STRIPE_PRO_PRICE_ID')
    if not price_id or not price_id.startswith('price_'):
        raise HTTPException(
            status_code=500,
            detail=(
                "STRIPE_PRO_PRICE_ID is invalid. It must be a Stripe Price ID "
                "(starting with 'price_'), not a Product ID. Create a recurring price "
                "in the Stripe dashboard for your product and use its Price ID."
            ),
        )

    if request.plan_type != 'pro':
        raise HTTPException(status_code=400, detail="Invalid plan type")

    db_session = db.get_session()
    try:
        org = db_session.query(Organization).filter(
            Organization.id == current_user["organization_id"]
        ).first()

        if not org:
            raise HTTPException(status_code=404, detail="Organization not found")

        # Create or reuse Stripe customer
        if org.stripe_customer_id:
            customer_id = org.stripe_customer_id
        else:
            customer = stripe.Customer.create(
                email=current_user.get("email"),
                name=org.name,
                metadata={"organization_id": str(org.id)},
            )
            customer_id = customer.id
            org.stripe_customer_id = customer_id
            db_session.commit()

        frontend_url = os.getenv("FRONTEND_URL", "http://localhost:3000")

        checkout_session = stripe.checkout.Session.create(
            customer=customer_id,
            mode='subscription',
            line_items=[{'price': price_id, 'quantity': 1}],
            success_url=f'{frontend_url}/settings/Plan?session_id={{CHECKOUT_SESSION_ID}}',
            cancel_url=f'{frontend_url}/settings/Plan',
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
        # Surface Stripe-specific errors to the client for easier debugging
        msg = getattr(e, 'user_message', None) or str(e)
        print(f"[Stripe] StripeError: {msg}")
        raise HTTPException(status_code=400, detail=f"Stripe error: {msg}")
    except HTTPException:
        raise
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))
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
            raise HTTPException(status_code=404, detail="No Stripe customer found")

        frontend_url = os.getenv("FRONTEND_URL", "http://localhost:3000")
        portal_session = stripe.billing_portal.Session.create(
            customer=org.stripe_customer_id,
            return_url=f'{frontend_url}/settings/Facturation',
        )
        return {"url": portal_session.url}
    except stripe.error.StripeError as e:
        msg = getattr(e, 'user_message', None) or str(e)
        raise HTTPException(status_code=400, detail=f"Stripe error: {msg}")
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
        raise HTTPException(status_code=400, detail=f"Stripe error: {msg}")
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
        raise HTTPException(status_code=400, detail=f"Stripe error: {msg}")
    finally:
        db_session.close()
