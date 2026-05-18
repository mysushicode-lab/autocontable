"""Authentication endpoints"""
from fastapi import APIRouter, HTTPException, Header, Depends
from src.storage.database import db
from src.storage.models import User, UserToken, Organization, UserRole, Settings, PasswordResetToken
from src.api.schemas import RegisterRequest, LoginRequest, ForgotPasswordRequest, ResetPasswordRequest, ChangePasswordRequest, ChangeUsernameRequest, ChangeEmailRequest
from src.email_ingestion import SMTPClient
import hashlib
import hmac
import secrets
import logging
from datetime import datetime, timedelta

logger = logging.getLogger(__name__)
router = APIRouter()


def _hash_password(password: str) -> str:
    """Hash a password using SHA-256.

    NOTE: SHA-256 without salt is NOT secure for production use. This is kept
    for backward-compat with existing accounts. Migrate to bcrypt/argon2 ASAP.
    """
    return hashlib.sha256(password.encode()).hexdigest()


def _verify_password(password: str, stored_hash: str) -> bool:
    """Constant-time password verification to avoid timing attacks."""
    return hmac.compare_digest(_hash_password(password), stored_hash)


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
def register(request: RegisterRequest):
    """Public registration — creates a new organization and admin account."""
    session = db.get_session()
    try:
        if session.query(User).filter(User.username == request.username).first():
            raise HTTPException(status_code=400, detail="Ce nom d'utilisateur est déjà pris.")
        if session.query(User).filter(User.email == request.email).first():
            raise HTTPException(status_code=400, detail="Cet email est déjà utilisé.")
        trial_start = datetime.utcnow()
        trial_end = trial_start + timedelta(days=7)
        org = Organization(
            name=request.name,
            plan_type='trial',
            trial_start_date=trial_start,
            trial_end_date=trial_end,
            is_trial_active=True
        )
        session.add(org)
        session.flush()
        org_id = org.id
        user = User(
            username=request.username,
            password_hash=_hash_password(request.password),
            name=request.name,
            email=request.email,
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
            ('company_name', request.name, 'general', 'Nom de votre entreprise'),
        ]
        for key, value, category, description in default_settings:
            session.add(Settings(key=key, value=value, category=category, description=description, organization_id=org_id))
        token_value = secrets.token_hex(32)
        user_token = UserToken(token=token_value, user_id=user_id)
        session.add(user_token)
        session.commit()
        return {
            "token": token_value,
            "user": {
                "id": user_id,
                "username": request.username,
                "name": request.name,
                "role": UserRole.ADMIN.value,
                "organization_id": org_id,
                "email": request.email,
                "profile_photo": None
            }
        }
    finally:
        session.close()


@router.post("/login")
def login(request: LoginRequest):
    """Login - validates credentials and returns stored token"""
    session = db.get_session()
    try:
        user = session.query(User).filter(User.username == request.username).first()
        # Always run hash verification even if user doesn't exist to prevent timing attacks
        dummy_hash = "0" * 64
        stored_hash = user.password_hash if user else dummy_hash
        if not _verify_password(request.password, stored_hash) or not user:
            raise HTTPException(status_code=401, detail="Identifiants invalides")
        token_value = secrets.token_hex(32)
        user_token = UserToken(token=token_value, user_id=user.id)
        session.add(user_token)
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
def forgot_password(request: ForgotPasswordRequest):
    """Generate password reset token and send email"""
    session = db.get_session()
    try:
        user = session.query(User).filter(User.email == request.email).first()
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
        smtp_client = SMTPClient()
        smtp_client.send_password_reset(user.email, token)
        
        return {"message": "Si l'email existe, un lien de réinitialisation a été envoyé"}
    finally:
        session.close()


@router.post("/reset-password")
def reset_password(request: ResetPasswordRequest):
    """Reset password using valid token"""
    session = db.get_session()
    try:
        reset_token = session.query(PasswordResetToken).filter(
            PasswordResetToken.token == request.token,
            PasswordResetToken.expires_at > datetime.utcnow()
        ).first()

        if not reset_token:
            raise HTTPException(status_code=400, detail="Token invalide ou expiré")

        user = session.query(User).filter(User.id == reset_token.user_id).first()
        if not user:
            raise HTTPException(status_code=404, detail="Utilisateur introuvable")

        # Update password
        user.password_hash = _hash_password(request.new_password)

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
