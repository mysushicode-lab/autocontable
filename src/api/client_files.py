"""Client file (dossier client) endpoints — pivot cabinet comptable"""
import os
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional
from datetime import datetime

from src.storage.database import db
from src.storage.models import ClientFile, Invoice, BankTransaction, ReconciliationMatch, InvoiceStatus, ProcessedFileHash
from src.api.auth import get_current_user

_SAFE_DATA_ROOT = os.path.realpath(os.path.join(os.getcwd(), "data"))

router = APIRouter()


class ClientFileCreate(BaseModel):
    name: str
    siret: Optional[str] = None
    activity: Optional[str] = None
    contact_email: Optional[str] = None
    notes: Optional[str] = None


class ClientFileUpdate(BaseModel):
    name: Optional[str] = None
    siret: Optional[str] = None
    activity: Optional[str] = None
    contact_email: Optional[str] = None
    notes: Optional[str] = None
    is_active: Optional[bool] = None


def _serialize(cf: ClientFile) -> dict:
    return {
        "id": cf.id,
        "name": cf.name,
        "siret": cf.siret,
        "activity": cf.activity,
        "contact_email": cf.contact_email,
        "notes": cf.notes,
        "is_active": cf.is_active,
        "created_at": cf.created_at.isoformat() if cf.created_at else None,
    }


@router.get("/")
@router.get("")
def list_client_files(current_user: dict = Depends(get_current_user)):
    """List all dossiers clients for the cabinet."""
    session = db.get_session()
    org_id = current_user["organization_id"]
    try:
        files = session.query(ClientFile).filter(
            ClientFile.organization_id == org_id
        ).order_by(ClientFile.name).all()
        return {"client_files": [_serialize(cf) for cf in files]}
    finally:
        session.close()


@router.post("/")
def create_client_file(payload: ClientFileCreate, current_user: dict = Depends(get_current_user)):
    """Create a new dossier client."""
    session = db.get_session()
    org_id = current_user["organization_id"]
    try:
        cf = ClientFile(
            organization_id=org_id,
            name=payload.name,
            siret=payload.siret,
            activity=payload.activity,
            contact_email=payload.contact_email,
            notes=payload.notes,
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow(),
        )
        session.add(cf)
        session.commit()
        session.refresh(cf)
        return {"message": "Dossier créé", "client_file": _serialize(cf)}
    finally:
        session.close()


@router.get("/summary")
def list_client_files_summary(current_user: dict = Depends(get_current_user)):
    """Portfolio view: each dossier with invoice counts, total, reconciliation state."""
    session = db.get_session()
    org_id = current_user["organization_id"]
    try:
        files = session.query(ClientFile).filter(
            ClientFile.organization_id == org_id,
            ClientFile.is_active == True,
        ).order_by(ClientFile.name).all()

        result = []
        for cf in files:
            invoices = session.query(Invoice).filter(
                Invoice.client_file_id == cf.id
            ).all()
            total_amount = sum(inv.amount or 0 for inv in invoices)
            matched = sum(1 for inv in invoices if inv.status == InvoiceStatus.MATCHED)
            pending = sum(1 for inv in invoices if inv.status in (InvoiceStatus.PENDING, InvoiceStatus.UNMATCHED))

            # Status traffic-light
            if not invoices:
                status = "empty"
            elif pending == 0:
                status = "ok"
            elif pending <= 3:
                status = "warning"
            else:
                status = "alert"

            result.append({
                **_serialize(cf),
                "invoice_count": len(invoices),
                "total_amount": total_amount,
                "matched_count": matched,
                "pending_count": pending,
                "status": status,
            })

        return {"client_files": result}
    finally:
        session.close()


@router.get("/{file_id}")
def get_client_file(file_id: int, current_user: dict = Depends(get_current_user)):
    session = db.get_session()
    org_id = current_user["organization_id"]
    try:
        cf = session.query(ClientFile).filter(
            ClientFile.id == file_id,
            ClientFile.organization_id == org_id,
        ).first()
        if not cf:
            raise HTTPException(status_code=404, detail="Dossier introuvable")
        return _serialize(cf)
    finally:
        session.close()


@router.put("/{file_id}")
def update_client_file(file_id: int, payload: ClientFileUpdate, current_user: dict = Depends(get_current_user)):
    session = db.get_session()
    org_id = current_user["organization_id"]
    try:
        cf = session.query(ClientFile).filter(
            ClientFile.id == file_id,
            ClientFile.organization_id == org_id,
        ).first()
        if not cf:
            raise HTTPException(status_code=404, detail="Dossier introuvable")
        for field, value in payload.model_dump(exclude_none=True).items():
            setattr(cf, field, value)
        cf.updated_at = datetime.utcnow()
        session.commit()
        session.refresh(cf)
        return {"message": "Dossier mis à jour", "client_file": _serialize(cf)}
    finally:
        session.close()


@router.delete("/{file_id}")
def delete_client_file(file_id: int, current_user: dict = Depends(get_current_user)):
    """Hard-delete: removes dossier, all linked invoices (files + hashes + matches), then the dossier itself."""
    session = db.get_session()
    org_id = current_user["organization_id"]
    try:
        cf = session.query(ClientFile).filter(
            ClientFile.id == file_id,
            ClientFile.organization_id == org_id,
        ).first()
        if not cf:
            raise HTTPException(status_code=404, detail="Dossier introuvable")

        invoices = session.query(Invoice).filter(
            Invoice.client_file_id == file_id,
            Invoice.organization_id == org_id,
        ).all()

        for invoice in invoices:
            # Delete physical file
            if invoice.file_path:
                try:
                    safe = os.path.realpath(
                        invoice.file_path if os.path.isabs(invoice.file_path)
                        else os.path.join(os.getcwd(), invoice.file_path.lstrip('/\\'))
                    )
                    if safe.startswith(_SAFE_DATA_ROOT + os.sep) and os.path.exists(safe):
                        os.remove(safe)
                except Exception:
                    pass
            # Delete hash
            if invoice.content_hash:
                session.query(ProcessedFileHash).filter(
                    ProcessedFileHash.content_hash == invoice.content_hash,
                    ProcessedFileHash.organization_id == org_id,
                ).delete()
            # Delete reconciliation matches
            session.query(ReconciliationMatch).filter(
                ReconciliationMatch.invoice_id == invoice.id,
                ReconciliationMatch.organization_id == org_id,
            ).delete()
            session.delete(invoice)

        session.delete(cf)
        session.commit()
        return {"message": "Dossier et factures supprimés", "deleted_invoices": len(invoices)}
    finally:
        session.close()
