"""Invoice CRUD endpoints: list, get, update, delete, clear-hashes."""
from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy import or_
from typing import Optional
from datetime import datetime
import os
import logging

logger = logging.getLogger(__name__)

from src.storage.database import db
from src.storage.models import (
    Invoice, Supplier, ReconciliationMatch, InvoiceStatus,
    ProcessedFileHash, User
)
from src.api.utils import get_month_date_range
from src.api.schemas import UpdateInvoiceRequest
from src.api.auth import get_current_user
from src.api.audit import log_action
from src.api.invoices.helpers import _SAFE_DATA_ROOT

router = APIRouter()


@router.get("/")
def list_invoices(
    status: Optional[str] = None,
    category: Optional[str] = None,
    search: Optional[str] = None,
    reference_number: Optional[str] = None,
    supplier: Optional[str] = None,
    month: Optional[int] = None,
    year: Optional[int] = None,
    include_reconciled: Optional[bool] = False,
    client_file_id: Optional[int] = None,
    current_user: dict = Depends(get_current_user)
):
    """List all invoices with optional filters"""
    session = db.get_session()
    try:
        from src.api.permissions import user_has_access
        from src.storage.models import ClientFile

        org_id = current_user["organization_id"]
        role = current_user.get("role", "accountant")
        user_id = current_user["id"]

        # For clients, force client_file_id to their own dossier
        if role == "client":
            user = session.query(User).get(user_id)
            if not user or not user.client_file_id:
                raise HTTPException(403, "Aucun dossier associé à votre compte")
            client_file_id = user.client_file_id

        # Verify access if client_file_id is specified
        if client_file_id is not None:
            has_access = user_has_access(session, user_id, client_file_id, org_id, role, "read_only")
            if not has_access:
                raise HTTPException(403, "Accès refusé à ce dossier")

        query = session.query(Invoice).filter(Invoice.organization_id == org_id)

        if client_file_id is not None:
            query = query.filter(Invoice.client_file_id == client_file_id)

        if status:
            query = query.filter(Invoice.status == InvoiceStatus(status))

        if category:
            query = query.filter(Invoice.category == category)

        if reference_number:
            query = query.filter(Invoice.reference_number == reference_number.upper())

        if supplier:
            query = query.join(Invoice.supplier).filter(Supplier.name.ilike(f"%{supplier}%"))

        if search:
            pattern = f"%{search}%"
            query = query.filter(
                or_(
                    Invoice.invoice_number.ilike(pattern),
                    Invoice.reference_number.ilike(pattern),
                    Invoice.work_order_reference.ilike(pattern),
                    Invoice.email_subject.ilike(pattern)
                )
            )

        if month and year:
            first_day, last_day = get_month_date_range(year, month)
            query = query.filter(Invoice.date >= first_day, Invoice.date <= last_day)

        invoices = query.all()

        # If include_reconciled is True, also include invoices matched to transactions in the selected month
        if include_reconciled and month and year:
            from src.storage.models import BankTransaction
            matches = session.query(ReconciliationMatch).join(Invoice).join(
                BankTransaction, ReconciliationMatch.transaction_id == BankTransaction.id
            ).filter(
                BankTransaction.date >= first_day,
                BankTransaction.date <= last_day,
                Invoice.organization_id == current_user["organization_id"]
            ).all()

            matched_invoice_ids = {inv.id for inv in invoices}
            for match in matches:
                if match.status != 'rejected' and match.invoice_id not in matched_invoice_ids:
                    invoices.append(match.invoice)
                    matched_invoice_ids.add(match.invoice_id)

        return {
            "count": len(invoices),
            "invoices": [
                {
                    "id": inv.id,
                    "invoice_number": inv.invoice_number,
                    "supplier": inv.supplier.name if inv.supplier else None,
                    "amount": inv.amount,
                    "amount_ht": inv.amount_ht,
                    "amount_tax": inv.amount_tax,
                    "date": inv.date.isoformat() if inv.date else None,
                    "due_date": inv.due_date.isoformat() if inv.due_date else None,
                    "category": inv.category,
                    "status": inv.status.value if inv.status else None,
                    "purchase_order": inv.purchase_order,
                    "delivery_note": inv.delivery_note,
                    "reference_number": inv.reference_number,
                    "work_order_reference": inv.work_order_reference,
                    "payment_method": inv.payment_method
                }
                for inv in invoices
            ]
        }
    except ValueError:
        raise HTTPException(status_code=400, detail="Statut de facture invalide")
    finally:
        session.close()


