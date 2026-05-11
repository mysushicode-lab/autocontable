"""Invoice endpoints"""
from fastapi import APIRouter, HTTPException, UploadFile, File, Depends
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from sqlalchemy import or_
from typing import Optional
from datetime import datetime
import os
import hashlib
import calendar

from src.storage.database import db
from src.storage.models import Invoice, Supplier, ReconciliationMatch, InvoiceStatus, ProcessedFileHash
from src.invoice_processor import InvoiceProcessor
from src.api.utils import save_uploaded_file, create_or_update_invoice
from src.api.schemas import UpdateInvoiceRequest
from src.api.auth import get_current_user
from src.reconciliation.reconciliation_engine import ReconciliationEngine

router = APIRouter()

UPLOAD_ROOT = os.path.join("data", "uploads")
INVOICE_UPLOAD_DIR = os.path.join(UPLOAD_ROOT, "invoices")


@router.post("/upload")
async def upload_invoice(file: UploadFile = File(...), current_user: dict = Depends(get_current_user)):
    """Import a supplier invoice manually."""
    allowed_extensions = {".pdf", ".png", ".jpg", ".jpeg", ".tiff", ".bmp"}
    extension = os.path.splitext(file.filename or "")[1].lower()
    if extension not in allowed_extensions:
        raise HTTPException(status_code=400, detail="Unsupported invoice file format")

    file_bytes = await file.read()
    content_hash = hashlib.md5(file_bytes).hexdigest()
    file.file.seek(0)

    saved_path = save_uploaded_file(file, INVOICE_UPLOAD_DIR)
    session = db.get_session()
    try:
        already_done = session.query(ProcessedFileHash).filter(
            ProcessedFileHash.content_hash == content_hash
        ).first()
        if already_done:
            existing_invoice = session.query(Invoice).filter(
                Invoice.content_hash == content_hash
            ).first()
            if existing_invoice:
                return {
                    "message": "Facture déjà importée (fichier identique)",
                    "invoice": {
                        "id": existing_invoice.id,
                        "invoice_number": existing_invoice.invoice_number,
                        "amount": existing_invoice.amount,
                        "status": existing_invoice.status.value if existing_invoice.status else None,
                        "supplier": existing_invoice.supplier.name if existing_invoice.supplier else None,
                    }
                }
            # Invoice was deleted — remove hash to allow re-import
            session.delete(already_done)
            session.commit()

        processor = InvoiceProcessor()
        extracted_data = processor.process_invoice(saved_path)
        invoice = create_or_update_invoice(session, saved_path, extracted_data, current_user["organization_id"])
        
        invoice.content_hash = content_hash
        if invoice.supplier:
            invoice.supplier.organization_id = current_user["organization_id"]
        if not session.query(ProcessedFileHash).filter(ProcessedFileHash.content_hash == content_hash).first():
            session.add(ProcessedFileHash(content_hash=content_hash, filename=file.filename, organization_id=current_user["organization_id"]))
        session.commit()
        
        # Run automatic reconciliation after manual import
        engine = ReconciliationEngine(session)
        engine.reconcile(organization_id=current_user["organization_id"])
        session.commit()
        
        session.refresh(invoice)
        return {
            "message": "Invoice imported successfully",
            "invoice": {
                "id": invoice.id,
                "invoice_number": invoice.invoice_number,
                "amount": invoice.amount,
                "status": invoice.status.value if invoice.status else None,
                "supplier": invoice.supplier.name if invoice.supplier else None,
            }
        }
    except Exception as exc:
        session.rollback()
        raise HTTPException(status_code=400, detail=str(exc))
    finally:
        session.close()


@router.get("/")
@router.get("")
def list_invoices(
    status: Optional[str] = None,
    category: Optional[str] = None,
    search: Optional[str] = None,
    vehicle_registration: Optional[str] = None,
    month: Optional[int] = None,
    year: Optional[int] = None,
    current_user: dict = Depends(get_current_user)
):
    """List all invoices with optional filters"""
    session = db.get_session()
    try:
        query = session.query(Invoice).filter(Invoice.organization_id == current_user["organization_id"])
        
        if status:
            query = query.filter(Invoice.status == InvoiceStatus(status))

        if category:
            query = query.filter(Invoice.category == category)

        if vehicle_registration:
            query = query.filter(Invoice.vehicle_registration == vehicle_registration.upper())

        if search:
            pattern = f"%{search}%"
            query = query.filter(
                or_(
                    Invoice.invoice_number.ilike(pattern),
                    Invoice.vehicle_registration.ilike(pattern),
                    Invoice.work_order_reference.ilike(pattern),
                    Invoice.email_subject.ilike(pattern)
                )
            )
        
        if month and year:
            last_day_num = calendar.monthrange(year, month)[1]
            first_day = datetime(year, month, 1)
            last_day = datetime(year, month, last_day_num, 23, 59, 59)
            query = query.filter(Invoice.date >= first_day, Invoice.date <= last_day)
        
        invoices = query.all()
        
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
                    "vehicle_registration": inv.vehicle_registration,
                    "work_order_reference": inv.work_order_reference,
                    "payment_method": inv.payment_method
                }
                for inv in invoices
            ]
        }
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid invoice status")
    finally:
        session.close()


