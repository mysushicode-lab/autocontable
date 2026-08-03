"""WhatsApp Business API ingestion channel.

Receives invoice images/PDFs from clients via WhatsApp.
Webhook receives messages → downloads media → processes via InvoiceProcessor.
"""
import os
import logging
import hashlib
import hmac
from datetime import datetime
from fastapi import APIRouter, Request, HTTPException, Depends
from src.storage.database import db
from src.storage.models import Settings, ClientFile, Invoice, InvoiceStatus, ProcessedFileHash
from src.api.auth import get_current_user

logger = logging.getLogger(__name__)
router = APIRouter()

WHATSAPP_VERIFY_TOKEN = os.getenv("WHATSAPP_VERIFY_TOKEN", "")
WHATSAPP_API_TOKEN = os.getenv("WHATSAPP_API_TOKEN", "")
WHATSAPP_PHONE_NUMBER_ID = os.getenv("WHATSAPP_PHONE_NUMBER_ID", "")
WHATSAPP_APP_SECRET = os.getenv("WHATSAPP_APP_SECRET", "")


@router.get("/webhook")
def verify_webhook(request: Request):
    """WhatsApp webhook verification (GET challenge)."""
    params = request.query_params
    mode = params.get("hub.mode")
    token = params.get("hub.verify_token")
    challenge = params.get("hub.challenge")

    if mode == "subscribe" and token == WHATSAPP_VERIFY_TOKEN:
        return int(challenge)
    raise HTTPException(403, "Verification failed")


