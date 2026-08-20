"""Webhook handlers for marketing event sync (deprecated - now handled by lifecycle engine)"""
import logging
from fastapi import APIRouter, Depends, BackgroundTasks
from src.api.auth import get_current_user

logger = logging.getLogger(__name__)
router = APIRouter()


def sync_user_marketing(
    email: str,
    name: str,
    org_id: int,
    oauth_provider: str = None,
    plan_type: str = "free"
) -> None:
    """Deprecated - email sync is now handled by lifecycle_engine + SendGrid."""
    logger.debug(f"[DEPRECATED] sync_user_marketing skipped for {email}")


def update_user_plan_marketing(
    email: str,
    new_plan: str,
    org_id: int
) -> None:
    """Deprecated - plan updates are now handled by lifecycle_engine + SendGrid."""
    logger.debug(f"[DEPRECATED] update_user_plan_marketing skipped for {email}")


@router.post("/webhook/user-signup")
def on_user_signup(
    background_tasks: BackgroundTasks,
    user_id: int,
    email: str,
    name: str,
    oauth_provider: str = None,
    current_user: dict = Depends(get_current_user)
):
    """Deprecated - signup sync now handled by lifecycle_engine."""
    return {"status": "deprecated", "message": "Handled by lifecycle_engine"}


@router.post("/webhook/plan-upgraded")
def on_plan_upgraded(
    background_tasks: BackgroundTasks,
    user_id: int,
    new_plan: str,
    current_user: dict = Depends(get_current_user)
):
    """Deprecated - plan upgrade sync now handled by lifecycle_engine."""
    return {"status": "deprecated", "message": "Handled by lifecycle_engine"}


@router.post("/webhook/trial-ending-soon")
def on_trial_ending_soon(
    background_tasks: BackgroundTasks,
    org_id: int,
    current_user: dict = Depends(get_current_user)
):
    """Deprecated - trial ending now handled by lifecycle_engine."""
    return {"status": "deprecated", "message": "Handled by lifecycle_engine"}
