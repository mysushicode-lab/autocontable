"""Invoice upload endpoint."""
from fastapi import APIRouter, UploadFile, File, Depends, HTTPException, Request
from typing import Optional
import os
import hashlib
import logging

logger = logging.getLogger(__name__)

from src.storage.database import db
from src.storage.models import Invoice, ProcessedFileHash
from src.invoice_processor import InvoiceProcessor
from src.api.utils import save_uploaded_file, create_or_update_invoice
from src.api.auth import check_trial_active
from src.reconciliation import run_auto_reconciliation
from src.api.audit import log_action
from src.api.webhooks import fire_webhook
from src.utils.paths import INVOICE_UPLOAD_DIR

router = APIRouter()


@router.post("/upload")
async def upload_invoice(
    file: UploadFile = File(...),
    client_file_id: Optional[int] = None,
    current_user: dict = Depends(check_trial_active),
    request: Request = None,
):
    """Import a supplier invoice manually, optionally tied to a dossier client."""
    allowed_extensions = {".pdf", ".png", ".jpg", ".jpeg", ".tiff", ".bmp"}
    extension = os.path.splitext(file.filename or "")[1].lower()
    if extension not in allowed_extensions:
        raise HTTPException(status_code=400, detail="Format de fichier facture non supporté")

    file_bytes = await file.read()
    content_hash = hashlib.md5(file_bytes).hexdigest()
    file.file.seek(0)

    saved_path = save_uploaded_file(file, INVOICE_UPLOAD_DIR)
    session = db.get_session()
    org_id = current_user["organization_id"]
    try:
        already_done = session.query(ProcessedFileHash).filter(
            ProcessedFileHash.content_hash == content_hash,
            ProcessedFileHash.organization_id == org_id
        ).first()
        if already_done:
            existing_invoice = session.query(Invoice).filter(
                Invoice.content_hash == content_hash,
                Invoice.organization_id == org_id
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
            # Invoice was deleted -- remove hash to allow re-import
            session.delete(already_done)
            session.commit()

        processor = InvoiceProcessor()
        extracted_data = processor.process_invoice(saved_path)
        invoice = create_or_update_invoice(session, saved_path, extracted_data, org_id)
        if client_file_id is not None:
            invoice.client_file_id = client_file_id

        invoice.content_hash = content_hash
        if not session.query(ProcessedFileHash).filter(
            ProcessedFileHash.content_hash == content_hash,
            ProcessedFileHash.organization_id == org_id
        ).first():
            session.add(ProcessedFileHash(content_hash=content_hash, filename=file.filename, organization_id=org_id))
        session.commit()

        # Store invoice ID before running reconciliation
        invoice_id = invoice.id

        # Run automatic reconciliation after manual import (isolated session inside helper)
        run_auto_reconciliation(org_id)

        # Re-fetch the invoice from the database to get the latest status after reconciliation
        invoice = session.query(Invoice).filter(Invoice.id == invoice_id).first()

        # Log audit trail
        ip_address = request.client.host if request else None
        log_action(
            session,
            org_id,
            current_user["id"],
            "create",
            "invoice",
            invoice.id,
            {"invoice_number": invoice.invoice_number, "amount": invoice.amount, "filename": file.filename},
            ip_address
        )

        # Fire webhook
        fire_webhook(org_id, "invoice.created", {
            "invoice_id": invoice.id,
            "invoice_number": invoice.invoice_number,
            "amount": invoice.amount,
            "supplier": invoice.supplier.name if invoice.supplier else None,
            "client_file_id": invoice.client_file_id,
        })

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
