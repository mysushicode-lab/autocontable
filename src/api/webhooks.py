"""Outbound webhook management — notify external systems of events."""
import os
import json
import logging
import hashlib
import hmac
from datetime import datetime
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException
import threading

import src.config  # noqa: F401

from src.storage.database import db
from src.storage.models import Settings
from src.api.auth import get_current_user
from src.api.billing import require_feature

logger = logging.getLogger(__name__)
router = APIRouter()

WEBHOOK_SECRET = os.getenv("WEBHOOK_SECRET", "factpilot-webhook-secret")


def fire_webhook(org_id: int, event: str, payload: dict):
    """Fire a webhook asynchronously (non-blocking).

    Events: invoice.created, invoice.matched, match.confirmed, match.rejected,
            entries.pushed, dossier.created
    """
    def _send():
        session = db.get_session()
        try:
            setting = session.query(Settings).filter(
                Settings.organization_id == org_id,
                Settings.key == "webhook_url",
                Settings.category == "webhooks",
            ).first()

            if not setting or not setting.value:
                return

            url = setting.value

            # Build webhook payload
            webhook_payload = {
                "event": event,
                "timestamp": datetime.utcnow().isoformat(),
                "organization_id": org_id,
                "data": payload,
            }

            # Sign the payload
            body = json.dumps(webhook_payload, default=str)
            signature = hmac.new(
                WEBHOOK_SECRET.encode(),
                body.encode(),
                hashlib.sha256
            ).hexdigest()

            # Send
            import requests
            try:
                resp = requests.post(
                    url,
                    data=body,
                    headers={
                        "Content-Type": "application/json",
                        "X-Webhook-Signature": signature,
                        "X-Webhook-Event": event,
                    },
                    timeout=10,
                )
                logger.info(f"[webhook] {event} → {url}: {resp.status_code}")
            except Exception as e:
                logger.error(f"[webhook] Failed to send {event}: {e}")
        finally:
            session.close()

    # Fire asynchronously
    thread = threading.Thread(target=_send, daemon=True)
    thread.start()


@router.get("/config")
def get_webhook_config(current_user: dict = Depends(require_feature("webhooks"))):
    """Get webhook configuration."""
    session = db.get_session()
    try:
        org_id = current_user["organization_id"]
        url_setting = session.query(Settings).filter(
            Settings.organization_id == org_id,
            Settings.key == "webhook_url",
            Settings.category == "webhooks",
        ).first()

        events_setting = session.query(Settings).filter(
            Settings.organization_id == org_id,
            Settings.key == "webhook_events",
            Settings.category == "webhooks",
        ).first()

        return {
            "url": url_setting.value if url_setting else None,
            "events": json.loads(events_setting.value) if events_setting and events_setting.value else [],
            "available_events": [
                "invoice.created",
                "invoice.matched",
                "match.confirmed",
                "match.rejected",
                "entries.pushed",
                "dossier.created",
            ]
        }
    finally:
        session.close()


@router.put("/config")
def update_webhook_config(payload: dict, current_user: dict = Depends(require_feature("webhooks"))):
    """Update webhook configuration.

    payload: {"url": "https://...", "events": ["invoice.created", "match.confirmed"]}
    """
    if current_user.get("role") != "admin":
        raise HTTPException(403, "Admin requis")

    session = db.get_session()
    try:
        org_id = current_user["organization_id"]
        url = payload.get("url", "")
        events = payload.get("events", [])

        # Upsert URL
        url_setting = session.query(Settings).filter(
            Settings.organization_id == org_id,
            Settings.key == "webhook_url",
            Settings.category == "webhooks",
        ).first()
        if url_setting:
            url_setting.value = url
        else:
            session.add(Settings(organization_id=org_id, key="webhook_url", value=url, category="webhooks"))

        # Upsert events
        events_setting = session.query(Settings).filter(
            Settings.organization_id == org_id,
            Settings.key == "webhook_events",
            Settings.category == "webhooks",
        ).first()
        if events_setting:
            events_setting.value = json.dumps(events)
        else:
            session.add(Settings(organization_id=org_id, key="webhook_events", value=json.dumps(events), category="webhooks"))

        session.commit()
        return {"success": True}
    finally:
        session.close()


@router.post("/test")
def test_webhook(current_user: dict = Depends(require_feature("webhooks"))):
    """Send a test webhook event."""
    org_id = current_user["organization_id"]
    fire_webhook(org_id, "test", {"message": "Webhook test depuis Autocontable"})
    return {"success": True, "message": "Webhook de test envoyé"}
