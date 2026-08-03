"""Billing: plan tiers, feature gating, usage calculation."""
import os
import logging
from fastapi import APIRouter, Depends, HTTPException

from src.storage.database import db
from src.storage.models import ClientFile, Organization
from src.api.auth import get_current_user

logger = logging.getLogger(__name__)
router = APIRouter()

PRICING_TIERS = [
    {
        "name": "starter", "price": 0, "max_dossiers": 2, "label": "Starter",
        "stripe_price_id": None,
        "features": ["upload_manual", "extraction_ia", "export_fec"],
    },
    {
        "name": "pro", "price": 89.00, "max_dossiers": 10, "overage_price": 7.00, "label": "Pro",
        "stripe_price_id": os.getenv("STRIPE_PRICE_PRO", ""),
        "features": ["upload_manual", "extraction_ia", "export_fec", "reconciliation", "integrations", "whatsapp", "portal_client", "analytics"],
    },
    {
        "name": "cabinet", "price": 199.00, "max_dossiers": 40, "overage_price": 5.00, "label": "Cabinet",
        "stripe_price_id": os.getenv("STRIPE_PRICE_CABINET", ""),
        "features": ["upload_manual", "extraction_ia", "export_fec", "reconciliation", "integrations", "whatsapp", "portal_client", "analytics", "audit_log", "custom_pcg", "webhooks", "auto_push"],
    },
    {
        "name": "reseau", "price": 399.00, "max_dossiers": 100, "overage_price": 4.00, "label": "Réseau",
        "stripe_price_id": os.getenv("STRIPE_PRICE_RESEAU", ""),
        "features": ["upload_manual", "extraction_ia", "export_fec", "reconciliation", "integrations", "whatsapp", "portal_client", "analytics", "audit_log", "custom_pcg", "webhooks", "auto_push", "permissions", "api_access"],
    },
]


def get_org_plan(session, org_id: int) -> dict:
    """Get the organization's current plan tier."""
    org = session.query(Organization).get(org_id)
    plan_type = org.plan_type if org else "starter"

    for tier in PRICING_TIERS:
        if tier["name"] == plan_type:
            return tier
    return PRICING_TIERS[0]  # Default to starter


def calculate_monthly_cost(dossier_count: int, plan_name: str) -> dict:
    """Calculate monthly cost based on plan and active dossiers."""
    tier = next((t for t in PRICING_TIERS if t["name"] == plan_name), PRICING_TIERS[0])
    overage = max(0, dossier_count - tier["max_dossiers"])
    overage_cost = overage * tier.get("overage_price", 0)
    total = tier["price"] + overage_cost
    return {
        "plan": tier["name"],
        "plan_label": tier["label"],
        "base_price": tier["price"],
        "max_dossiers": tier["max_dossiers"],
        "active_dossiers": dossier_count,
        "overage_dossiers": overage,
        "overage_price_per_dossier": tier.get("overage_price", 0),
        "overage_cost": overage_cost,
        "monthly_total": total,
        "features": tier["features"],
    }


def require_feature(feature: str):
    """FastAPI dependency factory — raises 403 if org plan doesn't include feature."""
    def _check(current_user: dict = Depends(get_current_user)):
        session = db.get_session()
        try:
            plan = get_org_plan(session, current_user["organization_id"])
            if feature not in plan.get("features", []):
                raise HTTPException(
                    403,
                    f"Fonctionnalité '{feature}' non disponible sur le plan {plan['label']}. Passez au plan supérieur."
                )
            return current_user
        finally:
            session.close()
    return _check


@router.get("/usage")
def get_billing_usage(current_user: dict = Depends(get_current_user)):
    """Get current billing usage and cost estimate."""
    session = db.get_session()
    try:
        org_id = current_user["organization_id"]
        org = session.query(Organization).get(org_id)
        plan_name = org.plan_type if org else "starter"

        active_dossiers = session.query(ClientFile).filter(
            ClientFile.organization_id == org_id,
            ClientFile.is_active == True
        ).count()

        return calculate_monthly_cost(active_dossiers, plan_name)
    finally:
        session.close()


@router.get("/pricing")
def get_pricing():
    """Get pricing tiers (public)."""
    return {"tiers": PRICING_TIERS, "currency": "EUR"}


@router.get("/can-access/{feature}")
def can_access_feature(feature: str, current_user: dict = Depends(get_current_user)):
    """Check if the org's plan includes a specific feature."""
    session = db.get_session()
    try:
        org_id = current_user["organization_id"]
        plan = get_org_plan(session, org_id)
        allowed = feature in plan.get("features", [])
        return {
            "allowed": allowed,
            "feature": feature,
            "plan": plan["name"],
            "upgrade_needed": plan["name"] if not allowed else None,
        }
    finally:
        session.close()


