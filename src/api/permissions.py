"""Dossier permission management endpoints."""
import os
import secrets
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException
from src.storage.database import db
from src.storage.models import DossierPermission, ClientFile, User, UserRole, InvitationToken
from src.api.auth import get_current_user
from src.api.billing import require_feature

router = APIRouter()


_PERMISSION_HIERARCHY = {"read_only": 0, "read_write": 1, "admin": 2}


def user_has_access(session, user_id: int, client_file_id: int, org_id: int, role: str, required_level: str = "read_only") -> bool:
    """Check if a user has access to a specific dossier at the required level.

    Admins always have full access to all dossiers in their org.
    Other users need explicit permission at or above the required level.
    """
    dossier = session.query(ClientFile).filter(
        ClientFile.id == client_file_id,
        ClientFile.organization_id == org_id
    ).first()
    if not dossier:
        return False

    if role == 'admin':
        return True

    perm = session.query(DossierPermission).filter(
        DossierPermission.user_id == user_id,
        DossierPermission.client_file_id == client_file_id,
    ).first()
    if not perm:
        return False

    user_level = _PERMISSION_HIERARCHY.get(perm.permission_level, 0)
    needed_level = _PERMISSION_HIERARCHY.get(required_level, 0)
    return user_level >= needed_level


def get_accessible_dossier_ids(session, user_id: int, org_id: int, role: str) -> list:
    """Get list of dossier IDs a user can access.

    Admins get all dossiers. Others get only their permitted ones.
    """
    if role == 'admin':
        dossiers = session.query(ClientFile).filter(
            ClientFile.organization_id == org_id
        ).all()
        return [d.id for d in dossiers]

    # Only return dossiers that belong to the user's org
    perms = session.query(DossierPermission).join(
        ClientFile, DossierPermission.client_file_id == ClientFile.id
    ).filter(
        DossierPermission.user_id == user_id,
        ClientFile.organization_id == org_id,
    ).all()
    return [p.client_file_id for p in perms]


@router.get("/dossier/{client_file_id}")
def get_dossier_permissions(client_file_id: int, current_user: dict = Depends(require_feature("permissions"))):
    """Get all users with access to a dossier. Admin only."""
    if current_user.get("role") != "admin":
        raise HTTPException(403, "Admin requis")

    session = db.get_session()
    try:
        org_id = current_user["organization_id"]
        cf = session.query(ClientFile).filter(
            ClientFile.id == client_file_id,
            ClientFile.organization_id == org_id
        ).first()
        if not cf:
            raise HTTPException(404, "Dossier non trouvé")

        perms = session.query(DossierPermission).filter(
            DossierPermission.client_file_id == client_file_id
        ).all()

        result = []
        for p in perms:
            user = session.query(User).get(p.user_id)
            if user:
                result.append({
                    "user_id": user.id,
                    "username": user.username,
                    "name": user.name,
                    "email": user.email,
                    "permission_level": p.permission_level,
                })

        return {"permissions": result}
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


@router.post("/grant")
def grant_permission(payload: dict, current_user: dict = Depends(require_feature("permissions"))):
    """Grant a user access to a dossier.

    payload: {"user_id": 123, "client_file_id": 456, "permission_level": "read_write"}
    """
    if current_user.get("role") != "admin":
        raise HTTPException(403, "Admin requis")

    session = db.get_session()
    try:
        org_id = current_user["organization_id"]
        user_id = payload.get("user_id")
        cfid = payload.get("client_file_id")
        level = payload.get("permission_level", "read_write")

        if level not in ("read_only", "read_write", "admin"):
            raise HTTPException(400, "permission_level invalide")

        # Verify user and dossier belong to same org
        user = session.query(User).filter(User.id == user_id, User.organization_id == org_id).first()
        if not user:
            raise HTTPException(404, "Utilisateur non trouvé")

        cf = session.query(ClientFile).filter(ClientFile.id == cfid, ClientFile.organization_id == org_id).first()
        if not cf:
            raise HTTPException(404, "Dossier non trouvé")

        # Upsert
        existing = session.query(DossierPermission).filter(
            DossierPermission.user_id == user_id,
            DossierPermission.client_file_id == cfid
        ).first()

        if existing:
            existing.permission_level = level
        else:
            session.add(DossierPermission(
                user_id=user_id,
                client_file_id=cfid,
                permission_level=level,
            ))
        session.commit()
        return {"success": True}
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


