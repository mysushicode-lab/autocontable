"""Authentication helpers: password hashing, token management, user resolution."""
import os
import hashlib
import hmac
import secrets
import logging
from datetime import datetime, timedelta

from fastapi import HTTPException, Header, Depends, Request
from passlib.context import CryptContext

from src.storage.database import db
from src.storage.models import User, UserToken, Organization

logger = logging.getLogger(__name__)

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


def get_current_user(authorization: str = Header(None), request: Request = None) -> dict:
    """Validate Bearer token from cookie or Authorization header and return user info dict."""
    token = None

    if request and hasattr(request, 'cookies'):
        token = request.cookies.get('auth_token')

    if not token and authorization and authorization.startswith("Bearer "):
        token = authorization[7:]

    if not token:
        raise HTTPException(status_code=401, detail="Token manquant")
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
