"""Authentication endpoints"""
from fastapi import APIRouter, HTTPException, Header, Depends, Request
from src.storage.database import db
from src.storage.models import User, UserToken, Organization, UserRole, Settings, PasswordResetToken
from src.api.schemas import RegisterRequest, LoginRequest, ForgotPasswordRequest, ResetPasswordRequest, ChangePasswordRequest, ChangeUsernameRequest, ChangeEmailRequest
from src.email_ingestion import SMTPClient
from src.api.rate_limit import limiter
from passlib.context import CryptContext
import hashlib
import hmac
import secrets
import logging
from datetime import datetime, timedelta

logger = logging.getLogger(__name__)
router = APIRouter()

# Token lifetime: 7 days of inactivity
TOKEN_LIFETIME = timedelta(days=7)

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
        if org.plan_type == 'trial' and org.trial_end_date and now > org.trial_end_date:
            raise HTTPException(
                status_code=403,
                detail="Votre période d'essai est terminée. Veuillez mettre à niveau votre compte pour continuer."
            )
        return current_user
    finally:
        session.close()


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
        trial_end = trial_start + timedelta(days=7)
        org = Organization(
            name=body.name,
            plan_type='trial',
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
        default_settings = [
            ('imap_server', 'imap.gmail.com', 'email', 'Serveur IMAP'),
            ('imap_port', '993', 'email', 'Port IMAP'),
            ('email_folder', 'INBOX', 'email', 'Dossier IMAP'),
            ('scheduler_interval', '1', 'scheduler', 'Intervalle en minutes'),
            ('auto_reconciliation', 'true', 'scheduler', 'Rapprochement automatique'),
            ('company_name', body.name, 'general', 'Nom de votre entreprise'),
        ]
        for key, value, category, description in default_settings:
            session.add(Settings(key=key, value=value, category=category, description=description, organization_id=org_id))
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
    finally:
        session.close()


@router.delete("/delete-account")
def delete_own_account(current_user: dict = Depends(get_current_user)):
    """Delete the authenticated user's own account"""
    session = db.get_session()
    try:
        user = session.query(User).filter(User.id == current_user["id"]).first()
        if not user:
            raise HTTPException(status_code=404, detail="Compte introuvable")
        session.query(UserToken).filter(UserToken.user_id == user.id).delete()
        session.delete(user)
        session.commit()
        return {"message": "Compte supprimé"}
    finally:
        session.close()


@router.post("/forgot-password")
@limiter.limit("5/hour")
def forgot_password(request: Request, body: ForgotPasswordRequest):
    """Generate password reset token and send email.

    Rate-limited to 5/hour per IP to prevent email-bombing and enumeration.
    """
    session = db.get_session()
    try:
        user = session.query(User).filter(User.email == body.email).first()
        if not user:
            # Don't reveal if email exists - return success anyway
            return {"message": "Si l'email existe, un lien de réinitialisation a été envoyé"}
        
        # Delete any existing reset tokens for this user
        session.query(PasswordResetToken).filter(PasswordResetToken.user_id == user.id).delete()
        
        # Generate new token (expires in 1 hour)
        token = secrets.token_hex(32)
        expires_at = datetime.utcnow() + timedelta(hours=1)
        reset_token = PasswordResetToken(token=token, user_id=user.id, expires_at=expires_at)
        session.add(reset_token)
        session.commit()
        
        # Send email with reset link
        try:
            smtp_client = SMTPClient()
            smtp_client.send_password_reset(user.email, token)
        except Exception as e:
            logger.error(f"Failed to send password reset email: {e}")
        
        return {"message": "Si l'email existe, un lien de réinitialisation a été envoyé"}
    finally:
        session.close()


@router.post("/reset-password")
@limiter.limit("10/hour")
def reset_password(request: Request, body: ResetPasswordRequest):
    """Reset password using valid token (rate-limited to prevent token brute-force)."""
    session = db.get_session()
    try:
        reset_token = session.query(PasswordResetToken).filter(
            PasswordResetToken.token == body.token,
            PasswordResetToken.expires_at > datetime.utcnow()
        ).first()

        if not reset_token:
            raise HTTPException(status_code=400, detail="Token invalide ou expiré")

        user = session.query(User).filter(User.id == reset_token.user_id).first()
        if not user:
            raise HTTPException(status_code=404, detail="Utilisateur introuvable")

        # Update password
        user.password_hash = _hash_password(body.new_password)

        # Delete the used token
        session.delete(reset_token)

        # Delete all user tokens to force re-login
        session.query(UserToken).filter(UserToken.user_id == user.id).delete()

        session.commit()
        return {"message": "Mot de passe réinitialisé avec succès"}
    finally:
        session.close()


@router.post("/change-password")
def change_password(request: ChangePasswordRequest, current_user: dict = Depends(get_current_user)):
    """Change password (requires current password verification)"""
    session = db.get_session()
    try:
        user = session.query(User).filter(User.id == current_user["id"]).first()
        if not user:
            raise HTTPException(status_code=404, detail="Utilisateur introuvable")

        # Verify current password using constant-time comparison
        if not _verify_password(request.current_password, user.password_hash):
            raise HTTPException(status_code=400, detail="Mot de passe actuel incorrect")

        # Update password
        user.password_hash = _hash_password(request.new_password)

        # Delete all user tokens to force re-login
        session.query(UserToken).filter(UserToken.user_id == user.id).delete()

        session.commit()
        return {"message": "Mot de passe changé avec succès"}
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
    finally:
        session.close()