@router.post("/revoke")
def revoke_permission(payload: dict, current_user: dict = Depends(require_feature("permissions"))):
    """Revoke a user's access to a dossier.

    payload: {"user_id": 123, "client_file_id": 456}
    """
    if current_user.get("role") != "admin":
        raise HTTPException(403, "Admin requis")

    session = db.get_session()
    try:
        org_id = current_user["organization_id"]
        user_id = payload.get("user_id")
        cfid = payload.get("client_file_id")

        from src.storage.models import ClientFile
        dossier = session.query(ClientFile).filter(
            ClientFile.id == cfid,
            ClientFile.organization_id == org_id
        ).first()
        if not dossier:
            raise HTTPException(404, "Dossier introuvable dans votre organisation")

        perm = session.query(DossierPermission).filter(
            DossierPermission.user_id == user_id,
            DossierPermission.client_file_id == cfid
        ).first()

        if perm:
            session.delete(perm)
            session.commit()

        return {"success": True}
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


@router.post("/invite")
def invite_user_to_dossier(payload: dict, current_user: dict = Depends(require_feature("permissions"))):
    """Generate invitation link for a PME/client to join org and access a dossier.

    payload: {"email": "pme@example.com", "client_file_id": 456, "permission_level": "read_write"}
    Sends email with join link containing the token.
    """
    if current_user.get("role") != "admin":
        raise HTTPException(403, "Admin requis")

    session = db.get_session()
    try:
        org_id = current_user["organization_id"]
        invited_email = payload.get("email", "").lower().strip()
        cfid = payload.get("client_file_id")
        level = payload.get("permission_level", "read_write")

        if not invited_email:
            raise HTTPException(400, "Email manquant")
        if level not in ("read_only", "read_write", "admin"):
            raise HTTPException(400, "permission_level invalide")

        # Verify dossier exists
        cf = session.query(ClientFile).filter(
            ClientFile.id == cfid,
            ClientFile.organization_id == org_id
        ).first()
        if not cf:
            raise HTTPException(404, "Dossier non trouvé")

        # Check if user already exists in org with this email
        existing_user = session.query(User).filter(
            User.email == invited_email,
            User.organization_id == org_id
        ).first()
        if existing_user:
            raise HTTPException(400, f"Utilisateur {invited_email} existe déjà dans l'organisation")

        # Generate invitation token (valid 7 days)
        token = secrets.token_urlsafe(32)
        invitation = InvitationToken(
            token=token,
            organization_id=org_id,
            client_file_id=cfid,
            invited_email=invited_email,
            permission_level=level,
            created_by_user_id=current_user["id"],
            expires_at=datetime.utcnow() + timedelta(days=7),
        )
        session.add(invitation)
        session.commit()

        join_url = f"{os.getenv('FRONTEND_URL', 'http://localhost:3000')}/join?token={token}"

        # Send invitation email directly via SMTP (transactional, not via queue)
        try:
            from src.email_ingestion.smtp_client import SMTPClient
            from src.scheduler.lifecycle_templates import layout
            inviter_name = current_user.get("name") or current_user.get("username") or "votre cabinet"
            html_body = layout(f"""
  <p style="font-family:Helvetica,sans-serif;font-size:15px;line-height:1.6;margin:0 0 16px 0;">Bonjour,</p>
  <p style="font-family:Helvetica,sans-serif;font-size:15px;line-height:1.6;margin:0 0 16px 0;"><strong>{inviter_name}</strong> vous invite à rejoindre leur espace FactPilot et à accéder au dossier <strong>{cf.name}</strong>.</p>
  <p style="font-family:Helvetica,sans-serif;font-size:15px;line-height:1.6;margin:0 0 16px 0;">Cliquez sur le bouton ci-dessous pour créer votre accès. Ce lien est valable 7 jours.</p>
  <p style="text-align:center;margin:24px 0;">
    <a href="{join_url}" style="background-color:#2563eb;color:white;padding:12px 28px;text-decoration:none;border-radius:8px;font-weight:bold;display:inline-block;">Rejoindre FactPilot</a>
  </p>
  <p style="font-family:Helvetica,sans-serif;font-size:13px;color:#64748b;">Ou copiez ce lien : {join_url}</p>
  <p style="font-family:Helvetica,sans-serif;font-size:13px;color:#64748b;">Si vous n'attendiez pas cette invitation, vous pouvez ignorer cet email.</p>
""")
            SMTPClient().send_email(
                to_email=invited_email,
                subject=f"Invitation FactPilot — {cf.name}",
                html_body=html_body,
                text_body=f"Bonjour,\n\n{inviter_name} vous invite à rejoindre FactPilot et à accéder au dossier {cf.name}.\n\nLien d'invitation (valable 7 jours) :\n{join_url}\n\n— L'équipe FactPilot"
            )
        except Exception as e:
            import logging
            logging.getLogger(__name__).error(f"Failed to send invitation email to {invited_email}: {e}")

        return {
            "success": True,
            "invitation_id": invitation.id,
            "join_url": join_url,
            "expires_at": invitation.expires_at.isoformat(),
        }
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()
