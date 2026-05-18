"""Shared auto-reconciliation helper used by the scheduler and API endpoints."""
import logging
from typing import Optional

from src.storage.database import db
from src.storage.models import Invoice, InvoiceStatus, BankTransaction
from src.reconciliation.reconciliation_engine import ReconciliationEngine

logger = logging.getLogger(__name__)


def run_auto_reconciliation(organization_id: int) -> int:
    """Run automatic reconciliation for a given organization.

    Uses an isolated session so it can safely be called from inside another
    transactional context (e.g. after an invoice upload or transaction update).

    Returns the number of matches created/updated; returns 0 on error.
    """
    if not organization_id:
        return 0

    session = db.get_session()
    try:
        invoices = session.query(Invoice).filter(
            Invoice.status.in_([
                InvoiceStatus.PROCESSED,
                InvoiceStatus.UNMATCHED,
                InvoiceStatus.PENDING,
            ]),
            Invoice.organization_id == organization_id,
        ).all()
        transactions = session.query(BankTransaction).filter(
            BankTransaction.organization_id == organization_id
        ).all()
        engine = ReconciliationEngine(session)
        matches = engine.reconcile(invoices, transactions, organization_id)
        session.commit()
        return len(matches) if matches else 0
    except Exception as exc:
        session.rollback()
        logger.warning(f"Auto-reconciliation failed for org {organization_id}: {exc}")
        return 0
    finally:
        session.close()
