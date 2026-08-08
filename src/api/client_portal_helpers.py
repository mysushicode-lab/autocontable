"""Helper functions for client portal endpoints."""
from fastapi import HTTPException
from src.storage.models import User, DossierPermission


def get_client_file_id(current_user: dict, session):
    """Get the client_file_id this client user is linked to.

    Client users have a client_file_id stored in their user record (via a new field).
    Accountants/admins can access any dossier via the activeClientFileId from frontend.
    """
    role = current_user.get("role")
    if role == "client":
        # Client users are restricted to their own dossier
        user = session.query(User).get(current_user["id"])
        if not user or not user.client_file_id:
            raise HTTPException(403, "Aucun dossier associé à votre compte")
        return user.client_file_id
    return None  # Accountants use the activeClientFileId from frontend


def check_write_permission(current_user: dict, session) -> bool:
    """Check if current user has write permission (not just read_only).

    Returns True if user can write, raises 403 if read_only.
    """
    role = current_user.get("role")
    user_id = current_user.get("id")

    # Admins and accountants always have write access
    if role in ("admin", "accountant"):
        return True

    # Clients must check DossierPermission
    if role == "client":
        user = session.query(User).get(user_id)
        if not user or not user.client_file_id:
            raise HTTPException(403, "Aucun dossier associé à votre compte")

        perm = session.query(DossierPermission).filter(
            DossierPermission.user_id == user_id,
            DossierPermission.client_file_id == user.client_file_id
        ).first()

        if not perm:
            raise HTTPException(403, "Vous n'avez pas accès à ce dossier")

        if perm.permission_level == "read_only":
            raise HTTPException(403, "Vous avez accès en lecture seule. Contact l'administrateur pour modifier.")

        return True

    raise HTTPException(403, "Accès refusé")
