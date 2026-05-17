"""Utility functions for API"""
import os
import shutil
import hashlib
import json
from datetime import datetime
from sqlalchemy.orm import Session
from fastapi import UploadFile

from src.storage.models import Invoice, ReconciliationMatch
from src.classifier import SupplierClassifier, CategoryClassifier


def ensure_directory(path: str) -> None:
    """Create directory if it doesn't exist"""
    os.makedirs(path, exist_ok=True)


def save_uploaded_file(upload: UploadFile, target_dir: str) -> str:
    """Save uploaded file to target directory with timestamp"""
    ensure_directory(target_dir)
    timestamp = datetime.utcnow().strftime("%Y%m%d%H%M%S%f")
    filename = f"{timestamp}_{os.path.basename(upload.filename)}"
    output_path = os.path.join(target_dir, filename)
    with open(output_path, "wb") as buffer:
        shutil.copyfileobj(upload.file, buffer)
    return output_path


def build_invoice_number(file_path: str) -> str:
    """Generate invoice number for manual imports"""
    return f"MANUAL-{datetime.utcnow().strftime('%Y%m%d-%H%M')}"


def serialize_match(match: ReconciliationMatch) -> dict:
    """Serialize reconciliation match to dict"""
    return {
        "id": match.id,
        "score": round((match.match_score or 0) * 100, 2),
        "status": match.status,
        "match_type": match.match_type,
        "invoice": {
            "id": match.invoice.id,
            "number": match.invoice.invoice_number,
            "supplier": match.invoice.supplier.name if match.invoice.supplier else None,
            "amount": match.invoice.amount,
            "date": match.invoice.date.isoformat() if match.invoice.date else None,
            "vehicle": match.invoice.vehicle_registration,
        },
        "transaction": {
            "db_id": match.transaction.id,
            "id": match.transaction.transaction_id,
            "amount": match.transaction.amount,
            "date": match.transaction.date.isoformat() if match.transaction.date else None,
            "description": match.transaction.description,
        },
    }


def create_or_update_invoice(session: Session, file_path: str, extracted_data: dict, organization_id: int) -> Invoice:
    """Create or update invoice with extracted data"""
    # Security check: organization_id must be provided
    if not organization_id:
        raise ValueError("organization_id is required for invoice creation")
    
    supplier_classifier = SupplierClassifier(session, org_id=organization_id)
    category_classifier = CategoryClassifier()
    supplier = supplier_classifier.detect_supplier(extracted_data)
    
    # Try invoice_number first, then fallback to PO/BC/SO/OR numbers, then timestamp
    invoice_number = extracted_data.get("invoice_number")
    if not invoice_number:
        invoice_number = extracted_data.get("purchase_order")
    if not invoice_number:
        invoice_number = extracted_data.get("delivery_note")
    if not invoice_number:
        invoice_number = extracted_data.get("work_order_reference")
    if not invoice_number:
        invoice_number = build_invoice_number(file_path)
    
    extraction_confidence = extracted_data.get("extraction_confidence", "low")

    invoice = session.query(Invoice).filter(
        Invoice.invoice_number == invoice_number,
        Invoice.organization_id == organization_id
    ).first()
    
    # Disable autoflush to prevent premature INSERT before all fields are set
    with session.no_autoflush:
        if invoice is None:
            invoice = Invoice(invoice_number=invoice_number, organization_id=organization_id)
            session.add(invoice)
        else:
            # Security: ensure organization_id is updated to current user's org
            invoice.organization_id = organization_id

        invoice.supplier_id = supplier.id if supplier else None
        invoice.amount = extracted_data.get("amount") or 0.0
        invoice.amount_ht = extracted_data.get("amount_ht")
        invoice.amount_tax = extracted_data.get("amount_tax")
        invoice.date = extracted_data.get("date") or datetime.utcnow()
        invoice.due_date = extracted_data.get("due_date")
        invoice.category = extracted_data.get("category") or category_classifier.classify(extracted_data)
        from src.storage.models import InvoiceStatus
        invoice.status = InvoiceStatus.PROCESSED if extraction_confidence in {"high", "medium"} else InvoiceStatus.PENDING
    invoice.purchase_order = extracted_data.get("purchase_order")
    invoice.delivery_note = extracted_data.get("delivery_note")
    invoice.vehicle_registration = extracted_data.get("vehicle_registration")
    invoice.work_order_reference = extracted_data.get("work_order_reference")
    invoice.payment_method = extracted_data.get("payment_method")
    invoice.file_path = file_path
    invoice.email_subject = extracted_data.get("email_subject") or "Import manuel"
    invoice.email_from = extracted_data.get("email_from")
    invoice.email_date = extracted_data.get("email_date")
    invoice.extracted_data = json.dumps(extracted_data, default=str)

    session.commit()
    session.refresh(invoice)
    return invoice


def get_db():
    """Get database session dependency"""
    from src.storage.database import db
    session = db.get_session()
    try:
        yield session
    finally:
        session.close()