@router.delete("/{invoice_id}")
def delete_invoice(invoice_id: int, current_user: dict = Depends(get_current_user)):
    """Delete an invoice and its reconciliation matches"""
    session = db.get_session()
    try:
        invoice = session.query(Invoice).filter(Invoice.id == invoice_id, Invoice.organization_id == current_user["organization_id"]).first()
        if not invoice:
            raise HTTPException(status_code=404, detail="Invoice not found")
        session.query(ReconciliationMatch).filter(ReconciliationMatch.invoice_id == invoice_id).delete()
        if invoice.file_path and os.path.exists(invoice.file_path):
            try:
                os.remove(invoice.file_path)
            except Exception:
                pass
        # Delete the processed file hash to allow re-import
        if invoice.content_hash:
            session.query(ProcessedFileHash).filter(
                ProcessedFileHash.content_hash == invoice.content_hash,
                ProcessedFileHash.organization_id == current_user["organization_id"]
            ).delete()
        session.delete(invoice)
        session.commit()
        return {"message": "Invoice deleted"}
    finally:
        session.close()


@router.put("/{invoice_id}")
def update_invoice(invoice_id: int, request: UpdateInvoiceRequest, current_user: dict = Depends(get_current_user)):
    """Update invoice fields and propagate changes"""
    session = db.get_session()
    try:
        invoice = session.query(Invoice).filter(Invoice.id == invoice_id, Invoice.organization_id == current_user["organization_id"]).first()
        if not invoice:
            raise HTTPException(status_code=404, detail="Invoice not found")
        if request.invoice_number is not None:
            invoice.invoice_number = request.invoice_number
        if request.amount is not None:
            invoice.amount = request.amount
        if request.amount_ht is not None:
            invoice.amount_ht = request.amount_ht
        if request.amount_tax is not None:
            invoice.amount_tax = request.amount_tax
        if request.date is not None:
            invoice.date = datetime.fromisoformat(request.date)
        if request.due_date is not None:
            invoice.due_date = datetime.fromisoformat(request.due_date) if request.due_date else None
        if request.category is not None:
            invoice.category = request.category
        if request.vehicle_registration is not None:
            invoice.vehicle_registration = request.vehicle_registration.upper() if request.vehicle_registration else None
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
                supplier = session.query(Supplier).filter(Supplier.name == request.supplier_name).first()
                if not supplier:
                    normalized = request.supplier_name.lower().strip()
                    supplier = Supplier(name=request.supplier_name, normalized_name=normalized)
                    session.add(supplier)
                    session.flush()
                invoice.supplier_id = supplier.id
            else:
                invoice.supplier_id = None
        session.commit()
        session.refresh(invoice)
        return {
            "message": "Invoice updated",
            "invoice": {
                "id": invoice.id,
                "invoice_number": invoice.invoice_number,
                "supplier": invoice.supplier.name if invoice.supplier else None,
                "amount": invoice.amount,
                "amount_ht": invoice.amount_ht,
                "amount_tax": invoice.amount_tax,
                "date": invoice.date.isoformat() if invoice.date else None,
                "due_date": invoice.due_date.isoformat() if invoice.due_date else None,
                "category": invoice.category,
                "vehicle_registration": invoice.vehicle_registration,
                "work_order_reference": invoice.work_order_reference,
                "purchase_order": invoice.purchase_order,
                "payment_method": invoice.payment_method,
                "status": invoice.status.value if invoice.status else None,
            }
        }
    finally:
        session.close()


@router.get("/{invoice_id}")
def get_invoice(invoice_id: int, current_user: dict = Depends(get_current_user)):
    """Get single invoice by ID"""
    session = db.get_session()
    try:
        invoice = session.query(Invoice).filter(Invoice.id == invoice_id, Invoice.organization_id == current_user["organization_id"]).first()
        
        if not invoice:
            raise HTTPException(status_code=404, detail="Invoice not found")
        
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
            "vehicle_registration": invoice.vehicle_registration,
            "work_order_reference": invoice.work_order_reference,
            "payment_method": invoice.payment_method,
            "file_path": invoice.file_path,
            "email_subject": invoice.email_subject,
            "email_from": invoice.email_from
        }
    finally:
        session.close()


@router.get("/{invoice_id}/download")
def download_invoice_pdf(invoice_id: int, current_user: dict = Depends(get_current_user)):
    """Download invoice PDF file"""
    session = db.get_session()
    try:
        invoice = session.query(Invoice).filter(Invoice.id == invoice_id, Invoice.organization_id == current_user["organization_id"]).first()
        if not invoice:
            raise HTTPException(status_code=404, detail="Invoice not found")
        
        if not invoice.file_path or not os.path.exists(invoice.file_path):
            raise HTTPException(status_code=404, detail="PDF file not found")
        
        return FileResponse(
            invoice.file_path,
            media_type="application/pdf",
            filename=os.path.basename(invoice.file_path)
        )
    finally:
        session.close()
