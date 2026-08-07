"""Analytics endpoints — operational metrics for the accountant."""
import os
import logging
from datetime import datetime, timedelta
from dateutil.relativedelta import relativedelta
from fastapi import APIRouter, Depends
from sqlalchemy import func, case

from src.storage.database import db
from src.storage.models import Invoice, BankTransaction, ReconciliationMatch, ClientFile, InvoiceStatus
from src.api.auth import get_current_user
from src.api.billing import require_feature

logger = logging.getLogger(__name__)
router = APIRouter()

# Analytics constants
TIME_MANUAL_MINUTES = 3.0  # Time to manually enter one invoice
TIME_AI_SECONDS = 15.0     # Time with AI assistance
COST_PER_INVOICE_USD = 0.003  # GPT-4o-mini vision cost estimate
USD_TO_EUR_RATE = 0.92     # Approximate exchange rate


@router.get("/overview")
def get_analytics_overview(
    month: int = None,
    year: int = None,
    current_user: dict = Depends(require_feature("analytics"))
):
    """Get overall analytics for the organization, optionally filtered by month/year."""
    session = db.get_session()
    try:
        org_id = current_user["organization_id"]
        now = datetime.utcnow()

        # Calculate month boundaries if filter is present
        month_start = None
        month_end = None
        if month and year:
            month_start = datetime(year, month, 1)
            month_end = month_start + relativedelta(months=1)

        # Build base query filters
        base_filters = [Invoice.organization_id == org_id]

        # Add optional month/year filter
        if month_start and month_end:
            base_filters.append(Invoice.date >= month_start.date())
            base_filters.append(Invoice.date < month_end.date())

        # Total counts
        total_invoices = session.query(Invoice).filter(*base_filters).count()
        total_matched = session.query(Invoice).filter(
            *base_filters,
            Invoice.status == InvoiceStatus.MATCHED
        ).count()
        total_dossiers = session.query(ClientFile).filter(
            ClientFile.organization_id == org_id,
            ClientFile.is_active == True
        ).count()

        # This month (current month stats, independent of filter)
        first_of_month = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        invoices_this_month = session.query(Invoice).filter(
            Invoice.organization_id == org_id,
            Invoice.created_at >= first_of_month
        ).count()

        # Match rate
        match_rate = round(total_matched / total_invoices * 100, 1) if total_invoices > 0 else 0

        # Auto vs manual matches (filtered by invoice date if applicable)
        match_base_filters = [ReconciliationMatch.organization_id == org_id]
        if month_start and month_end:
            # Join with invoices to filter matches by invoice date
            auto_matches = session.query(ReconciliationMatch).join(
                Invoice, ReconciliationMatch.invoice_id == Invoice.id
            ).filter(
                ReconciliationMatch.organization_id == org_id,
                ReconciliationMatch.match_type == 'automatic',
                Invoice.date >= month_start.date(),
                Invoice.date < month_end.date()
            ).count()
            manual_matches = session.query(ReconciliationMatch).join(
                Invoice, ReconciliationMatch.invoice_id == Invoice.id
            ).filter(
                ReconciliationMatch.organization_id == org_id,
                ReconciliationMatch.match_type == 'manual',
                Invoice.date >= month_start.date(),
                Invoice.date < month_end.date()
            ).count()
        else:
            auto_matches = session.query(ReconciliationMatch).filter(
                ReconciliationMatch.organization_id == org_id,
                ReconciliationMatch.match_type == 'automatic'
            ).count()
            manual_matches = session.query(ReconciliationMatch).filter(
                ReconciliationMatch.organization_id == org_id,
                ReconciliationMatch.match_type == 'manual'
            ).count()

        # Time saved estimate: 3 min per invoice (manual entry) vs 15 sec (AI)
        time_saved_minutes = total_invoices * (TIME_MANUAL_MINUTES - TIME_AI_SECONDS / 60)

        # Cost estimate: ~$0.003 per GPT-4o-mini vision call
        ai_cost_estimate = total_invoices * COST_PER_INVOICE_USD

        # Per-dossier stats (optimized with GROUP BY to avoid N+1 queries)
        if month_start and month_end:
            # With month filter: only count invoices in that month
            dossier_query = session.query(
                ClientFile.id,
                ClientFile.name,
                func.count(Invoice.id).label('invoices'),
                func.sum(case((Invoice.status == InvoiceStatus.MATCHED, 1), else_=0)).label('matched')
            ).outerjoin(
                Invoice,
                (Invoice.client_file_id == ClientFile.id) &
                (Invoice.date >= month_start.date()) &
                (Invoice.date < month_end.date())
            ).filter(
                ClientFile.organization_id == org_id,
                ClientFile.is_active == True
            ).group_by(ClientFile.id, ClientFile.name).all()
        else:
            # No filter: count all invoices
            dossier_query = session.query(
                ClientFile.id,
                ClientFile.name,
                func.count(Invoice.id).label('invoices'),
                func.sum(case((Invoice.status == InvoiceStatus.MATCHED, 1), else_=0)).label('matched')
            ).outerjoin(Invoice, Invoice.client_file_id == ClientFile.id) \
             .filter(ClientFile.organization_id == org_id, ClientFile.is_active == True) \
             .group_by(ClientFile.id, ClientFile.name).all()

        dossier_stats = []
        for row in dossier_query:
            inv_count = row.invoices or 0
            matched_count = row.matched or 0
            dossier_stats.append({
                "id": row.id,
                "name": row.name,
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
                "ai_cost_eur": round(ai_cost_estimate * USD_TO_EUR_RATE, 2),
                "cost_per_invoice_eur": round(COST_PER_INVOICE_USD * USD_TO_EUR_RATE, 4),
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
            # Calculate month start/end using relativedelta for accurate month arithmetic
            month_start = (now - relativedelta(months=i)).replace(day=1, hour=0, minute=0, second=0, microsecond=0)
            month_end = month_start + relativedelta(months=1)

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
