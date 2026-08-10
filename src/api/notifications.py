"""Notification preferences and test endpoint"""
from fastapi import APIRouter, Depends
from src.api.auth import get_current_user
from src.notifications import send_email

router = APIRouter()


@router.post("/test")
def send_test_notification(current_user: dict = Depends(get_current_user)):
    """Send a test notification email to verify SMTP configuration."""
    email = current_user.get("email")
    if not email:
        return {"success": False, "error": "Aucun email configuré pour votre compte"}

    success = send_email(
        to=email,
        subject="[FactPilot] Test de notification",
        body_html="<p>Si vous recevez cet email, les notifications sont correctement configurées. ✅</p>"
    )

    return {"success": success, "message": "Email envoyé" if success else "Échec d'envoi — vérifiez la configuration SMTP"}
