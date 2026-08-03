"""Password management endpoints"""
import os
from fastapi import APIRouter, HTTPException, Request, Depends
from src.storage.database import db
from src.storage.models import User, UserToken, PasswordResetToken
from src.api.schemas import ForgotPasswordRequest, ResetPasswordRequest, ChangePasswordRequest
from src.email_ingestion import SMTPClient
from src.api.rate_limit import limiter
from src.api.auth import get_current_user, _hash_password, _verify_password
import secrets
import logging
from datetime import datetime, timedelta

logger = logging.getLogger(__name__)
router = APIRouter()


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

        # Generate new token
        token = secrets.token_hex(32)
        _expiry_hours = int(os.getenv("PASSWORD_RESET_EXPIRY_HOURS", 1))
        expires_at = datetime.utcnow() + timedelta(hours=_expiry_hours)
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
    except Exception:
        session.rollback()
        raise
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
    except Exception:
        session.rollback()
        raise
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
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()
