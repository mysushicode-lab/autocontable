"""User management endpoints"""
from fastapi import APIRouter, HTTPException, UploadFile, File, Depends
from sqlalchemy.orm import Session
from typing import Optional
import os
import shutil

from src.storage.database import db
from src.storage.models import User, UserRole
from src.api.schemas import CreateUserRequest, UpdateUserRequest
from src.api.auth import get_current_user, _hash_password

router = APIRouter()

ALLOWED_PHOTO_EXTENSIONS = {".jpg", ".jpeg", ".png", ".gif", ".webp"}


def require_admin(current_user: dict = Depends(get_current_user)) -> dict:
    """Ensure the current user has admin role."""
    if current_user.get("role") != UserRole.ADMIN.value:
        raise HTTPException(status_code=403, detail="Permission refusée - rôle administrateur requis")
    return current_user


@router.get("")
@router.get("/")
def list_users(current_user: dict = Depends(get_current_user)):
    """List all users in the same organization"""
    session = db.get_session()
    try:
        users = session.query(User).filter(User.organization_id == current_user["organization_id"]).all()
        return {
            "users": [
                {
                    "id": u.id,
                    "username": u.username,
                    "name": u.name,
                    "email": u.email,
                    "role": u.role.value,
                    "created_at": u.created_at.isoformat() if u.created_at else None
                }
                for u in users
            ]
        }
    finally:
        session.close()


@router.post("/create")
def create_user(request: CreateUserRequest, current_user: dict = Depends(require_admin)):
    """Create a new user in the same organization (admin only)"""
    session = db.get_session()
    try:
        if session.query(User).filter(User.username == request.username).first():
            raise HTTPException(status_code=400, detail="Ce nom d'utilisateur existe déjà")
        if session.query(User).filter(User.email == request.email).first():
            raise HTTPException(status_code=400, detail="Cet email existe déjà")

        password_hash = _hash_password(request.password)
        user = User(
            username=request.username,
            password_hash=password_hash,
            name=request.name,
            email=request.email,
            role=UserRole.ADMIN if request.role == "admin" else UserRole.ACCOUNTANT,
            organization_id=current_user["organization_id"]
        )
        session.add(user)
        session.commit()
        return {"message": "User created", "id": user.id}
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


@router.delete("/{user_id}")
def delete_user(user_id: int, current_user: dict = Depends(require_admin)):
    """Delete a user (admin only)"""
    session = db.get_session()
    try:
        user = session.query(User).filter(User.id == user_id, User.organization_id == current_user["organization_id"]).first()
        if not user:
            raise HTTPException(status_code=404, detail="Utilisateur introuvable")
        if user.id == current_user["id"]:
            raise HTTPException(status_code=400, detail="Vous ne pouvez pas supprimer votre propre compte")

        # Delete associated user tokens first
        from src.storage.models import UserToken
        session.query(UserToken).filter(UserToken.user_id == user_id).delete()

        session.delete(user)
        session.commit()
        return {"message": "User deleted"}
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


@router.put("/{user_id}")
def update_user(user_id: int, request: UpdateUserRequest, current_user: dict = Depends(get_current_user)):
    """Update user name and email (admin can update anyone, users can only update themselves)"""
    if current_user["id"] != user_id and current_user.get("role") != UserRole.ADMIN.value:
        raise HTTPException(status_code=403, detail="Permission refusée")
    session = db.get_session()
    try:
        user = session.query(User).filter(User.id == user_id, User.organization_id == current_user["organization_id"]).first()
        if not user:
            raise HTTPException(status_code=404, detail="Utilisateur introuvable")

        if request.name is not None:
            user.name = request.name
        if request.email is not None:
            user.email = request.email

        session.commit()
        session.refresh(user)
        return {
            "message": "User updated",
            "user": {
                "id": user.id,
                "username": user.username,
                "name": user.name,
                "email": user.email,
                "role": user.role.value,
                "profile_photo": user.profile_photo
            }
        }
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


@router.post("/{user_id}/profile-photo")
def upload_profile_photo(user_id: int, file: UploadFile = File(...), current_user: dict = Depends(get_current_user)):
    """Upload profile photo (users can only modify their own, admins can modify any)"""
    if current_user["id"] != user_id and current_user.get("role") != UserRole.ADMIN.value:
        raise HTTPException(status_code=403, detail="Permission refusée")

    # Validate file type using extension whitelist (content-type can be spoofed)
    ext = os.path.splitext(file.filename or "")[1].lower()
    if ext not in ALLOWED_PHOTO_EXTENSIONS:
        raise HTTPException(status_code=400, detail="Format d'image non supporté")
    if not file.content_type or not file.content_type.startswith('image/'):
        raise HTTPException(status_code=400, detail="Le fichier doit être une image")

    session = db.get_session()
    try:
        user = session.query(User).filter(User.id == user_id, User.organization_id == current_user["organization_id"]).first()
        if not user:
            raise HTTPException(status_code=404, detail="Utilisateur introuvable")

        # Create uploads directory if not exists
        upload_dir = os.path.join("data", "uploads", "profile_photos")
        os.makedirs(upload_dir, exist_ok=True)

        # Generate filename using sanitized extension
        filename = f"user_{user_id}{ext}"
        filepath = os.path.join(upload_dir, filename)

        # Save file
        with open(filepath, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        # Update user record
        user.profile_photo = f"/api/uploads/profile_photos/{filename}"
        session.commit()

        return {"message": "Profile photo updated", "photo_url": user.profile_photo}
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


@router.get("/onboarding-status")
def get_onboarding_status(current_user: dict = Depends(get_current_user)):
    """Get onboarding completion status for the current user's organization."""
    from src.storage.models import Settings
    session = db.get_session()
    try:
        org_id = current_user["organization_id"]
        setting = session.query(Settings).filter(
            Settings.organization_id == org_id,
            Settings.key == "onboarding_completed"
        ).first()
        return {"completed": setting is not None and setting.value == "true"}
    finally:
        session.close()


@router.post("/onboarding-complete")
def mark_onboarding_complete(current_user: dict = Depends(get_current_user)):
    """Mark onboarding as completed for the current user's organization."""
    from src.storage.models import Settings
    from fastapi import HTTPException
    session = db.get_session()
    try:
        org_id = current_user["organization_id"]
        existing = session.query(Settings).filter(
            Settings.organization_id == org_id,
            Settings.key == "onboarding_completed"
        ).first()

        # Prevent re-onboarding if already completed
        if existing and existing.value == "true":
            raise HTTPException(
                status_code=400,
                detail="L'onboarding a déjà été complété pour cette organisation."
            )

        if existing:
            existing.value = "true"
        else:
            session.add(Settings(
                organization_id=org_id,
                key="onboarding_completed",
                value="true",
                category="system"
            ))
        session.commit()
        return {"success": True}
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()
