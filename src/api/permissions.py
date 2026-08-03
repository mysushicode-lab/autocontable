"""Dossier permission management endpoints."""
from fastapi import APIRouter, Depends, HTTPException
from src.storage.database import db
from src.storage.models import DossierPermission, ClientFile, User, UserRole
from src.api.auth import get_current_user
from src.api.billing import require_feature

router = APIRouter()


def user_has_access(session, user_id: int, client_file_id: int, org_id: int, role: str) -> bool:
    """Check if a user has access to a specific dossier.

    Admins always have access to all dossiers in their org.
    Other users need explicit permission.
    """
    # Verify dossier belongs to the org first
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
    return perm is not None


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