def _verify_meta_signature(payload: bytes, signature: str) -> bool:
    """Verify Meta webhook signature (x-hub-signature-256)."""
    if not WHATSAPP_APP_SECRET:
        logger.warning("[whatsapp] WHATSAPP_APP_SECRET not set — skipping signature check")
        return True
    if not signature:
        return False
    expected = hmac.new(
        WHATSAPP_APP_SECRET.encode(),
        payload,
        hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(f"sha256={expected}", signature)


@router.post("/webhook")
async def receive_message(request: Request):
    """Receive WhatsApp messages containing invoice documents/images.

    Flow:
    1. Verify Meta signature
    2. Extract media (image/document) from message
    3. Download media via WhatsApp Cloud API
    4. Match sender phone to a client dossier (via settings)
    5. Process through InvoiceProcessor
    6. Send confirmation reply
    """
    raw_body = await request.body()
    signature = request.headers.get("x-hub-signature-256", "")
    if not _verify_meta_signature(raw_body, signature):
        raise HTTPException(403, "Invalid signature")

    import json
    body = json.loads(raw_body)

    try:
        entry = body.get("entry", [{}])[0]
        changes = entry.get("changes", [{}])[0]
        value = changes.get("value", {})
        messages = value.get("messages", [])

        if not messages:
            return {"status": "ok"}

        for message in messages:
            msg_type = message.get("type")
            sender_phone = message.get("from", "")
            msg_id = message.get("id", "")

            # Only process images and documents
            if msg_type not in ("image", "document"):
                _send_reply(sender_phone, "Merci ! Envoyez vos factures en photo ou PDF pour qu'elles soient traitées automatiquement.")
                continue

            # Get media info
            if msg_type == "image":
                media = message.get("image", {})
            else:
                media = message.get("document", {})

            media_id = media.get("id")
            mime_type = media.get("mime_type", "")
            filename = media.get("filename", f"whatsapp_{msg_id}.{'pdf' if 'pdf' in mime_type else 'jpg'}")

            if not media_id:
                continue

            # Download media
            file_path = _download_media(media_id, filename)
            if not file_path:
                _send_reply(sender_phone, "Erreur lors du téléchargement. Veuillez réessayer.")
                continue

            # Find client dossier by phone number
            session = db.get_session()
            try:
                mapping = _find_dossier_by_phone(session, sender_phone)
                if not mapping:
                    _send_reply(sender_phone, "Votre numéro n'est pas encore associé à un dossier. Contactez votre comptable.")
                    continue

                org_id = mapping["organization_id"]
                client_file_id = mapping["client_file_id"]

                # Check duplicate
                content_hash = _compute_file_hash(file_path)
                existing = session.query(ProcessedFileHash).filter(
                    ProcessedFileHash.content_hash == content_hash,
                    ProcessedFileHash.organization_id == org_id,
                ).first()
                if existing:
                    _send_reply(sender_phone, "Ce document a déjà été traité.")
                    continue

                # Process invoice
                from src.invoice_processor import InvoiceProcessor
                processor = InvoiceProcessor()
                invoice_data = processor.process_invoice(file_path, email_metadata={
                    "email_from": f"whatsapp:{sender_phone}",
                    "email_subject": f"WhatsApp {filename}",
                })

                if invoice_data.get("not_an_invoice"):
                    _send_reply(sender_phone, "Ce document ne semble pas être une facture.")
                    continue

                # Create invoice
                invoice = Invoice(
                    invoice_number=invoice_data.get("invoice_number") or f"WA-{datetime.now().strftime('%Y%m%d%H%M%S')}",
                    supplier_id=invoice_data.get("supplier_id"),
                    amount=invoice_data.get("amount") or 0,
                    amount_ht=invoice_data.get("amount_ht"),
                    amount_tax=invoice_data.get("amount_tax"),
                    date=invoice_data.get("date") or datetime.now(),
                    due_date=invoice_data.get("due_date"),
                    category=invoice_data.get("category"),
                    reference_number=invoice_data.get("reference_number"),
                    organization_id=org_id,
                    client_file_id=client_file_id,
                    file_path=file_path,
                    email_from=f"whatsapp:{sender_phone}",
                    email_subject=f"WhatsApp — {filename}",
                    content_hash=content_hash,
                    status=InvoiceStatus.PROCESSED,
                )
                session.add(invoice)

                # Register hash
                session.add(ProcessedFileHash(
                    content_hash=content_hash,
                    filename=filename,
                    organization_id=org_id,
                ))
                session.commit()

                # Reply with confirmation
                supplier = invoice_data.get("supplier_name") or "Fournisseur"
                amount = invoice_data.get("amount") or 0
                _send_reply(sender_phone, f"✓ Facture reçue : {supplier} — {amount:.2f}€. Elle sera traitée par votre comptable.")

            finally:
                session.close()

    except Exception as e:
        logger.error(f"[whatsapp] Error processing message: {e}")

    return {"status": "ok"}


@router.get("/mappings")
def get_phone_mappings(current_user: dict = Depends(get_current_user)):
    """Get WhatsApp phone-to-dossier mappings for the organization."""
    session = db.get_session()
    try:
        org_id = current_user["organization_id"]
        settings = session.query(Settings).filter(
            Settings.organization_id == org_id,
            Settings.category == "whatsapp",
        ).all()

        mappings = []
        for s in settings:
            if s.key.startswith("wa_phone_"):
                phone = s.key.replace("wa_phone_", "")
                mappings.append({"phone": phone, "client_file_id": int(s.value)})

        return {"mappings": mappings}
    finally:
        session.close()


@router.post("/mappings")
def add_phone_mapping(payload: dict, current_user: dict = Depends(get_current_user)):
    """Map a WhatsApp phone number to a client dossier.

    payload: {"phone": "33612345678", "client_file_id": 42}
    """
    session = db.get_session()
    try:
        org_id = current_user["organization_id"]
        phone = payload.get("phone", "").strip().replace("+", "")
        client_file_id = payload.get("client_file_id")

        if not phone or not client_file_id:
            raise HTTPException(400, "phone et client_file_id requis")

        # Verify dossier belongs to org
        cf = session.query(ClientFile).filter(
            ClientFile.id == client_file_id,
            ClientFile.organization_id == org_id
        ).first()
        if not cf:
            raise HTTPException(404, "Dossier non trouvé")

        key = f"wa_phone_{phone}"
        existing = session.query(Settings).filter(
            Settings.organization_id == org_id,
            Settings.key == key,
            Settings.category == "whatsapp",
        ).first()

        if existing:
            existing.value = str(client_file_id)
        else:
            session.add(Settings(
                organization_id=org_id,
                key=key,
                value=str(client_file_id),
                category="whatsapp",
            ))
        session.commit()
        return {"success": True}
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


@router.delete("/mappings/{phone}")
def remove_phone_mapping(phone: str, current_user: dict = Depends(get_current_user)):
    """Remove a phone-to-dossier mapping."""
    session = db.get_session()
    try:
        org_id = current_user["organization_id"]
        key = f"wa_phone_{phone}"
        setting = session.query(Settings).filter(
            Settings.organization_id == org_id,
            Settings.key == key,
            Settings.category == "whatsapp",
        ).first()
        if setting:
            session.delete(setting)
            session.commit()
        return {"success": True}
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


# ─── Helpers ───────────────────────────────────────────────────────────────

def _download_media(media_id: str, filename: str) -> str:
    """Download media from WhatsApp Cloud API."""
    import requests

    if not WHATSAPP_API_TOKEN:
        logger.error("[whatsapp] WHATSAPP_API_TOKEN not configured")
        return ""

    # Step 1: Get media URL
    url = f"https://graph.facebook.com/v18.0/{media_id}"
    headers = {"Authorization": f"Bearer {WHATSAPP_API_TOKEN}"}

    try:
        resp = requests.get(url, headers=headers, timeout=10)
        resp.raise_for_status()
        media_url = resp.json().get("url")

        if not media_url:
            return ""

        # Step 2: Download file
        resp = requests.get(media_url, headers=headers, timeout=30)
        resp.raise_for_status()

        from src.utils.paths import INVOICES_DIR
        os.makedirs(INVOICES_DIR, exist_ok=True)
        timestamp = datetime.now().strftime("%Y%m%d%H%M%S%f")
        safe_filename = f"{timestamp}_{filename.replace(' ', '_')}"
        file_path = os.path.join(INVOICES_DIR, safe_filename)

        with open(file_path, "wb") as f:
            f.write(resp.content)

        return file_path
    except Exception as e:
        logger.error(f"[whatsapp] Media download failed: {e}")
        return ""


def _find_dossier_by_phone(session, phone: str) -> dict:
    """Find organization and client_file_id mapped to a phone number."""
    # Normalize phone (remove + prefix)
    phone_clean = phone.strip().replace("+", "")

    # Search across all orgs for this phone mapping
    key = f"wa_phone_{phone_clean}"
    setting = session.query(Settings).filter(
        Settings.key == key,
        Settings.category == "whatsapp",
    ).first()

    if setting:
        return {
            "organization_id": setting.organization_id,
            "client_file_id": int(setting.value),
        }
    return None


def _compute_file_hash(file_path: str) -> str:
    """Compute MD5 hash of a file for deduplication."""
    h = hashlib.md5()
    with open(file_path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()


def _send_reply(to_phone: str, text: str):
    """Send a text reply via WhatsApp Cloud API."""
    import requests

    if not WHATSAPP_API_TOKEN or not WHATSAPP_PHONE_NUMBER_ID:
        logger.warning(f"[whatsapp] Cannot reply (not configured): {text}")
        return

    url = f"https://graph.facebook.com/v18.0/{WHATSAPP_PHONE_NUMBER_ID}/messages"
    headers = {
        "Authorization": f"Bearer {WHATSAPP_API_TOKEN}",
        "Content-Type": "application/json",
    }
    payload = {
        "messaging_product": "whatsapp",
        "to": to_phone,
        "type": "text",
        "text": {"body": text},
    }

    try:
        requests.post(url, json=payload, headers=headers, timeout=10)
    except Exception as e:
        logger.error(f"[whatsapp] Reply failed: {e}")
