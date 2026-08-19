"""Affiliate program API endpoints."""
import os
import secrets
import logging
from datetime import datetime
from decimal import Decimal

import stripe
from fastapi import APIRouter, HTTPException, Depends
from src.storage.database import db
from src.storage.models import Affiliate, Referral, ReferralStatus, User, Organization
from src.api.auth_helpers import get_current_user

logger = logging.getLogger(__name__)
stripe.api_key = os.getenv('STRIPE_SECRET_KEY')

router = APIRouter()


@router.post("/register")
def register_affiliate(current_user: dict = Depends(get_current_user)):
    """Register current user as an affiliate. Generates a unique referral code."""
    session = db.get_session()
    try:
        existing = session.query(Affiliate).filter(Affiliate.user_id == current_user["id"]).first()
        if existing:
            return {"code": existing.code, "commission_rate": existing.commission_rate}

        code = current_user.get("username", "")[:10].upper() + secrets.token_hex(3).upper()
        affiliate = Affiliate(
            user_id=current_user["id"],
            code=code,
            commission_rate=0.20,
        )
        session.add(affiliate)
        session.commit()
        return {"code": affiliate.code, "commission_rate": affiliate.commission_rate}
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


@router.get("/me")
def get_my_affiliate(current_user: dict = Depends(get_current_user)):
    """Get current user's affiliate info and stats."""
    session = db.get_session()
    try:
        affiliate = session.query(Affiliate).filter(Affiliate.user_id == current_user["id"]).first()
        if not affiliate:
            raise HTTPException(404, "Vous n'êtes pas affilié. Inscrivez-vous d'abord.")

        referrals = session.query(Referral).filter(Referral.affiliate_id == affiliate.id).all()
        return {
            "code": affiliate.code,
            "commission_rate": affiliate.commission_rate,
            "is_active": affiliate.is_active,
            "total_earned": float(affiliate.total_earned or 0),
            "total_paid": float(affiliate.total_paid or 0),
            "referrals_count": len(referrals),
            "referrals_converted": sum(1 for r in referrals if r.status != ReferralStatus.PENDING),
            "stripe_connected": affiliate.stripe_onboarding_complete or False,
            "created_at": affiliate.created_at.isoformat(),
        }
    finally:
        session.close()


@router.get("/referrals")
def list_referrals(current_user: dict = Depends(get_current_user)):
    """List all referrals for current affiliate."""
    session = db.get_session()
    try:
        affiliate = session.query(Affiliate).filter(Affiliate.user_id == current_user["id"]).first()
        if not affiliate:
            raise HTTPException(404, "Vous n'êtes pas affilié.")

        referrals = session.query(Referral).filter(Referral.affiliate_id == affiliate.id).order_by(Referral.created_at.desc()).all()
        results = []
        for r in referrals:
            user = session.query(User).filter(User.id == r.referred_user_id).first()
            results.append({
                "id": r.id,
                "email": user.email if user else None,
                "status": r.status.value,
                "commission_amount": float(r.commission_amount or 0),
                "created_at": r.created_at.isoformat(),
                "converted_at": r.converted_at.isoformat() if r.converted_at else None,
            })
        return results
    finally:
        session.close()


def track_referral(session, ref_code: str, user_id: int, org_id: int):
    """Called at signup when ?ref=CODE is present. Links the new user to the affiliate."""
    if not ref_code:
        return
    affiliate = session.query(Affiliate).filter(
        Affiliate.code == ref_code,
        Affiliate.is_active == True,
    ).first()
    if not affiliate:
        return
    existing = session.query(Referral).filter(Referral.referred_user_id == user_id).first()
    if existing:
        return
    session.add(Referral(
        affiliate_id=affiliate.id,
        referred_user_id=user_id,
        referred_org_id=org_id,
        status=ReferralStatus.PENDING,
    ))


@router.post("/connect-onboard")
def connect_onboard(current_user: dict = Depends(get_current_user)):
    """Create a Stripe Connect Express account and return onboarding URL."""
    if not stripe.api_key:
        raise HTTPException(500, "Stripe non configuré")

    session = db.get_session()
    try:
        affiliate = session.query(Affiliate).filter(
            Affiliate.user_id == current_user["id"]
        ).first()
        if not affiliate:
            raise HTTPException(404, "Vous n'êtes pas affilié.")

        if affiliate.stripe_onboarding_complete:
            raise HTTPException(400, "Compte déjà connecté.")

        frontend_url = os.getenv("FRONTEND_URL", "http://localhost:3000")

        # Create Stripe Connect Express account if not exists
        if not affiliate.stripe_account_id:
            user = session.query(User).filter(User.id == current_user["id"]).first()
            account = stripe.Account.create(
                type="express",
                email=user.email if user else current_user.get("email"),
                metadata={"affiliate_id": str(affiliate.id)},
            )
            affiliate.stripe_account_id = account.id
            session.commit()

        # Create onboarding link to Stripe's hosted signup
        link = stripe.AccountLink.create(
            account=affiliate.stripe_account_id,
            refresh_url=f"{frontend_url}/affiliation?stripe=refresh",
            return_url=f"{frontend_url}/affiliation?stripe=complete",
            type="account_onboarding",
        )
        return {"url": link.url}
    except stripe.error.StripeError as e:
        msg = getattr(e, 'user_message', None) or str(e)
        raise HTTPException(400, f"Erreur Stripe : {msg}")
    except HTTPException:
        raise
    except Exception:
        session.rollback()
        logger.exception("connect_onboard error")
        raise HTTPException(500, "Erreur interne")
    finally:
        session.close()


@router.get("/connect-status")
def connect_status(current_user: dict = Depends(get_current_user)):
    """Check Stripe Connect onboarding status."""
    if not stripe.api_key:
        raise HTTPException(500, "Stripe non configuré")

    session = db.get_session()
    try:
        affiliate = session.query(Affiliate).filter(
            Affiliate.user_id == current_user["id"]
        ).first()
        if not affiliate:
            raise HTTPException(404, "Vous n'êtes pas affilié.")

        if not affiliate.stripe_account_id:
            return {"connected": False, "onboarding_complete": False}

        account = stripe.Account.retrieve(affiliate.stripe_account_id)
        charges_enabled = account.get("charges_enabled", False)
        payouts_enabled = account.get("payouts_enabled", False)

        if payouts_enabled and not affiliate.stripe_onboarding_complete:
            affiliate.stripe_onboarding_complete = True
            session.commit()

        return {
            "connected": True,
            "onboarding_complete": affiliate.stripe_onboarding_complete,
            "payouts_enabled": payouts_enabled,
            "charges_enabled": charges_enabled,
        }
    except stripe.error.StripeError as e:
        msg = getattr(e, 'user_message', None) or str(e)
        raise HTTPException(400, f"Erreur Stripe : {msg}")
    finally:
        session.close()


def convert_referral(session, org_id: int, payment_amount: Decimal):
    """Called when an org upgrades to a paid plan. Marks referral as converted and credits commission."""
    referral = session.query(Referral).filter(
        Referral.referred_org_id == org_id,
        Referral.status == ReferralStatus.PENDING,
    ).first()
    if not referral:
        return
    affiliate = session.query(Affiliate).filter(Affiliate.id == referral.affiliate_id).first()
    if not affiliate:
        return
    commission = payment_amount * Decimal(str(affiliate.commission_rate))
    referral.status = ReferralStatus.CONVERTED
    referral.commission_amount = commission
    referral.converted_at = datetime.utcnow()
    affiliate.total_earned = (affiliate.total_earned or 0) + commission
