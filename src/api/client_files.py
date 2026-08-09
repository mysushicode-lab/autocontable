"""Client file (dossier client) endpoints — pivot cabinet comptable"""
import os
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional
from datetime import datetime

from src.storage.database import db
from src.storage.models import ClientFile, Invoice, BankTransaction, ReconciliationMatch, InvoiceStatus, ProcessedFileHash
from src.api.auth import get_current_user
from src.utils.siret import validate_siret
from src.api.webhooks import fire_webhook

_SAFE_DATA_ROOT = os.path.realpath(os.path.join(os.getcwd(), "data"))

router = APIRouter()


class ClientFileCreate(BaseModel):
    name: str
    siret: Optional[str] = None
    activity: Optional[str] = None
    contact_email: Optional[str] = None
    scheduler_email: Optional[str] = None
    phone: Optional[str] = None  # Accept 'phone' from frontend
    notes: Optional[str] = None
    color: Optional[str] = '#3b82f6'


class ClientFileUpdate(BaseModel):
    name: Optional[str] = None
    siret: Optional[str] = None
    activity: Optional[str] = None
    contact_email: Optional[str] = None
    scheduler_email: Optional[str] = None
    phone: Optional[str] = None  # Accept 'phone' from frontend
    notes: Optional[str] = None
    color: Optional[str] = None
    is_active: Optional[bool] = None


def _serialize(cf: ClientFile) -> dict:
    return {
        "id": cf.id,
        "name": cf.name,
        "siret": cf.siret,
        "activity": cf.activity,
        "contact_email": cf.contact_email,
        "scheduler_email": cf.scheduler_email,
        "contact_phone": cf.contact_phone,
        "notes": cf.notes,
        "color": cf.color,
        "is_active": cf.is_active,
        "created_at": cf.created_at.isoformat() if cf.created_at else None,
    }


@router.get("/")
@router.get("")
def list_client_files(current_user: dict = Depends(get_current_user)):
    """List all dossiers clients for the cabinet."""
    from src.api.permissions import get_accessible_dossier_ids

    session = db.get_session()
    org_id = current_user["organization_id"]
    role = current_user.get("role", "accountant")
    try:
        if role == "admin":
            files = session.query(ClientFile).filter(
                ClientFile.organization_id == org_id
            ).order_by(ClientFile.name).all()
        else:
            accessible_ids = get_accessible_dossier_ids(session, current_user["id"], org_id, role)
            files = session.query(ClientFile).filter(
                ClientFile.organization_id == org_id,
                ClientFile.id.in_(accessible_ids)
            ).order_by(ClientFile.name).all()
        return {"client_files": [_serialize(cf) for cf in files]}
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


def _require_management_role(current_user: dict):
    """Raise 403 if user is not admin or accountant."""
    role = current_user.get("role", "")
    if role not in ("admin", "accountant"):
        raise HTTPException(status_code=403, detail="Accès réservé aux administrateurs et comptables")


