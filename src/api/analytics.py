"""Analytics endpoints — operational metrics for the accountant."""
import os
import logging
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends
from sqlalchemy import func

from src.storage.database import db
from src.storage.models import Invoice, BankTransaction, ReconciliationMatch, ClientFile, InvoiceStatus, Organization
from src.api.auth import get_current_user
from src.api.billing import require_feature

logger = logging.getLogger(__name__)
router = APIRouter()


@router.get("/overview")
def get_analytics_overview(current_user: dict = Depends(require_feature("analytics"))):
    """Get overall analytics for the organization."""
    session = db.get_session()
    try:
        org_id = current_user["organization_id"]
        now = datetime.utcnow()
        thirty_days_ago = now - timedelta(days=30)

        # Total counts
        total_invoices = session.query(Invoice).filter(Invoice.organization_id == org_id).count()
        total_matched = session.query(Invoice).filter(
            Invoice.organization_id == org_id,
            Invoice.status == InvoiceStatus.MATCHED
        ).count()
        total_dossiers = session.query(ClientFile).filter(
            ClientFile.organization_id == org_id,
            ClientFile.is_active == True
        ).count()

        # This month
        first_of_month = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        invoices_this_month = session.query(Invoice).filter(
            Invoice.organization_id == org_id,
            Invoice.created_at >= first_of_month
        ).count()

        # Match rate
        match_rate = round(total_matched / total_invoices * 100, 1) if total_invoices > 0 else 0

        # Auto vs manual matches
        auto_matches = session.query(ReconciliationMatch).filter(
            ReconciliationMatch.organization_id == org_id,
            ReconciliationMatch.match_type == 'automatic'
        ).count()
        manual_matches = session.query(ReconciliationMatch).filter(
            ReconciliationMatch.organization_id == org_id,
            ReconciliationMatch.match_type == 'manual'
        ).count()

        # Time saved estimate: 3 min per invoice (manual entry) vs 15 sec (AI)
        time_saved_minutes = total_invoices * 2.75  # 3min - 15sec = 2min45 saved

        # Cost estimate: ~$0.003 per GPT-4o-mini vision call
        ai_cost_estimate = total_invoices * 0.003

        # Per-dossier stats
        dossier_stats = []
        dossiers = session.query(ClientFile).filter(
            ClientFile.organization_id == org_id,
            ClientFile.is_active == True
        ).all()

        for cf in dossiers:
            inv_count = session.query(Invoice).filter(
                Invoice.organization_id == org_id,
                Invoice.client_file_id == cf.id
            ).count()
            matched_count = session.query(Invoice).filter(
                Invoice.organization_id == org_id,
                Invoice.client_file_id == cf.id,
                Invoice.status == InvoiceStatus.MATCHED
            ).count()
            dossier_stats.append({
                "id": cf.id,
                "name": cf.name,
                "invoices": inv_count,
                "matched": matched_count,
                "rate": round(matched_count / inv_count * 100, 1) if inv_count > 0 else 0,
            })

        return {
            "totals": {
                "invoices": total_invoices,
                "matched": total_matched,
                "dossiers": total_dossiers,
                "invoices_this_month": invoices_this_month,
                "match_rate": match_rate,
            },
            "automation": {
                "auto_matches": auto_matches,
                "manual_matches": manual_matches,
                "automation_rate": round(auto_matches / (auto_matches + manual_matches) * 100, 1) if (auto_matches + manual_matches) > 0 else 0,
            },
            "savings": {
                "time_saved_hours": round(time_saved_minutes / 60, 1),
                "ai_cost_eur": round(ai_cost_estimate * 0.92, 2),  # USD to EUR approx
                "cost_per_invoice_eur": 0.003,
            },
            "dossiers": sorted(dossier_stats, key=lambda x: x["invoices"], reverse=True),
        }
    finally:
        session.close()


@router.get("/monthly-trend")
def get_monthly_trend(months: int = 6, current_user: dict = Depends(require_feature("analytics"))):
    """Get monthly invoice processing trend."""
    session = db.get_session()
    try:
        org_id = current_user["organization_id"]
        now = datetime.utcnow()

        trends = []
        for i in range(months - 1, -1, -1):
            # Calculate month start/end
            month_date = now - timedelta(days=i * 30)
            month_start = month_date.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
            if month_start.month == 12:
                month_end = month_start.replace(year=month_start.year + 1, month=1)
            else:
                month_end = month_start.replace(month=month_start.month + 1)

            count = session.query(Invoice).filter(
                Invoice.organization_id == org_id,
                Invoice.created_at >= month_start,
                Invoice.created_at < month_end
            ).count()

            trends.append({
                "month": month_start.strftime("%Y-%m"),
                "label": month_start.strftime("%b %Y"),
                "invoices": count,
            })

        return {"trends": trends}
    finally:
        session.close()