@router.delete("/clear-hashes")
def clear_processed_hashes(current_user: dict = Depends(get_current_user)):
    """Clear all processed file hashes for the organization to allow re-import of all files"""
    session = db.get_session()
    try:
        deleted_count = session.query(ProcessedFileHash).filter(
            ProcessedFileHash.organization_id == current_user["organization_id"]
        ).delete()
        session.commit()
        return {"message": f"Cleared {deleted_count} processed file hashes"}
    finally:
        session.close()


@router.delete("/{invoice_id}")
def delete_invoice(invoice_id: int, current_user: dict = Depends(get_current_user), request: Request = None):
    """Delete an invoice and its file"""
    session = db.get_session()
    try:
        invoice = session.query(Invoice).filter(
            Invoice.id == invoice_id,
            Invoice.organization_id == current_user["organization_id"]
        ).first()
        if not invoice:
            raise HTTPException(status_code=404, detail="Facture introuvable")

        # Store details before deletion
        invoice_details = {
            "invoice_number": invoice.invoice_number,
            "amount": invoice.amount,
            "supplier": invoice.supplier.name if invoice.supplier else None,
        }
        # Delete the file if it exists and is within the safe data root
        if invoice.file_path:
            try:
                safe = os.path.realpath(invoice.file_path if os.path.isabs(invoice.file_path)
                                        else os.path.join(os.getcwd(), invoice.file_path.lstrip('/\\')))
                if safe.startswith(_SAFE_DATA_ROOT + os.sep) and os.path.exists(safe):
                    os.remove(safe)
            except Exception:
                pass
        # Delete the processed file hash to allow re-import
        if invoice.content_hash:
            session.query(ProcessedFileHash).filter(
                ProcessedFileHash.content_hash == invoice.content_hash,
                ProcessedFileHash.organization_id == current_user["organization_id"]
            ).delete()
        session.query(ReconciliationMatch).filter(
            ReconciliationMatch.invoice_id == invoice_id,
            ReconciliationMatch.organization_id == current_user["organization_id"]
        ).delete()
        session.delete(invoice)
        session.commit()

        # Log audit trail
        ip_address = request.client.host if request else None
        log_action(
            session,
            current_user["organization_id"],
            current_user["id"],
            "delete",
            "invoice",
            invoice_id,
            invoice_details,
            ip_address
        )

        return {"message": "Invoice deleted"}
    finally:
        session.close()


@router.get("/{invoice_id}")
def get_invoice(invoice_id: int, current_user: dict = Depends(get_current_user)):
    """Get single invoice by ID"""
    session = db.get_session()
    try:
        invoice = session.query(Invoice).filter(
            Invoice.id == invoice_id,
            Invoice.organization_id == current_user["organization_id"]
        ).first()

        if not invoice:
            raise HTTPException(status_code=404, detail="Facture introuvable")

        return {
            "id": invoice.id,
            "invoice_number": invoice.invoice_number,
            "supplier": invoice.supplier.name if invoice.supplier else None,
            "amount": invoice.amount,
            "amount_tax": invoice.amount_tax,
            "date": invoice.date.isoformat() if invoice.date else None,
            "due_date": invoice.due_date.isoformat() if invoice.due_date else None,
            "category": invoice.category,
            "status": invoice.status.value if invoice.status else None,
            "purchase_order": invoice.purchase_order,
            "delivery_note": invoice.delivery_note,
            "reference_number": invoice.reference_number,
            "work_order_reference": invoice.work_order_reference,
            "payment_method": invoice.payment_method,
            "file_path": invoice.file_path,
            "email_subject": invoice.email_subject,
            "email_from": invoice.email_from
        }
    finally:
        session.close()