@router.post("/")
@router.post("")
def create_client_file(payload: ClientFileCreate, current_user: dict = Depends(get_current_user)):
    """Create a new dossier client."""
    _require_management_role(current_user)
    if payload.siret:
        siret_check = validate_siret(payload.siret)
        if not siret_check["valid"]:
            raise HTTPException(status_code=400, detail=siret_check["error"])

    session = db.get_session()
    org_id = current_user["organization_id"]
    try:
        # Lock the org row to serialize concurrent dossier creations (PostgreSQL)
        from src.api.billing import get_org_plan
        from src.storage.models import Organization
        session.query(Organization).filter(Organization.id == org_id).with_for_update().first()

        plan = get_org_plan(session, org_id)
        max_dossiers = plan["max_dossiers"]
        if max_dossiers is not None:
            current_count = session.query(ClientFile).filter(
                ClientFile.organization_id == org_id,
                ClientFile.is_active == True
            ).count()
            if current_count >= max_dossiers:
                raise HTTPException(
                    403,
                    f"Limite de {max_dossiers} dossiers atteinte pour le plan {plan['label']}. Passez au plan supérieur."
                )
        cf = ClientFile(
            organization_id=org_id,
            name=payload.name,
            siret=payload.siret,
            activity=payload.activity,
            contact_email=payload.contact_email,
            scheduler_email=payload.scheduler_email,
            contact_phone=payload.phone,  # Map 'phone' to 'contact_phone'
            notes=payload.notes,
            color=payload.color,
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow(),
        )
        session.add(cf)
        session.commit()
        session.refresh(cf)

        # Auto-create WhatsApp phone mapping if phone provided
        if payload.phone:
            from src.storage.models import Settings
            phone_clean = payload.phone.strip().replace("+", "").replace(" ", "").replace("-", "")
            key = f"wa_phone_{phone_clean}"
            existing = session.query(Settings).filter(
                Settings.organization_id == org_id,
                Settings.key == key,
                Settings.category == "whatsapp",
            ).first()
            if not existing:
                session.add(Settings(
                    organization_id=org_id,
                    key=key,
                    value=str(cf.id),
                    category="whatsapp",
                ))
                session.commit()

        # Fire webhook
        fire_webhook(org_id, "dossier.created", {
            "client_file_id": cf.id,
            "name": cf.name,
            "siret": cf.siret,
        })

        return {"message": "Dossier créé", "client_file": _serialize(cf)}
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


@router.get("/summary")
def list_client_files_summary(current_user: dict = Depends(get_current_user)):
    """Portfolio view: each dossier with invoice counts, total, reconciliation state."""
    from src.api.permissions import get_accessible_dossier_ids

    session = db.get_session()
    org_id = current_user["organization_id"]
    role = current_user.get("role", "accountant")
    try:
        if role == "admin":
            files = session.query(ClientFile).filter(
                ClientFile.organization_id == org_id,
                ClientFile.is_active == True,
            ).order_by(ClientFile.name).all()
        else:
            accessible_ids = get_accessible_dossier_ids(session, current_user["id"], org_id, role)
            files = session.query(ClientFile).filter(
                ClientFile.organization_id == org_id,
                ClientFile.is_active == True,
                ClientFile.id.in_(accessible_ids)
            ).order_by(ClientFile.name).all()

        result = []
        for cf in files:
            invoices = session.query(Invoice).filter(
                Invoice.client_file_id == cf.id
            ).all()
            total_amount = sum(inv.amount or 0 for inv in invoices)
            matched = sum(1 for inv in invoices if inv.status == InvoiceStatus.MATCHED)
            pending = sum(1 for inv in invoices if inv.status in (InvoiceStatus.PENDING, InvoiceStatus.UNMATCHED))

            # Status traffic-light based on match rate
            if not invoices:
                status = "empty"
            elif pending == 0:
                status = "ok"
            elif matched / len(invoices) >= 0.6:
                status = "ok"
            elif matched / len(invoices) >= 0.35:
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
    except Exception:
        session.rollback()
        raise
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
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


@router.put("/{file_id}")
def update_client_file(file_id: int, payload: ClientFileUpdate, current_user: dict = Depends(get_current_user)):
    _require_management_role(current_user)
    if payload.siret:
        siret_check = validate_siret(payload.siret)
        if not siret_check["valid"]:
            raise HTTPException(status_code=400, detail=siret_check["error"])

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
            # Map 'phone' to 'contact_phone' in database
            if field == 'phone':
                setattr(cf, 'contact_phone', value)
            else:
                setattr(cf, field, value)
        cf.updated_at = datetime.utcnow()
        session.commit()
        session.refresh(cf)
        return {"message": "Dossier mis à jour", "client_file": _serialize(cf)}
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


@router.get("/validate-siret/{siret}")
def check_siret(siret: str, current_user: dict = Depends(get_current_user)):
    """Validate a SIRET number."""
    result = validate_siret(siret)
    return result


@router.delete("/{file_id}")
def delete_client_file(file_id: int, current_user: dict = Depends(get_current_user)):
    """Hard-delete: removes dossier, all linked invoices (files + hashes + matches), then the dossier itself."""
    _require_management_role(current_user)
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
