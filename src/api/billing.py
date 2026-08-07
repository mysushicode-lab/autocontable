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
        "name": "starter", "price": 29.00, "max_dossiers": 1, "max_invoices_per_month": 50, "label": "Starter",
        "stripe_price_id": os.getenv("STRIPE_PRICE_STARTER", ""),
        "features": ["upload_manual", "extraction_ia", "export_fec", "reconciliation"],
    },
    {
        "name": "pro", "price": 79.00, "max_dossiers": 5, "max_invoices_per_month": 200, "label": "Pro",
        "stripe_price_id": os.getenv("STRIPE_PRICE_PRO", ""),
        "features": ["upload_manual", "extraction_ia", "export_fec", "reconciliation", "whatsapp", "analytics"],
    },
    {
        "name": "cabinet", "price": 199.00, "max_dossiers": None, "max_invoices_per_month": 1000, "label": "Cabinet",
        "stripe_price_id": os.getenv("STRIPE_PRICE_CABINET", ""),
        "features": ["upload_manual", "extraction_ia", "export_fec", "reconciliation", "whatsapp", "analytics", "permissions", "audit_log", "api_access"],
    },
    {
        "name": "reseau", "price": None, "max_dossiers": None, "max_invoices_per_month": None, "label": "Réseau",
        "stripe_price_id": os.getenv("STRIPE_PRICE_RESEAU", ""),
        "features": ["upload_manual", "extraction_ia", "export_fec", "reconciliation", "whatsapp", "analytics", "permissions", "audit_log", "api_access", "webhooks", "custom_pcg"],
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

    # Handle unlimited plans (None = illimité)
    max_dossiers = tier.get("max_dossiers")
    if max_dossiers is None:
        overage = 0
        overage_cost = 0
    else:
        overage = max(0, dossier_count - max_dossiers)
        overage_cost = overage * tier.get("overage_price", 0)

    # Handle custom pricing (None = sur devis)
    base_price = tier.get("price")
    total = base_price + overage_cost if base_price is not None else None

    return {
        "plan": tier["name"],
        "plan_label": tier["label"],
        "base_price": base_price,
        "max_dossiers": max_dossiers,
        "max_invoices_per_month": tier.get("max_invoices_per_month"),
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

        result = calculate_monthly_cost(active_dossiers, plan_name)

        # Add invoice quota usage (TODO: add migration for these columns)
        result["invoices_processed_this_month"] = getattr(org, "invoices_processed_this_month", 0) or 0
        quota_reset_date = getattr(org, "monthly_quota_reset_date", None)
        result["quota_reset_date"] = quota_reset_date.isoformat() if quota_reset_date else None

        return result
    finally:
        session.close()


@router.get("/pricing")
def get_pricing():
    """Get pricing tiers (public)."""
    public_tiers = [
        {k: v for k, v in tier.items() if k != "stripe_price_id"}
        for tier in PRICING_TIERS
    ]
    return {"tiers": public_tiers, "currency": "EUR"}


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


