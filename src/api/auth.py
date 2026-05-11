"""Authentication endpoints"""
from fastapi import APIRouter, HTTPException, Header, Depends
from src.storage.database import db
from src.storage.models import User, UserRole, Organization, UserToken, Settings
from src.api.schemas import LoginRequest, RegisterRequest
import hashlib
import secrets

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
