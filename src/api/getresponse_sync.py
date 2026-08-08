"""Webhook handlers to sync user events with GetResponse"""
import logging
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from src.storage.database import db
from src.storage.models import User, Settings, Organization
from src.api.auth import get_current_user
from src.integrations.getresponse import GetResponseClient, GetResponseSegmentation

logger = logging.getLogger(__name__)
router = APIRouter()


def get_org_settings(org_id: int) -> dict:
    """Get organization settings from database"""
    session = db.get_session()
    try:
        settings = session.query(Settings).filter(
            Settings.organization_id == org_id
        ).all()
        return {s.key: s.value for s in settings}
    finally:
        session.close()


def sync_user_to_getresponse(
    email: str,
    name: str,
    org_id: int,
    oauth_provider: str = None,
    plan_type: str = "free"
) -> None:
    """Sync user to GetResponse (background task)"""
    try:
        settings = get_org_settings(org_id)
        api_key = settings.get('getresponse_api_key')

        if not api_key:
            logger.info(f"GetResponse not configured for org {org_id}, skipping sync")
            return

        client = GetResponseClient(api_key)
        segmentation = GetResponseSegmentation(client)

        segmentation.add_user_contact(
            email=email,
            name=name,
            oauth_provider=oauth_provider,
            plan_type=plan_type
        )

        logger.info(f"Synced user {email} to GetResponse (org: {org_id})")
    except Exception as e:
        logger.error(f"Failed to sync user {email} to GetResponse: {e}")


def update_user_plan_in_getresponse(
    email: str,
    new_plan: str,
    org_id: int
) -> None:
    """Update user plan in GetResponse (background task)"""
    try:
        settings = get_org_settings(org_id)
        api_key = settings.get('getresponse_api_key')

        if not api_key:
            logger.info(f"GetResponse not configured for org {org_id}, skipping sync")
            return

        client = GetResponseClient(api_key)
        segmentation = GetResponseSegmentation(client)

        segmentation.update_user_plan(email, new_plan)

        logger.info(f"Updated user {email} plan to {new_plan} in GetResponse")
    except Exception as e:
        logger.error(f"Failed to update plan for {email} in GetResponse: {e}")


@router.post("/webhook/user-signup")
def on_user_signup(
    background_tasks: BackgroundTasks,
    user_id: int,
    email: str,
    name: str,
    oauth_provider: str = None,
    current_user: dict = Depends(get_current_user)
):
    """Webhook called when user signs up (OAuth or manual)"""
    session = db.get_session()
    try:
        user = session.query(User).filter(User.id == user_id).first()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        org_id = user.organization_id

        background_tasks.add_task(
            sync_user_to_getresponse,
            email=email,
            name=name,
            org_id=org_id,
            oauth_provider=oauth_provider,
            plan_type="free"
        )

        return {"status": "queued"}
    finally:
        session.close()


@router.post("/webhook/plan-upgraded")
def on_plan_upgraded(
    background_tasks: BackgroundTasks,
    user_id: int,
    new_plan: str,
    current_user: dict = Depends(get_current_user)
):
    """Webhook called when organization plan is upgraded"""
    session = db.get_session()
    try:
        user = session.query(User).filter(User.id == user_id).first()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        org_id = user.organization_id
        email = user.email

        if not email:
            logger.warning(f"User {user_id} has no email, skipping GetResponse sync")
            return {"status": "no_email"}

        background_tasks.add_task(
            update_user_plan_in_getresponse,
            email=email,
            new_plan=new_plan,
            org_id=org_id
        )

        return {"status": "queued"}
    finally:
        session.close()


@router.post("/webhook/trial-ending-soon")
def on_trial_ending_soon(
    background_tasks: BackgroundTasks,
    org_id: int,
    current_user: dict = Depends(get_current_user)
):
    """Webhook for trial ending soon notification (segment update)"""
    try:
        settings = get_org_settings(org_id)
        api_key = settings.get('getresponse_api_key')

        if not api_key:
            return {"status": "not_configured"}

        session = db.get_session()
        try:
            users = session.query(User).filter(
                User.organization_id == org_id
            ).all()

            client = GetResponseClient(api_key)
            segmentation = GetResponseSegmentation(client)

            for user in users:
                if user.email:
                    background_tasks.add_task(
                        segmentation.update_user_lifecycle,
                        email=user.email,
                        stage="trial_ending"
                    )

            return {"status": "queued", "users": len(users)}
        finally:
            session.close()
    except Exception as e:
        logger.error(f"Failed to mark trial ending: {e}")
        raise HTTPException(status_code=500, detail="Failed to mark trial ending")
