"""Public upload link — no auth required, token-based access."""
import os
import hashlib
import hmac
import time
import logging
from fastapi import APIRouter, UploadFile, File, HTTPException, Depends
from typing import Optional

from src.storage.database import db
from src.storage.models import ClientFile, Invoice
from src.invoice_processor.invoice_processor import InvoiceProcessor
from src.api.utils import create_or_update_invoice
from src.api.auth import get_current_user

logger = logging.getLogger(__name__)
router = APIRouter()

# Secret for signing upload tokens (fallback to a random one if not set)
_UPLOAD_SECRET = os.getenv("UPLOAD_LINK_SECRET", os.getenv("SECRET_KEY", "autocontable-upload-default-secret"))

from src.utils.paths import INVOICE_UPLOAD_DIR as UPLOAD_DIR


def generate_upload_token(client_file_id: int, organization_id: int) -> str:
    """Generate a signed upload token for a dossier.

    Token format: {client_file_id}:{org_id}:{timestamp}:{signature}
    Tokens don't expire (by design — the accountant can regenerate if needed).
    """
    payload = f"{client_file_id}:{organization_id}:{int(time.time())}"
    signature = hmac.new(
        _UPLOAD_SECRET.encode(),
        payload.encode(),
        hashlib.sha256
    ).hexdigest()[:16]
    return f"{payload}:{signature}"


def verify_upload_token(token: str) -> dict:
    """Verify and decode an upload token.

    Returns: {"client_file_id": int, "organization_id": int} or raises HTTPException
    """
    try:
        parts = token.split(":")
        if len(parts) != 4:
            raise ValueError("Invalid token format")

        client_file_id = int(parts[0])
        organization_id = int(parts[1])
        timestamp = parts[2]
        provided_sig = parts[3]

        # Verify signature
        payload = f"{client_file_id}:{organization_id}:{timestamp}"
        expected_sig = hmac.new(
            _UPLOAD_SECRET.encode(),
            payload.encode(),
            hashlib.sha256
        ).hexdigest()[:16]

        if not hmac.compare_digest(provided_sig, expected_sig):
            raise ValueError("Invalid signature")

        # Token expiry
        _expiry_days = int(os.getenv("UPLOAD_TOKEN_EXPIRY_DAYS", 30))
        token_age = int(time.time()) - int(timestamp)
        if token_age > _expiry_days * 24 * 60 * 60:
            raise ValueError("Token expired")

        return {"client_file_id": client_file_id, "organization_id": organization_id}
    except (ValueError, IndexError) as e:
        raise HTTPException(403, "Lien de dépôt invalide ou expiré")


@router.post("/upload/{token}")
async def public_upload(token: str, file: UploadFile = File(...)):
    """Public upload endpoint — no auth required, validated by token."""
    # Verify token
    token_data = verify_upload_token(token)
    client_file_id = token_data["client_file_id"]
    organization_id = token_data["organization_id"]

    # Validate file
    allowed_extensions = {".pdf", ".png", ".jpg", ".jpeg"}
    extension = os.path.splitext(file.filename or "")[1].lower()
    if extension not in allowed_extensions:
        raise HTTPException(400, "Format non supporté. Envoyez un PDF ou une image.")

    # Size limit
    file_bytes = await file.read()
    _max_upload = int(os.getenv("MAX_UPLOAD_SIZE_MB", 10)) * 1024 * 1024
    if len(file_bytes) > _max_upload:
        raise HTTPException(400, "Fichier trop volumineux (max 10 Mo)")

    # Save file
    from src.utils.encryption import encrypt_file, ENCRYPTION_AVAILABLE

    os.makedirs(UPLOAD_DIR, exist_ok=True)
    timestamp = str(int(time.time() * 1000))
    safe_filename = f"{timestamp}_{file.filename}"
    file_path = os.path.join(UPLOAD_DIR, safe_filename)

    with open(file_path, 'wb') as f:
        f.write(file_bytes)

    # Encrypt after saving if encryption is enabled
    if ENCRYPTION_AVAILABLE:
        if encrypt_file(file_path):
            file_path = file_path + '.enc'

    # Process the invoice
    session = db.get_session()
    try:
        # Verify dossier still exists
        cf = session.query(ClientFile).filter(
            ClientFile.id == client_file_id,
            ClientFile.organization_id == organization_id
        ).first()
        if not cf:
            os.remove(file_path)
            raise HTTPException(404, "Dossier non trouvé")

        # Process with AI extraction
        try:
            processor = InvoiceProcessor()
            result = processor.process_invoice(file_path)

            if result and result.get("is_invoice"):
                invoice = create_or_update_invoice(
                    session=session,
                    file_path=file_path,
                    extracted_data=result,
                    organization_id=organization_id,
                )
                invoice.client_file_id = client_file_id
                session.commit()
                return {
                    "success": True,
                    "message": f"Facture reçue : {result.get('invoice_number', 'N/A')} — {result.get('supplier_name', 'Fournisseur')}",
                }
            else:
                # Save as unprocessed
                return {
                    "success": True,
                    "message": "Document reçu. Il sera traité par votre comptable.",
                }
        except Exception as e:
            logger.error(f"Public upload processing failed: {e}")
            return {
                "success": True,
                "message": "Document reçu. Il sera traité prochainement.",
            }
    finally:
        session.close()


@router.get("/info/{token}")
def get_upload_link_info(token: str):
    """Get basic info about an upload link (dossier name) — no auth."""
    token_data = verify_upload_token(token)
    session = db.get_session()
    try:
        cf = session.query(ClientFile).filter(
            ClientFile.id == token_data["client_file_id"],
            ClientFile.organization_id == token_data["organization_id"]
        ).first()
        if not cf:
            raise HTTPException(404, "Lien invalide")
        return {"dossier_name": cf.name, "active": cf.is_active}
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


# --- Authenticated endpoint to generate/get token ---

@router.post("/generate/{client_file_id}")
def generate_link(client_file_id: int, current_user: dict = Depends(get_current_user)):
    """Generate an upload link for a dossier. Accountants/admins only."""
    if current_user.get("role") == "client":
        raise HTTPException(403, "Accès refusé")

    session = db.get_session()
    try:
        org_id = current_user["organization_id"]
        cf = session.query(ClientFile).filter(
            ClientFile.id == client_file_id,
            ClientFile.organization_id == org_id
        ).first()
        if not cf:
            raise HTTPException(404, "Dossier non trouvé")

        token = generate_upload_token(client_file_id, org_id)
        # The frontend URL would be: {FRONTEND_URL}/depot/{token}
        return {"token": token, "dossier_name": cf.name}
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()
