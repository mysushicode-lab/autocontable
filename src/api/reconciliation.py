"""Reconciliation endpoints"""
from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session
from sqlalchemy import or_
from typing import Optional
from datetime import datetime
import calendar

from src.storage.database import db
from src.storage.models import Invoice, BankTransaction, ReconciliationMatch, InvoiceStatus
from src.reconciliation.reconciliation_engine import ReconciliationEngine
from src.api.utils import serialize_match
from src.api.schemas import ManualLinkPayload
from src.api.auth import get_current_user, check_trial_active

router = APIRouter()


@router.post("/run")
def run_reconciliation(month: Optional[int] = None, year: Optional[int] = None, current_user: dict = Depends(check_trial_active)):
    """Run reconciliation automatically on current invoices and transactions."""
    session = db.get_session()
    org_id = current_user["organization_id"]
    try:
        invoice_query = session.query(Invoice).filter(
            Invoice.status.in_([InvoiceStatus.PROCESSED, InvoiceStatus.UNMATCHED, InvoiceStatus.PENDING]),
            Invoice.organization_id == org_id
        )
        
        invoices = invoice_query.all()
        transaction_query = session.query(BankTransaction).filter(BankTransaction.organization_id == org_id)

        engine = ReconciliationEngine(session)
        matches = engine.reconcile(invoices, transaction_query.all(), org_id)
        serialized_matches = [serialize_match(match) for match in matches]
        return {
            "message": "Reconciliation completed",
            "matches_created": len(matches),
            "matches": serialized_matches,
        }
    except Exception as exc:
        session.rollback()
        raise HTTPException(status_code=400, detail=str(exc))
    finally:
        session.close()



@router.post("/{match_id}/reject")
def reject_match(match_id: int, current_user: dict = Depends(get_current_user)):
    """Reject a proposed reconciliation match."""
    session = db.get_session()
    try:
        match = session.query(ReconciliationMatch).filter(
            ReconciliationMatch.id == match_id,
            ReconciliationMatch.organization_id == current_user["organization_id"]
        ).first()
        if not match:
            raise HTTPException(status_code=404, detail="Match not found")

        match.status = "rejected"
        match.matched_by = "user"
        match.invoice.status = InvoiceStatus.UNMATCHED
        session.commit()
        session.refresh(match)
        return {"message": "Match rejected", "match": serialize_match(match)}
    finally:
        session.close()


@router.post("/manual-link")
def create_manual_link(payload: ManualLinkPayload, current_user: dict = Depends(get_current_user)):
    """Create a manual invoice to bank transaction link."""
    session = db.get_session()
    org_id = current_user["organization_id"]
    try:
        invoice = session.query(Invoice).filter(
            Invoice.id == payload.invoice_id,
            Invoice.organization_id == org_id
        ).first()
        transaction = session.query(BankTransaction).filter(
            BankTransaction.id == payload.transaction_id,
            BankTransaction.organization_id == org_id
        ).first()

        if not invoice:
            raise HTTPException(status_code=404, detail="Invoice not found")
        if not transaction:
            raise HTTPException(status_code=404, detail="Bank transaction not found")

        transaction_already_linked = session.query(ReconciliationMatch).filter(
            ReconciliationMatch.transaction_id == transaction.id,
            ReconciliationMatch.invoice_id != invoice.id,
            ReconciliationMatch.status != "rejected",
            ReconciliationMatch.organization_id == org_id
        ).first()
        if transaction_already_linked:
            raise HTTPException(status_code=400, detail="Bank transaction is already linked to another invoice")

        existing_match = session.query(ReconciliationMatch).filter(
            ReconciliationMatch.invoice_id == invoice.id,
            ReconciliationMatch.transaction_id == transaction.id,
            ReconciliationMatch.organization_id == org_id
        ).first()
        if existing_match:
            existing_match.status = "confirmed"
            existing_match.match_type = "manual"
            existing_match.notes = payload.notes
            existing_match.matched_by = "user"
            invoice.status = InvoiceStatus.MATCHED
            session.commit()
            session.refresh(existing_match)
            return {"message": "Manual link updated", "match": serialize_match(existing_match)}
        else:
            manual_match = ReconciliationMatch(
                invoice_id=invoice.id,
                transaction_id=transaction.id,
                match_score=1.0,
                match_type="manual",
                status="confirmed",
                matched_by="user",
                notes=payload.notes,
                organization_id=org_id
            )
            session.add(manual_match)
            invoice.status = InvoiceStatus.MATCHED
            session.commit()
            session.refresh(manual_match)
            return {"message": "Manual link created", "match": serialize_match(manual_match)}
    finally:
        session.close()


