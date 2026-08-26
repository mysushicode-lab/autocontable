"""Authentication endpoints: login, register, profile, username/email changes, invitations."""
import os
from datetime import datetime, timedelta

from fastapi import APIRouter, HTTPException, Depends, Request, BackgroundTasks

import src.config  # noqa: F401

from src.storage.database import db
from src.storage.models import (
    User, UserToken, UserRole, Organization, InvitationToken, DossierPermission
)
from src.api.schemas import RegisterRequest, LoginRequest, ChangeUsernameRequest, ChangeEmailRequest
from src.utils.defaults import create_default_settings
from src.api.rate_limit import limiter

# Re-export helpers so existing imports (from src.api.auth import ...) keep working
from src.api.auth_helpers import (  # noqa: F401
    _hash_password,
    _verify_password,
    _needs_rehash,
    _create_user_token,
    _DUMMY_BCRYPT_HASH,
    get_current_user,
    check_trial_active,
    logger,
)

router = APIRouter()


@router.get("/me")
def get_me(current_user: dict = Depends(get_current_user)):
    """Return the authenticated user's profile."""
    return current_user


@router.post("/register")
@limiter.limit("5/hour")
def register(request: Request, body: RegisterRequest, background_tasks: BackgroundTasks):
    """Public registration -- creates a new organization and admin account.

    Rate-limited to 5 requests/hour per IP to prevent mass account creation.
    """
    session = db.get_session()
    try:
        if session.query(User).filter(User.username == body.username).first():
            raise HTTPException(status_code=400, detail="Ce nom d'utilisateur est déjà pris.")
        if session.query(User).filter(User.email == body.email).first():
            raise HTTPException(status_code=400, detail="Cet email est déjà utilisé.")
        trial_start = datetime.utcnow()
        trial_end = trial_start + timedelta(days=int(os.getenv("TRIAL_PERIOD_DAYS", 14)))
        org = Organization(
            name=body.name,
            plan_type='free',
            trial_start_date=trial_start,
            trial_end_date=trial_end,
            is_trial_active=True
        )
        session.add(org)
        session.flush()
        org_id = org.id
        user = User(
            username=body.username,
            password_hash=_hash_password(body.password),
            name=body.name,
            email=body.email,
            role=UserRole.ADMIN,
            organization_id=org_id
        )
        session.add(user)
        session.flush()
        user_id = user.id
        create_default_settings(session, org_id, company_name=body.name)
        # Track affiliate referral if ref code provided
        if body.ref:
            from src.api.affiliates import track_referral
            track_referral(session, body.ref, user_id, org_id)
        token_value = _create_user_token(session, user_id)

        # Lifecycle: trigger trial welcome + nurture sequence
        from src.scheduler.lifecycle_engine import on_account_created
        on_account_created(session, user_id=user_id, organization_id=org_id, email=body.email)

        session.commit()

        return {
            "token": token_value,
            "user": {
                "id": user_id,
                "username": body.username,
                "name": body.name,
                "role": UserRole.ADMIN.value,
                "organization_id": org_id,
                "email": body.email,
                "profile_photo": None
            }
        }
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


@router.post("/login")
@limiter.limit("10/minute")
def login(request: Request, body: LoginRequest):
    """Login - validates credentials and returns stored token.

    Rate-limited to 10 attempts/minute per IP to mitigate brute-force.
    """
    session = db.get_session()
    try:
        user = session.query(User).filter(User.username == body.username).first()
        # Always run hash verification even if user doesn't exist to prevent timing attacks
        stored_hash = user.password_hash if user else _DUMMY_BCRYPT_HASH
        password_ok = _verify_password(body.password, stored_hash)
        if not user or not password_ok:
            raise HTTPException(status_code=401, detail="Identifiants invalides")

        # Transparent password rehash to upgrade legacy SHA-256 to bcrypt
        if _needs_rehash(user.password_hash):
            try:
                user.password_hash = _hash_password(body.password)
                logger.info(f"Upgraded password hash for user {user.id}")
            except Exception as e:
                logger.warning(f"Failed to upgrade password hash for user {user.id}: {e}")

        token_value = _create_user_token(session, user.id)
        session.commit()

        # Log audit trail
        from src.api.audit import log_action
        ip_address = request.client.host if request else None
        log_action(
            session,
            user.organization_id,
            user.id,
            "login",
            "user",
            user.id,
            {"username": user.username},
            ip_address
        )

        return {
            "token": token_value,
            "user": {
                "id": user.id,
                "username": user.username,
                "name": user.name,
                "role": user.role.value,
                "organization_id": user.organization_id,
                "email": user.email,
                "profile_photo": user.profile_photo
            }
        }
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


