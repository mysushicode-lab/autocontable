"""Settings endpoints"""
import os
from fastapi import APIRouter, Depends, HTTPException
from typing import Optional
from datetime import datetime

import src.config  # noqa: F401

from src.storage.database import db
from src.storage.models import Settings, Organization
from src.api.schemas import SettingUpdate, TestImapRequest
from src.api.auth import get_current_user, check_trial_active

try:
    import stripe
    stripe.api_key = os.getenv('STRIPE_SECRET_KEY')
    STRIPE_AVAILABLE = bool(stripe.api_key)
except ImportError:
    STRIPE_AVAILABLE = False

router = APIRouter()


def sync_plan_from_stripe(org, session):
    """Sync organization plan from Stripe subscription state.

    Returns True if any change was committed.
    """
    if not STRIPE_AVAILABLE or not org.stripe_customer_id:
        return False
    try:
        subscriptions = stripe.Subscription.list(
            customer=org.stripe_customer_id,
            status='all',
            limit=10,
        )
        has_active = any(
            sub.status in ('active', 'trialing', 'past_due')
            for sub in subscriptions.data
        )
        changed = False
        if has_active and org.plan_type != 'paid':
            org.plan_type = 'paid'
            org.is_trial_active = False
            changed = True
        elif not has_active and org.plan_type == 'paid':
            # Subscription cancelled or expired
            org.plan_type = 'free'
            org.is_trial_active = False
            changed = True
        if changed:
            session.commit()
        return changed
    except Exception as e:
        print(f"[sync_plan_from_stripe] Error: {e}")
        return False


@router.get("/")
@router.get("")
def get_settings(category: Optional[str] = None, current_user: dict = Depends(get_current_user)):
    """Get all settings or filtered by category"""
    session = db.get_session()
    try:
        query = session.query(Settings).filter(Settings.organization_id == current_user["organization_id"])
        if category:
            query = query.filter(Settings.category == category)
        settings = query.all()
        return {
            "settings": [
                {
                    "key": s.key,
                    "value": s.value,
                    "category": s.category,
                    "description": s.description,
                    "updated_at": s.updated_at.isoformat() if s.updated_at else None
                }
                for s in settings
            ]
        }
    finally:
        session.close()


@router.put("/{key}")
def update_setting(key: str, update: SettingUpdate, current_user: dict = Depends(check_trial_active)):
    """Update a setting value"""
    session = db.get_session()
    org_id = current_user["organization_id"]
    try:
        setting = session.query(Settings).filter(Settings.key == key, Settings.organization_id == org_id).first()
        if not setting:
            setting = Settings(key=key, value=update.value, category="general", organization_id=org_id)
            session.add(setting)
        else:
            setting.value = update.value
        session.commit()
        return {"message": "Setting updated", "key": key, "value": update.value}
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


@router.post("/test-imap")
def test_imap_connection(request: TestImapRequest, current_user: dict = Depends(get_current_user)):
    """Test IMAP connection with provided credentials (authenticated)"""
    import imaplib
    import ssl
    try:
        context = ssl.create_default_context()
        mail = imaplib.IMAP4_SSL(request.server, request.port, ssl_context=context)
        mail.login(request.email, request.password)
        mail.logout()
        return {"success": True, "message": "Connexion réussie"}
    except imaplib.IMAP4.error as e:
        return {"success": False, "message": f"Erreur d'authentification : {str(e)}"}
    except ConnectionRefusedError:
        return {"success": False, "message": "Connexion refusée - vérifiez le serveur et le port"}
    except ssl.SSLError as e:
        return {"success": False, "message": f"Erreur SSL : {str(e)}"}
    except OSError as e:
        return {"success": False, "message": f"Serveur introuvable : {str(e)}"}
    except Exception as e:
        return {"success": False, "message": f"Erreur : {str(e)}"}


@router.get("/plan")
def get_plan_status(current_user: dict = Depends(get_current_user)):
    """Get current organization plan status and trial information.

    Auto-syncs from Stripe if the org has a stripe_customer_id, ensuring the
    plan is always up-to-date even if webhooks are missed.
    """
    session = db.get_session()
    try:
        org = session.query(Organization).filter(Organization.id == current_user["organization_id"]).first()
        if not org:
            raise HTTPException(status_code=404, detail="Organisation introuvable")

        # Sync from Stripe (no-op if no customer id or stripe unavailable)
        sync_plan_from_stripe(org, session)

        now = datetime.utcnow()
        is_trial_expired = False
        days_remaining = 0

        if org.plan_type == 'trial' and org.trial_end_date:
            if now > org.trial_end_date:
                is_trial_expired = True
                org.is_trial_active = False
                org.plan_type = 'free'
                session.commit()
            else:
                days_remaining = (org.trial_end_date - now).days
                if days_remaining < 0:
                    days_remaining = 0

        return {
            "plan_type": org.plan_type,
            "is_trial_active": org.is_trial_active,
            "trial_start_date": org.trial_start_date.isoformat() if org.trial_start_date else None,
            "trial_end_date": org.trial_end_date.isoformat() if org.trial_end_date else None,
            "days_remaining": days_remaining,
            "is_trial_expired": is_trial_expired
        }
    finally:
        session.close()


@router.post("/getresponse-config")
def configure_getresponse(
    body: dict,
    current_user: dict = Depends(get_current_user)
):
    """Configure GetResponse API key for organization"""
    api_key = body.get("api_key", "").strip()

    if not api_key:
        raise HTTPException(status_code=400, detail="API key required")

    session = db.get_session()
    try:
        org_id = current_user["organization_id"]

        existing = session.query(Settings).filter(
            Settings.organization_id == org_id,
            Settings.key == "getresponse_api_key"
        ).first()

        if existing:
            existing.value = api_key
        else:
            session.add(Settings(
                organization_id=org_id,
                key="getresponse_api_key",
                value=api_key,
                category="integrations",
                description="GetResponse API key for email marketing automation"
            ))

        session.commit()
        return {"status": "configured", "message": "GetResponse API key saved"}
    except Exception as e:
        session.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        session.close()


@router.post("/getresponse-test")
def test_getresponse_connection(current_user: dict = Depends(get_current_user)):
    """Test GetResponse connection"""
    from src.integrations.getresponse import GetResponseClient

    session = db.get_session()
    try:
        org_id = current_user["organization_id"]

        api_key_setting = session.query(Settings).filter(
            Settings.organization_id == org_id,
            Settings.key == "getresponse_api_key"
        ).first()

        if not api_key_setting or not api_key_setting.value:
            raise HTTPException(
                status_code=400,
                detail="GetResponse API key not configured"
            )

        try:
            client = GetResponseClient(api_key_setting.value)
            account = client._request("GET", "/accounts")

            return {
                "status": "connected",
                "account_id": account.get("accountId"),
                "email": account.get("email"),
                "company": account.get("companyName")
            }
        except Exception as e:
            raise HTTPException(
                status_code=401,
                detail=f"GetResponse connection failed: {str(e)}"
            )
    finally:
        session.close()


@router.get("/getresponse-status")
def get_getresponse_status(current_user: dict = Depends(get_current_user)):
    """Get GetResponse configuration status"""
    session = db.get_session()
    try:
        org_id = current_user["organization_id"]

        api_key_setting = session.query(Settings).filter(
            Settings.organization_id == org_id,
            Settings.key == "getresponse_api_key"
        ).first()

        is_configured = bool(api_key_setting and api_key_setting.value)

        return {
            "configured": is_configured,
            "api_key_masked": f"...{api_key_setting.value[-10:]}" if is_configured else None
        }
    finally:
        session.close()