@router.get("/details")
def get_reconciliation_details(
    month: Optional[int] = None,
    year: Optional[int] = None,
    current_user: dict = Depends(get_current_user)
):
    """Get detailed reconciliation payload for the UI."""
    session = db.get_session()
    org_id = current_user["organization_id"]
    try:
        invoice_query = session.query(Invoice).filter(Invoice.organization_id == org_id)
        match_query = session.query(ReconciliationMatch).filter(
            ReconciliationMatch.organization_id == org_id,
            ReconciliationMatch.status != 'rejected'
        ).join(Invoice).join(BankTransaction, ReconciliationMatch.transaction_id == BankTransaction.id)
        transaction_query = session.query(BankTransaction).filter(BankTransaction.organization_id == org_id)

        if month and year:
            last_day_num = calendar.monthrange(year, month)[1]
            first_day = datetime(year, month, 1)
            last_day = datetime(year, month, last_day_num, 23, 59, 59)
            invoice_query = invoice_query.filter(Invoice.date >= first_day, Invoice.date <= last_day)
            match_query = match_query.filter(BankTransaction.date >= first_day, BankTransaction.date <= last_day)
            transaction_query = transaction_query.filter(BankTransaction.date >= first_day, BankTransaction.date <= last_day)

        matches = match_query.all()
        matched_transaction_ids = {match.transaction_id for match in matches}
        matched_invoice_ids = {match.invoice_id for match in matches}

        # Calculate unmatched invoices based on actual reconciliation matches, not invoice status
        all_invoices = invoice_query.all()
        unmatched_invoices = [inv for inv in all_invoices if inv.id not in matched_invoice_ids]
        
        bank_only_transactions = transaction_query.filter(
            ~BankTransaction.id.in_(matched_transaction_ids) if matched_transaction_ids else True
        ).all()

        return {
            "matches": [
                {
                    "id": match.id,
                    "score": round((match.match_score or 0) * 100, 2),
                    "status": match.status,
                    "invoice": {
                        "id": match.invoice.id,
                        "number": match.invoice.invoice_number,
                        "supplier": match.invoice.supplier.name if match.invoice.supplier else None,
                        "amount": match.invoice.amount,
                        "date": match.invoice.date.isoformat() if match.invoice.date else None,
                        "vehicle": match.invoice.vehicle_registration
                    },
                    "transaction": {
                        "id": match.transaction.transaction_id,
                        "amount": match.transaction.amount,
                        "date": match.transaction.date.isoformat() if match.transaction.date else None,
                        "description": match.transaction.description
                    }
                }
                for match in matches
            ],
            "unmatched_invoices": [
                {
                    "id": invoice.id,
                    "invoice": {
                        "number": invoice.invoice_number,
                        "supplier": invoice.supplier.name if invoice.supplier else None,
                        "amount": invoice.amount,
                        "date": invoice.date.isoformat() if invoice.date else None
                    },
                    "vehicle": invoice.vehicle_registration
                }
                for invoice in unmatched_invoices
            ],
            "bank_only": [
                {
                    "db_id": tx.id,
                    "id": tx.transaction_id,
                    "amount": tx.amount,
                    "date": tx.date.isoformat() if tx.date else None,
                    "description": tx.description
                }
                for tx in bank_only_transactions
            ]
        }
    finally:
        session.close()


@router.get("/")
@router.get("")
def get_reconciliation_status(
    month: Optional[int] = None,
    year: Optional[int] = None,
    current_user: dict = Depends(get_current_user)
):
    """Get reconciliation statistics (excludes rejected matches)."""
    session = db.get_session()
    org_id = current_user["organization_id"]
    try:
        invoice_q = session.query(Invoice).filter(Invoice.organization_id == org_id)
        match_q = session.query(ReconciliationMatch).filter(
            ReconciliationMatch.organization_id == org_id
        ).join(Invoice).join(BankTransaction, ReconciliationMatch.transaction_id == BankTransaction.id)

        if month and year:
            last_day_num = calendar.monthrange(year, month)[1]
            first_day = datetime(year, month, 1)
            last_day = datetime(year, month, last_day_num, 23, 59, 59)
            invoice_q = invoice_q.filter(Invoice.date >= first_day, Invoice.date <= last_day)
            match_q = match_q.filter(BankTransaction.date >= first_day, BankTransaction.date <= last_day)

        all_matches = match_q.all()
        active = [m for m in all_matches if m.status != 'rejected']

        all_invoices = invoice_q.all()
        total_invoices   = len(all_invoices)
        
        # Calculate matched invoices based on actual reconciliation matches, not invoice status
        matched_invoice_ids = {match.invoice_id for match in active}
        matched_invoices = len(matched_invoice_ids)

        success_rate = round((matched_invoices / total_invoices) * 100) if total_invoices else 0

        return {
            "total_matches":     len(active),
            "confirmed":         len(active),
            "total_invoices":    total_invoices,
            "matched_invoices":  matched_invoices,
            "unmatched_invoices": total_invoices - matched_invoices,
            "success_rate":      success_rate,
        }
    finally:
        session.close()
