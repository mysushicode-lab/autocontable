"""Authentication endpoints"""
from fastapi import APIRouter, HTTPException, Header, Depends
from src.storage.database import db
from src.storage.models import User, UserRole, Organization, UserToken, Settings, PasswordResetToken
from src.api.schemas import LoginRequest, RegisterRequest, ForgotPasswordRequest, ResetPasswordRequest
import hashlib
import secrets
from datetime import datetime, timedelta

router = APIRouter()


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


@router.post("/register")
def register(request: RegisterRequest):
    """Public registration — creates a new organization and admin account."""
    session = db.get_session()
    try:
        if session.query(User).filter(User.username == request.username).first():
            raise HTTPException(status_code=400, detail="Ce nom d'utilisateur est déjà pris.")
        org = Organization(name=request.name)
        session.add(org)
        session.flush()
        org_id = org.id
        password_hash = hashlib.sha256(request.password.encode()).hexdigest()
        user = User(
            username=request.username,
            password_hash=password_hash,
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
            ('scheduler_interval', '0.166', 'scheduler', 'Intervalle en minutes'),
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
        if not user:
            raise HTTPException(status_code=401, detail="Identifiants invalides")
        password_hash = hashlib.sha256(request.password.encode()).hexdigest()
        if user.password_hash != password_hash:
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
    """Generate password reset token and send email (for now, just returns token for testing)"""
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
        
        # TODO: Send email with reset link
        # For now, return the token for testing
        return {
            "message": "Si l'email existe, un lien de réinitialisation a été envoyé",
            "token": token  # Remove this in production
        }
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
        user.password_hash = hashlib.sha256(request.new_password.encode()).hexdigest()
        
        # Delete the used token
        session.delete(reset_token)
        
        # Delete all user tokens to force re-login
        session.query(UserToken).filter(UserToken.user_id == user.id).delete()
        
        session.commit()
        return {"message": "Mot de passe réinitialisé avec succès"}
    finally:
        session.close()
