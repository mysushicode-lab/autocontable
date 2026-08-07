"""WhatsApp Business API ingestion channel.

Multi-tenant architecture:
- Each organization stores its own credentials in Settings table
- A single global WHATSAPP_VERIFY_TOKEN is used for Meta webhook verification
- Phone-to-dossier mappings link client phone numbers to their cabinet's dossier

Flow:
  Client sends photo → Meta POST /api/whatsapp/webhook
  → identify org via phone mapping → load org credentials
  → download media → process invoice → reply confirmation
"""
import os
import logging
import hashlib
import hmac
from datetime import datetime
from fastapi import APIRouter, Request, HTTPException, Depends

import src.config  # noqa: F401

from src.storage.database import db
from src.storage.models import Settings, ClientFile, ProcessedFileHash
from src.api.auth import get_current_user

logger = logging.getLogger(__name__)
router = APIRouter()

WHATSAPP_VERIFY_TOKEN = os.getenv("WHATSAPP_VERIFY_TOKEN", "factpilot-verify-token-2026")


# ─── Webhook endpoints ────────────────────────────────────────────────────────

@router.get("/webhook")
def verify_webhook(request: Request):
    """Meta webhook verification (GET challenge).
    https://developers.facebook.com/docs/graph-api/webhooks/getting-started
    """
    params = request.query_params
    mode = params.get("hub.mode")
    token = params.get("hub.verify_token")
    challenge = params.get("hub.challenge")

    if mode == "subscribe" and token == WHATSAPP_VERIFY_TOKEN:
        return int(challenge)
    raise HTTPException(403, "Verification failed")


@router.post("/webhook")
async def receive_message(request: Request):
    """Receive incoming WhatsApp messages (Meta Cloud API format).
    https://developers.facebook.com/docs/whatsapp/cloud-api/webhooks/components
    """
    import json
    raw_body = await request.body()
    body = json.loads(raw_body)

    try:
        entry = body.get("entry", [{}])[0]
        changes = entry.get("changes", [{}])[0]
        value = changes.get("value", {})
        messages = value.get("messages", [])

        if not messages:
            return {"status": "ok"}

        for message in messages:
            _handle_message(message, raw_body, request)

    except Exception as e:
        logger.error(f"[whatsapp] Webhook error: {e}")

    # Always return 200 to avoid Meta retries
    return {"status": "ok"}


# ─── Phone-to-dossier mapping API ────────────────────────────────────────────

@router.get("/mappings")
def get_phone_mappings(current_user: dict = Depends(get_current_user)):
    """List WhatsApp phone-to-dossier mappings for the organization."""
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
    """Map a client's WhatsApp phone number to their dossier.
    payload: {"phone": "33612345678", "client_file_id": 42}
    """
    session = db.get_session()
    try:
        org_id = current_user["organization_id"]
        phone = _normalize_phone(payload.get("phone", ""))
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
        key = f"wa_phone_{_normalize_phone(phone)}"
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


# ─── Internal logic ───────────────────────────────────────────────────────────

