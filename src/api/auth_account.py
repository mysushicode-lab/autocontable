"""Account management endpoints: data export and account deletion (RGPD)."""
import json
from datetime import datetime

from fastapi import APIRouter, HTTPException, Depends, Request
from fastapi.responses import Response

from src.storage.database import db
from src.storage.models import (
    User, UserToken, Organization, UserRole, PasswordResetToken,
    DossierPermission, Invoice, BankTransaction, ReconciliationMatch,
    ClientFile, AuditLog, ProcessedFileHash, Settings as SettingsModel, Supplier
)
from src.api.auth_helpers import get_current_user
from src.api.rate_limit import limiter

router = APIRouter()


@router.get("/data-export")
@limiter.limit("3/hour")
def export_user_data(request: Request, current_user: dict = Depends(get_current_user)):
    """Export all data for the authenticated user (RGPD Article 20)"""
    session = db.get_session()
    try:
        user = session.query(User).filter(User.id == current_user["id"]).first()
        if not user:
            raise HTTPException(status_code=404, detail="Utilisateur introuvable")

        invoices = session.query(Invoice).filter(Invoice.organization_id == user.organization_id).all()
        transactions = session.query(BankTransaction).filter(BankTransaction.organization_id == user.organization_id).all()
        settings = session.query(SettingsModel).filter(SettingsModel.organization_id == user.organization_id).all()

        payload = {
            "exported_at": datetime.utcnow().isoformat() + "Z",
            "profile": {
                "id": user.id,
                "username": user.username,
                "name": user.name,
                "email": user.email,
                "role": user.role.value if user.role else None,
                "created_at": user.created_at.isoformat() if user.created_at else None,
            },
            "invoices": [
                {
                    "id": inv.id,
                    "invoice_number": inv.invoice_number,
                    "amount": inv.amount,
                    "date": inv.date.isoformat() if inv.date else None,
                    "status": inv.status.value if inv.status else None,
                }
                for inv in invoices
            ],
            "transactions": [
                {
                    "id": tr.id,
                    "description": tr.description,
                    "amount": tr.amount,
                    "date": tr.date.isoformat() if tr.date else None,
                }
                for tr in transactions
            ],
            "settings": [{"key": s.key, "value": s.value} for s in settings if s.key not in ("email_password",)],
        }

        content = json.dumps(payload, ensure_ascii=False, indent=2)
        return Response(
            content=content,
            media_type="application/json",
            headers={"Content-Disposition": f"attachment; filename=factpilot-export-{user.username}.json"}
        )
    finally:
        session.close()


@router.delete("/delete-account")
def delete_own_account(current_user: dict = Depends(get_current_user)):
    """Delete the authenticated user's own account and all associated data (RGPD Art. 17)."""
    session = db.get_session()
    try:
        user = session.query(User).filter(User.id == current_user["id"]).first()
        if not user:
            raise HTTPException(status_code=404, detail="Compte introuvable")

        org_id = user.organization_id

        # Check if user is the last admin -- if so, delete entire org data
        admin_count = session.query(User).filter(
            User.organization_id == org_id,
            User.role == UserRole.ADMIN
        ).count()

        if admin_count <= 1 and user.role == UserRole.ADMIN:
            # Last admin: purge all org data
            session.query(ReconciliationMatch).filter(ReconciliationMatch.organization_id == org_id).delete()
            session.query(ProcessedFileHash).filter(ProcessedFileHash.organization_id == org_id).delete()
            session.query(Invoice).filter(Invoice.organization_id == org_id).delete()
            session.query(BankTransaction).filter(BankTransaction.organization_id == org_id).delete()
            session.query(Supplier).filter(Supplier.organization_id == org_id).delete()
            session.query(ClientFile).filter(ClientFile.organization_id == org_id).delete()
            session.query(AuditLog).filter(AuditLog.organization_id == org_id).delete()
            session.query(SettingsModel).filter(SettingsModel.organization_id == org_id).delete()
            # Delete all org users' tokens and permissions
            org_users = session.query(User).filter(User.organization_id == org_id).all()
            for u in org_users:
                session.query(UserToken).filter(UserToken.user_id == u.id).delete()
                session.query(DossierPermission).filter(DossierPermission.user_id == u.id).delete()
                session.query(PasswordResetToken).filter(PasswordResetToken.user_id == u.id).delete()
            session.query(User).filter(User.organization_id == org_id).delete()
            session.query(Organization).filter(Organization.id == org_id).delete()
        else:
            # Not last admin: only delete this user's data
            session.query(UserToken).filter(UserToken.user_id == user.id).delete()
            session.query(DossierPermission).filter(DossierPermission.user_id == user.id).delete()
            session.query(PasswordResetToken).filter(PasswordResetToken.user_id == user.id).delete()
            session.query(AuditLog).filter(AuditLog.user_id == user.id).delete()
            session.delete(user)

        session.commit()
        return {"message": "Compte et données supprimés"}
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()