@router.put("/{invoice_id}")
def update_invoice(
    invoice_id: int,
    request: UpdateInvoiceRequest,
    current_user: dict = Depends(get_current_user),
    req: Request = None
):
    """Update invoice fields and propagate changes"""
    session = db.get_session()
    try:
        invoice = session.query(Invoice).filter(
            Invoice.id == invoice_id,
            Invoice.organization_id == current_user["organization_id"]
        ).first()
        if not invoice:
            raise HTTPException(status_code=404, detail="Facture introuvable")

        # Store old values for audit
        old_values = {
            "invoice_number": invoice.invoice_number,
            "amount": invoice.amount,
            "supplier": invoice.supplier.name if invoice.supplier else None,
        }
        if request.invoice_number is not None:
            invoice.invoice_number = request.invoice_number
        if request.amount is not None:
            invoice.amount = request.amount
        if request.amount_ht is not None:
            invoice.amount_ht = request.amount_ht
        if request.amount_tax is not None:
            invoice.amount_tax = request.amount_tax
        if request.date is not None:
            try:
                invoice.date = datetime.fromisoformat(request.date)
            except ValueError:
                try:
                    invoice.date = datetime.strptime(request.date, "%Y-%m-%d")
                except ValueError:
                    raise HTTPException(
                        status_code=422,
                        detail=f"Format de date invalide : {request.date}. Format attendu : AAAA-MM-JJ"
                    )
        if request.due_date is not None:
            if request.due_date:
                try:
                    invoice.due_date = datetime.fromisoformat(request.due_date)
                except ValueError:
                    try:
                        invoice.due_date = datetime.strptime(request.due_date, "%Y-%m-%d")
                    except ValueError:
                        raise HTTPException(
                            status_code=422,
                            detail=f"Format de date d'échéance invalide : {request.due_date}. Format attendu : AAAA-MM-JJ"
                        )
            else:
                invoice.due_date = None
        if request.category is not None:
            invoice.category = request.category
        if request.reference_number is not None:
            invoice.reference_number = request.reference_number.upper() if request.reference_number else None
        if request.work_order_reference is not None:
            invoice.work_order_reference = request.work_order_reference
        if request.purchase_order is not None:
            invoice.purchase_order = request.purchase_order
        if request.payment_method is not None:
            invoice.payment_method = request.payment_method
        if request.status is not None:
            try:
                invoice.status = InvoiceStatus(request.status)
            except ValueError:
                pass
        if request.supplier_name is not None:
            if request.supplier_name:
                org_id = current_user["organization_id"]
                normalized = request.supplier_name.lower().strip()
                sup = session.query(Supplier).filter(
                    Supplier.organization_id == org_id,
                    Supplier.name == request.supplier_name,
                ).first()
                if not sup:
                    sup = session.query(Supplier).filter(
                        Supplier.organization_id == org_id,
                        Supplier.normalized_name == normalized,
                    ).first()
                if sup:
                    invoice.supplier_id = sup.id
                else:
                    new_supplier = Supplier(
                        name=request.supplier_name,
                        normalized_name=normalized,
                        organization_id=org_id,
                    )
                    session.add(new_supplier)
                    session.flush()
                    invoice.supplier_id = new_supplier.id

        session.commit()
        session.refresh(invoice)

        # Log audit trail
        ip_address = req.client.host if req else None
        new_values = {
            "invoice_number": invoice.invoice_number,
            "amount": invoice.amount,
            "supplier": invoice.supplier.name if invoice.supplier else None,
        }
        log_action(
            session,
            current_user["organization_id"],
            current_user["id"],
            "update",
            "invoice",
            invoice.id,
            {"old_value": old_values, "new_value": new_values},
            ip_address
        )

        return {
            "message": "Invoice updated successfully",
            "invoice": {
                "id": invoice.id,
                "invoice_number": invoice.invoice_number,
                "amount": invoice.amount,
                "date": invoice.date.isoformat() if invoice.date else None,
            }
        }
    except HTTPException:
        session.rollback()
        raise
    except Exception as exc:
        session.rollback()
        raise HTTPException(status_code=422, detail=str(exc))
    finally:
        session.close()
