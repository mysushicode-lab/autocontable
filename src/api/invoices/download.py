"""Invoice download and view endpoints."""
from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import FileResponse
import os
import logging

logger = logging.getLogger(__name__)

from src.storage.database import db
from src.storage.models import Invoice
from src.api.auth import get_current_user
from src.api.invoices.helpers import resolve_invoice_file_path

router = APIRouter()


@router.get("/{invoice_id}/download")
def download_invoice_pdf(invoice_id: int, current_user: dict = Depends(get_current_user)):
    """Download invoice PDF file"""
    from src.utils.encryption import get_decrypted_path

    session = db.get_session()
    try:
        invoice = session.query(Invoice).filter(
            Invoice.id == invoice_id,
            Invoice.organization_id == current_user["organization_id"]
        ).first()
        if not invoice:
            raise HTTPException(status_code=404, detail="Facture introuvable")

        if not invoice.file_path:
            raise HTTPException(status_code=404, detail="Fichier PDF introuvable")

        file_path = resolve_invoice_file_path(invoice.file_path)
        actual_path = get_decrypted_path(file_path)

        # Create response
        response = FileResponse(
            actual_path,
            media_type="application/pdf",
            filename=os.path.basename(invoice.file_path.replace('.enc', ''))
        )

        # Clean up temp file if decrypted
        if actual_path != file_path:
            import atexit
            atexit.register(lambda: os.remove(actual_path) if os.path.exists(actual_path) else None)

        return response
    finally:
        session.close()


@router.get("/{invoice_id}/view")
def view_invoice_pdf(invoice_id: int, current_user: dict = Depends(get_current_user)):
    """View invoice PDF file in browser"""
    from src.utils.encryption import get_decrypted_path

    session = db.get_session()
    try:
        invoice = session.query(Invoice).filter(
            Invoice.id == invoice_id,
            Invoice.organization_id == current_user["organization_id"],
        ).first()
        if not invoice:
            raise HTTPException(status_code=404, detail="Facture introuvable")

        if not invoice.file_path:
            raise HTTPException(status_code=404, detail="Fichier PDF introuvable")

        file_path = resolve_invoice_file_path(invoice.file_path)
        actual_path = get_decrypted_path(file_path)

        response = FileResponse(
            actual_path,
            media_type="application/pdf",
            headers={"Content-Disposition": f"inline; filename={os.path.basename(invoice.file_path.replace('.enc', ''))}"},
        )

        # Clean up temp file if decrypted
        if actual_path != file_path:
            import atexit
            atexit.register(lambda: os.remove(actual_path) if os.path.exists(actual_path) else None)

        return response
    finally:
        session.close()
