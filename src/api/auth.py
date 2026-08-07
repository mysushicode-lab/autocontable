"""Authentication endpoints"""
import os
from fastapi import APIRouter, HTTPException, Header, Depends, Request

import src.config  # noqa: F401

from src.storage.database import db
from src.storage.models import User, UserToken, Organization, UserRole, PasswordResetToken
from src.api.schemas import RegisterRequest, LoginRequest, ChangeUsernameRequest, ChangeEmailRequest
from src.utils.defaults import create_default_settings
from src.api.rate_limit import limiter
from passlib.context import CryptContext
import hashlib
import hmac
import secrets
import logging
from datetime import datetime, timedelta

logger = logging.getLogger(__name__)
router = APIRouter()

# Token lifetime (configurable)
TOKEN_LIFETIME = timedelta(days=int(os.getenv("TOKEN_LIFETIME_DAYS", 7)))

# Password hashing context: bcrypt is the default, sha256 kept only for legacy verification
# Existing accounts will be transparently migrated to bcrypt on next successful login.
_pwd_context = CryptContext(
    schemes=["bcrypt"],
    deprecated="auto",
    bcrypt__rounds=12,
)

# bcrypt has a hard 72-byte limit on the input password. Truncate defensively
# so longer passwords don't raise ValueError (behaviour changed in bcrypt 4.1).
_BCRYPT_MAX_BYTES = 72


def _truncate_for_bcrypt(password: str) -> str:
    """Truncate the password to fit bcrypt's 72-byte limit."""
    if password is None:
        return ""
    encoded = password.encode("utf-8")
    if len(encoded) <= _BCRYPT_MAX_BYTES:
        return password
    # Decode back, ignoring any partial multibyte char at the boundary
    return encoded[:_BCRYPT_MAX_BYTES].decode("utf-8", errors="ignore")


# Precomputed bcrypt hash used as a constant-time decoy when the username
# doesn't exist, to make the response time identical and avoid user enumeration.
_DUMMY_BCRYPT_HASH = _pwd_context.hash(_truncate_for_bcrypt("dummy_password_for_timing_protection"))


def _is_legacy_sha256(stored_hash: str) -> bool:
    """Detect legacy unsalted SHA-256 hashes (64 hex chars)."""
    return (
        isinstance(stored_hash, str)
        and len(stored_hash) == 64
        and all(c in "0123456789abcdef" for c in stored_hash.lower())
    )


def _hash_password(password: str) -> str:
    """Hash a password using bcrypt (cost=12)."""
    return _pwd_context.hash(_truncate_for_bcrypt(password))


def _verify_password(password: str, stored_hash: str) -> bool:
    """Verify a password against a stored hash.

    Supports both legacy SHA-256 (for backward-compat) and bcrypt. Uses
    constant-time comparison for the SHA-256 path.
    """
    if not stored_hash:
        return False
    if _is_legacy_sha256(stored_hash):
        legacy_hash = hashlib.sha256(password.encode()).hexdigest()
        return hmac.compare_digest(legacy_hash, stored_hash)
    try:
        return _pwd_context.verify(_truncate_for_bcrypt(password), stored_hash)
    except Exception:
        return False


def _needs_rehash(stored_hash: str) -> bool:
    """True if the hash should be upgraded (legacy SHA-256 or outdated bcrypt cost)."""
    if _is_legacy_sha256(stored_hash):
        return True
    try:
        return _pwd_context.needs_update(stored_hash)
    except Exception:
        return False


def _create_user_token(session, user_id: int) -> str:
    """Create a new user token with expiration and return its value."""
    token_value = secrets.token_hex(32)
    user_token = UserToken(
        token=token_value,
        user_id=user_id,
        expires_at=datetime.utcnow() + TOKEN_LIFETIME,
    )
    session.add(user_token)
    return token_value


def get_current_user(authorization: str = Header(None)) -> dict:
    """Validate Bearer token and return user info dict."""
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Token manquant")
    token = authorization[7:]
    session = db.get_session()
    try:
        user_token = session.query(UserToken).filter(UserToken.token == token).first()
        if not user_token:
            raise HTTPException(status_code=401, detail="Token invalide ou expiré")
        # Enforce token expiration
        if user_token.expires_at is not None and user_token.expires_at < datetime.utcnow():
            # Cleanup expired token
            session.delete(user_token)
            session.commit()
            raise HTTPException(status_code=401, detail="Token expiré")
        user = session.query(User).filter(User.id == user_token.user_id).first()
        if not user:
            raise HTTPException(status_code=401, detail="Utilisateur introuvable")
        return {
            "id": user.id,
            "username": user.username,
            "name": user.name,
            "role": user.role.value,
            "organization_id": user.organization_id,
            "email": user.email,
            "profile_photo": user.profile_photo,
            "client_file_id": user.client_file_id,
        }
    finally:
        session.close()