@router.post("/change-username")
def change_username(request: ChangeUsernameRequest, current_user: dict = Depends(get_current_user)):
    """Change username"""
    session = db.get_session()
    try:
        # Check if username already exists
        existing = session.query(User).filter(User.username == request.new_username).first()
        if existing:
            raise HTTPException(status_code=400, detail="Ce nom d'utilisateur est déjà pris")

        user = session.query(User).filter(User.id == current_user["id"]).first()
        if not user:
            raise HTTPException(status_code=404, detail="Utilisateur introuvable")

        user.username = request.new_username
        # Invalidate other sessions to force re-login with new username
        session.query(UserToken).filter(UserToken.user_id == user.id).delete()
        session.commit()
        return {"message": "Nom d'utilisateur changé avec succès. Veuillez vous reconnecter."}
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


@router.post("/change-email")
def change_email(request: ChangeEmailRequest, current_user: dict = Depends(get_current_user)):
    """Change email"""
    session = db.get_session()
    try:
        # Check if email already exists
        existing = session.query(User).filter(User.email == request.new_email).first()
        if existing:
            raise HTTPException(status_code=400, detail="Cet email est déjà utilisé")

        user = session.query(User).filter(User.id == current_user["id"]).first()
        if not user:
            raise HTTPException(status_code=404, detail="Utilisateur introuvable")

        user.email = request.new_email
        session.commit()
        return {"message": "Email changé avec succès"}
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


@router.post("/join-from-invitation")
def join_from_invitation(body: dict, background_tasks: BackgroundTasks):
    """PME creates account and joins organization via invitation token.

    body: {"token": "abc...", "username": "pme", "password": "...", "name": "PME Name"}
    """
    session = db.get_session()
    try:
        token_str = body.get("token", "").strip()
        username = body.get("username", "").strip()
        password = body.get("password", "")
        name = body.get("name", "").strip()

        if not all([token_str, username, password, name]):
            raise HTTPException(400, "Tous les champs requis")

        # Validate invitation token
        invitation = session.query(InvitationToken).filter(
            InvitationToken.token == token_str,
            InvitationToken.used_at.is_(None),  # Not yet used
            InvitationToken.expires_at > datetime.utcnow()
        ).first()

        if not invitation:
            raise HTTPException(400, "Lien d'invitation invalide ou expiré")

        # Check username doesn't already exist
        if session.query(User).filter(User.username == username).first():
            raise HTTPException(400, "Ce nom d'utilisateur est déjà pris")

        # Create user in the org from the invitation
        user = User(
            username=username,
            password_hash=_hash_password(password),
            name=name,
            email=invitation.invited_email,
            role=UserRole.CLIENT,
            organization_id=invitation.organization_id
        )
        session.add(user)
        session.flush()

        # Grant dossier access if specified in invitation
        if invitation.client_file_id:
            session.add(DossierPermission(
                user_id=user.id,
                client_file_id=invitation.client_file_id,
                permission_level=invitation.permission_level,
            ))

        # Mark invitation as used
        invitation.used_by_user_id = user.id
        invitation.used_at = datetime.utcnow()

        session.commit()

        # Create token and return
        token_value = _create_user_token(session, user.id)
        session.commit()

        return {
            "access_token": token_value,
            "token_type": "bearer",
            "user": {
                "id": user.id,
                "username": username,
                "name": name,
                "role": UserRole.CLIENT.value,
                "organization_id": invitation.organization_id,
                "email": invitation.invited_email,
            }
        }
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()