def _handle_message(message: dict, raw_body: bytes, request: Request):
    """Process a single incoming WhatsApp message."""
    msg_type = message.get("type")
    sender_phone = message.get("from", "")
    msg_id = message.get("id", "")

    session = db.get_session()
    try:
        # Step 1: Identify org from sender phone
        mapping = _find_dossier_by_phone(session, sender_phone)
        if not mapping:
            logger.info(f"[whatsapp] Unknown sender {sender_phone}")
            return

        org_id = mapping["organization_id"]
        client_file_id = mapping["client_file_id"]

        # Step 2: Load org credentials
        creds = _get_org_credentials(session, org_id)
        api_token = creds.get("whatsapp_token", "")
        phone_number_id = creds.get("whatsapp_phone_number_id", "")

        if not api_token:
            logger.error(f"[whatsapp] Org {org_id} has no whatsapp_token configured")
            return

        # Step 3: Verify signature
        signature = request.headers.get("x-hub-signature-256", "")
        app_secret = creds.get("whatsapp_app_secret", "")
        if app_secret and not _verify_signature(raw_body, signature, app_secret):
            logger.warning(f"[whatsapp] Invalid signature for org {org_id}")
            return

        # Step 4: Only process images and documents
        if msg_type not in ("image", "document"):
            _send_reply(
                sender_phone,
                "Merci ! Envoyez vos factures en photo ou PDF pour un traitement automatique.",
                api_token, phone_number_id
            )
            return

        # Step 5: Extract media info
        media = message.get(msg_type, {})
        media_id = media.get("id")
        if not media_id:
            return

        mime_type = media.get("mime_type", "")
        filename = media.get("filename", f"wa_{msg_id}.{'pdf' if 'pdf' in mime_type else 'jpg'}")

        # Step 6: Download media
        file_path = _download_media(media_id, filename, api_token)
        if not file_path:
            _send_reply(sender_phone, "Erreur lors du telechargement. Reessayez.", api_token, phone_number_id)
            return

        # Step 7: Deduplication
        content_hash = _compute_file_hash(file_path)
        if session.query(ProcessedFileHash).filter(
            ProcessedFileHash.content_hash == content_hash,
            ProcessedFileHash.organization_id == org_id,
        ).first():
            _send_reply(sender_phone, "Ce document a deja ete traite.", api_token, phone_number_id)
            return

        # Step 8: Process invoice
        from src.invoice_processor import InvoiceProcessor
        from src.api.utils import create_or_update_invoice

        processor = InvoiceProcessor()
        invoice_data = processor.process_invoice(file_path)

        if invoice_data.get("not_an_invoice"):
            _send_reply(sender_phone, "Ce document ne semble pas etre une facture.", api_token, phone_number_id)
            return

        invoice = create_or_update_invoice(session, file_path, invoice_data, org_id)
        invoice.client_file_id = client_file_id
        invoice.content_hash = content_hash

        # Register hash
        session.add(ProcessedFileHash(
            content_hash=content_hash,
            filename=filename,
            organization_id=org_id,
        ))
        session.commit()

        # Step 9: Fire outbound webhook
        from src.api.webhooks import fire_webhook
        fire_webhook(org_id, "invoice.created", {
            "invoice_id": invoice.id,
            "invoice_number": invoice.invoice_number,
            "amount": invoice.amount,
            "supplier": invoice.supplier.name if invoice.supplier else None,
            "source": "whatsapp",
        })

        # Step 10: Reply confirmation
        supplier = invoice.supplier.name if invoice.supplier else "Fournisseur"
        amount = invoice.amount or 0
        _send_reply(
            sender_phone,
            f"Facture recue : {supplier} - {amount:.2f} EUR. Traitement en cours.",
            api_token, phone_number_id
        )

    except Exception as e:
        logger.error(f"[whatsapp] Error handling message: {e}")
    finally:
        session.close()


# ─── Helpers ──────────────────────────────────────────────────────────────────

def _get_org_credentials(session, org_id: int) -> dict:
    """Load WhatsApp credentials for an organization from Settings."""
    keys = ["whatsapp_token", "whatsapp_phone_number_id", "whatsapp_app_secret"]
    settings = session.query(Settings).filter(
        Settings.organization_id == org_id,
        Settings.key.in_(keys)
    ).all()
    return {s.key: s.value for s in settings}


def _find_dossier_by_phone(session, phone: str) -> dict:
    """Find organization and client_file_id mapped to a phone number."""
    phone_clean = _normalize_phone(phone)
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


def _verify_signature(payload: bytes, signature: str, app_secret: str) -> bool:
    """Verify Meta webhook signature (x-hub-signature-256).
    https://developers.facebook.com/docs/graph-api/webhooks/getting-started#verification-requests
    """
    if not signature:
        return False
    expected = hmac.new(app_secret.encode(), payload, hashlib.sha256).hexdigest()
    return hmac.compare_digest(f"sha256={expected}", signature)


def _download_media(media_id: str, filename: str, api_token: str) -> str:
    """Download media from WhatsApp Cloud API.
    https://developers.facebook.com/docs/whatsapp/cloud-api/reference/media
    """
    import requests

    try:
        headers = {"Authorization": f"Bearer {api_token}"}

        # Get media URL
        resp = requests.get(f"https://graph.facebook.com/v18.0/{media_id}", headers=headers, timeout=10)
        resp.raise_for_status()
        media_url = resp.json().get("url")
        if not media_url:
            return ""

        # Download file content
        resp = requests.get(media_url, headers=headers, timeout=30)
        resp.raise_for_status()

        # Save locally
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


def _send_reply(to_phone: str, text: str, api_token: str, phone_number_id: str):
    """Send a text reply via WhatsApp Cloud API.
    https://developers.facebook.com/docs/whatsapp/cloud-api/messages/text-messages
    """
    import requests

    if not api_token or not phone_number_id:
        logger.warning(f"[whatsapp] Cannot reply (not configured): {text}")
        return

    try:
        requests.post(
            f"https://graph.facebook.com/v18.0/{phone_number_id}/messages",
            json={
                "messaging_product": "whatsapp",
                "to": to_phone,
                "type": "text",
                "text": {"body": text},
            },
            headers={
                "Authorization": f"Bearer {api_token}",
                "Content-Type": "application/json",
            },
            timeout=10,
        )
    except Exception as e:
        logger.error(f"[whatsapp] Reply failed: {e}")


def _compute_file_hash(file_path: str) -> str:
    """Compute MD5 hash for deduplication."""
    h = hashlib.md5()
    with open(file_path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()


def _normalize_phone(phone: str) -> str:
    """Normalize phone number: strip spaces, +, dashes."""
    return phone.strip().replace("+", "").replace(" ", "").replace("-", "")