def check_trial_active(current_user: dict = Depends(get_current_user)):
    """Check if organization trial is still active. Raises 403 if trial expired."""
    session = db.get_session()
    try:
        org = session.query(Organization).filter(Organization.id == current_user["organization_id"]).first()
        if not org:
            raise HTTPException(status_code=404, detail="Organization not found")

        now = datetime.utcnow()
        if org.is_trial_active and org.trial_end_date and now > org.trial_end_date:
            raise HTTPException(
                status_code=403,
                detail="Votre période d'essai est terminée. Veuillez mettre à niveau votre compte pour continuer."
            )
        return current_user
    finally:
        session.close()


@router.get("/me")
def get_me(current_user: dict = Depends(get_current_user)):
    """Return the authenticated user's profile."""
    return current_user


@router.post("/register")
@limiter.limit("5/hour")
def register(request: Request, body: RegisterRequest):
    """Public registration — creates a new organization and admin account.

    Rate-limited to 5 requests/hour per IP to prevent mass account creation.
    """
    session = db.get_session()
    try:
        if session.query(User).filter(User.username == body.username).first():
            raise HTTPException(status_code=400, detail="Ce nom d'utilisateur est déjà pris.")
        if session.query(User).filter(User.email == body.email).first():
            raise HTTPException(status_code=400, detail="Cet email est déjà utilisé.")
        trial_start = datetime.utcnow()
        trial_end = trial_start + timedelta(days=int(os.getenv("TRIAL_PERIOD_DAYS", 7)))
        org = Organization(
            name=body.name,
            plan_type='starter',
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
        token_value = _create_user_token(session, user_id)
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


@router.get("/data-export")
@limiter.limit("3/hour")
def export_user_data(request: Request, current_user: dict = Depends(get_current_user)):
    """Export all data for the authenticated user (RGPD Article 20)"""
    from fastapi.responses import JSONResponse
    session = db.get_session()
    try:
        user = session.query(User).filter(User.id == current_user["id"]).first()
        if not user:
            raise HTTPException(status_code=404, detail="Utilisateur introuvable")

        from src.storage.models import Invoice, BankTransaction, Settings as SettingsModel
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

        from fastapi.responses import Response
        import json
        content = json.dumps(payload, ensure_ascii=False, indent=2)
        return Response(
            content=content,
            media_type="application/json",
            headers={"Content-Disposition": f"attachment; filename=autocontable-export-{user.username}.json"}
        )
    finally:
        session.close()


@router.delete("/delete-account")
def delete_own_account(current_user: dict = Depends(get_current_user)):
    """Delete the authenticated user's own account and all associated data (RGPD Art. 17)."""
    from src.storage.models import (
        Invoice, BankTransaction, ReconciliationMatch,
        ClientFile, DossierPermission, AuditLog, PasswordResetToken, ProcessedFileHash, Settings
    )
    session = db.get_session()
    try:
        user = session.query(User).filter(User.id == current_user["id"]).first()
        if not user:
            raise HTTPException(status_code=404, detail="Compte introuvable")

        org_id = user.organization_id

        # Check if user is the last admin — if so, delete entire org data
        admin_count = session.query(User).filter(
            User.organization_id == org_id,
            User.role == UserRole.ADMIN
        ).count()

        if admin_count <= 1 and user.role == UserRole.ADMIN:
            # Last admin: purge all org data
            from src.storage.models import Supplier
            session.query(ReconciliationMatch).filter(ReconciliationMatch.organization_id == org_id).delete()
            session.query(ProcessedFileHash).filter(ProcessedFileHash.organization_id == org_id).delete()
            session.query(Invoice).filter(Invoice.organization_id == org_id).delete()
            session.query(BankTransaction).filter(BankTransaction.organization_id == org_id).delete()
            session.query(Supplier).filter(Supplier.organization_id == org_id).delete()
            session.query(ClientFile).filter(ClientFile.organization_id == org_id).delete()
            session.query(AuditLog).filter(AuditLog.organization_id == org_id).delete()
            session.query(Settings).filter(Settings.organization_id == org_id).delete()
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
