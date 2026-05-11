"""Settings endpoints"""
from fastapi import APIRouter, Depends
from typing import Optional

from src.storage.database import db
from src.storage.models import Settings
from src.api.schemas import SettingUpdate, TestImapRequest
from src.api.auth import get_current_user

router = APIRouter()


@router.get("/")
@router.get("")
def get_settings(category: Optional[str] = None, current_user: dict = Depends(get_current_user)):
    """Get all settings or filtered by category"""
    session = db.get_session()
    try:
        query = session.query(Settings).filter(Settings.organization_id == current_user["organization_id"])
        if category:
            query = query.filter(Settings.category == category)
        settings = query.all()
        return {
            "settings": [
                {
                    "key": s.key,
                    "value": s.value,
                    "category": s.category,
                    "description": s.description,
                    "updated_at": s.updated_at.isoformat() if s.updated_at else None
                }
                for s in settings
            ]
        }
    finally:
        session.close()


@router.put("/{key}")
def update_setting(key: str, update: SettingUpdate, current_user: dict = Depends(get_current_user)):
    """Update a setting value"""
    session = db.get_session()
    org_id = current_user["organization_id"]
    try:
        setting = session.query(Settings).filter(Settings.key == key, Settings.organization_id == org_id).first()
        if not setting:
            setting = Settings(key=key, value=update.value, category="general", organization_id=org_id)
            session.add(setting)
        else:
            setting.value = update.value
        session.commit()
        return {"message": "Setting updated", "key": key, "value": update.value}
    finally:
        session.close()


@router.post("/test-imap")
def test_imap_connection(request: TestImapRequest):
    """Test IMAP connection with provided credentials"""
    import imaplib
    import ssl
    try:
        context = ssl.create_default_context()
        mail = imaplib.IMAP4_SSL(request.server, request.port, ssl_context=context)
        mail.login(request.email, request.password)
        mail.logout()
        return {"success": True, "message": "Connexion réussie"}
    except imaplib.IMAP4.error as e:
        return {"success": False, "message": f"Erreur d'authentification : {str(e)}"}
    except ConnectionRefusedError:
        return {"success": False, "message": "Connexion refusée - vérifiez le serveur et le port"}
    except ssl.SSLError as e:
        return {"success": False, "message": f"Erreur SSL : {str(e)}"}
    except OSError as e:
        return {"success": False, "message": f"Serveur introuvable : {str(e)}"}
    except Exception as e:
        return {"success": False, "message": f"Erreur : {str(e)}"}
