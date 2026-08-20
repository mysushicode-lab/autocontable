"""SendGrid email event webhook + unsubscribe handler.

Handles:
  GET  /api/email-events?action=unsubscribe&email=… — one-click unsubscribe from footer link
  POST /api/email-events                             — SendGrid signed event webhook

SendGrid configuration:
  Settings → Mail Settings → Event Webhook
  URL: https://api.factpilot.fr/api/email-events
  Events to enable: open, click, bounce, spamreport, unsubscribe, group_unsubscribe
"""
import hmac
import hashlib
import json
import os
import logging
from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse
from datetime import datetime

from src.storage.database import db
from src.storage.models import EmailSuppression, EmailEvent, User, QuizContact, Organization

logger = logging.getLogger(__name__)
router = APIRouter()

SENDGRID_WEBHOOK_SECRET = os.getenv('EMAIL_WEBHOOK_SECRET', '')

# Map SendGrid event names to internal names
_SG_MAP = {
    'open':               'opened',
    'click':              'clicked',
    'bounce':             'bounced',
    'spamreport':         'complained',
    'unsubscribe':        'unsubscribed',
    'group_unsubscribe':  'unsubscribed',
}


def _verify(request: Request, raw: bytes) -> bool:
    """Optional HMAC-SHA256 check — skip if secret not configured (dev mode)."""
    if not SENDGRID_WEBHOOK_SECRET:
        return True
    sig = request.headers.get('X-Twilio-Email-Event-Webhook-Signature', '')
    ts  = request.headers.get('X-Twilio-Email-Event-Webhook-Timestamp', '')
    expected = hmac.new(
        SENDGRID_WEBHOOK_SECRET.encode(),
        (ts + raw.decode()).encode(),
        hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(sig, expected)


def _suppress(session, email: str, reason: str):
    """Upsert suppression record."""
    existing = session.query(EmailSuppression).filter(
        EmailSuppression.email == email.lower()
    ).first()
    if not existing:
        session.add(EmailSuppression(email=email.lower(), reason=reason))
    else:
        existing.reason = reason
    session.commit()


def _resolve_ids(session, email: str) -> dict:
    """Return organization_id and/or quiz_contact_id for a given email address."""
    result = {}
    user = session.query(User).filter(User.email == email).first()
    if user:
        result['organization_id'] = user.organization_id
        result['user_id'] = user.id
    contact = session.query(QuizContact).filter(QuizContact.email == email).first()
    if contact:
        result['quiz_contact_id'] = contact.id
    return result


def _record_event(session, email: str, event: str, email_type: str = 'unknown', bounce_type: str = None):
    """Insert an EmailEvent row and refresh engagement score for the entity."""
    ids = _resolve_ids(session, email)
    if not ids:
        return  # Unknown email — ignore

    ev = EmailEvent(
        organization_id=ids.get('organization_id'),
        quiz_contact_id=ids.get('quiz_contact_id'),
        user_id=ids.get('user_id'),
        email_type=email_type,
        event=event,
        bounce_type=bounce_type,
        occurred_at=datetime.utcnow(),
    )
    session.add(ev)
    session.commit()

    # Recalculate engagement score (non-blocking, best-effort)
    try:
        from src.scheduler.engagement import calculate_engagement_score
        if ids.get('organization_id'):
            calculate_engagement_score(session, organization_id=ids['organization_id'])
        elif ids.get('quiz_contact_id'):
            calculate_engagement_score(session, quiz_contact_id=ids['quiz_contact_id'])
    except Exception as e:
        logger.warning(f"[EmailEvents] Score recalc failed for {email}: {e}")


# ─── Endpoints ────────────────────────────────────────────────────────────────

@router.get('/email-events')
def unsubscribe_link(request: Request):
    """One-click unsubscribe from email footer link (GET).

    URL: /api/email-events?action=unsubscribe&email=[[email]]
    """
    action = request.query_params.get('action')
    email  = request.query_params.get('email', '').strip().lower()

    if action == 'unsubscribe' and email:
        session = db.get_session()
        try:
            _suppress(session, email, 'unsubscribed')
            _record_event(session, email, 'unsubscribed', 'footer_link')
            logger.info(f"[EmailEvents] Unsubscribed: {email}")
        except Exception as e:
            logger.error(f"[EmailEvents] Unsubscribe error for {email}: {e}")
        finally:
            session.close()

        frontend = os.getenv('FRONTEND_URL', 'https://factpilot.fr')
        return HTMLResponse(
            f"<html><body style='font-family:Helvetica,sans-serif;max-width:480px;margin:60px auto;'>"
            f"<h2>Désabonnement confirmé</h2>"
            f"<p>Vous ne recevrez plus d'emails marketing de FactPilot.</p>"
            f"<p><a href='{frontend}/account/preferences'>Gérer mes préférences</a></p>"
            f"</body></html>"
        )

    return HTMLResponse("<p>Paramètre invalide.</p>", status_code=400)


@router.post('/email-events')
async def sendgrid_webhook(request: Request):
    """Handle signed SendGrid event webhook (open, click, bounce, spam, unsubscribe).

    All events are recorded in EmailEvent for engagement scoring.
    Suppression events (bounce hard, spam, unsub) also update EmailSuppression.
    """
    raw = await request.body()

    if not _verify(request, raw):
        logger.warning("[EmailEvents] Webhook signature invalid — rejected")
        return {"received": False}

    try:
        events = json.loads(raw)
        if not isinstance(events, list):
            events = [events]
    except Exception:
        return {"received": False}

    session = db.get_session()
    try:
        for evt in events:
            raw_event  = evt.get('event', '')
            email      = (evt.get('email') or '').strip().lower()
            email_type = (evt.get('emailTemplateId') or evt.get('email_type') or 'unknown')
            bounce_type = evt.get('type')  # 'hard' | 'soft' for bounce events

            if not email or not raw_event:
                continue

            event = _SG_MAP.get(raw_event, raw_event)

            # Record the event + refresh score
            _record_event(session, email, event, email_type, bounce_type)

            # Suppression for destructive events
            if event == 'bounced' and bounce_type == 'hard':
                _suppress(session, email, 'hard_bounce')
                logger.info(f"[EmailEvents] Hard bounce: {email}")

            elif event == 'complained':
                _suppress(session, email, 'spam_complaint')
                logger.info(f"[EmailEvents] Spam complaint: {email}")

            elif event == 'unsubscribed':
                _suppress(session, email, 'unsubscribed')
                logger.info(f"[EmailEvents] Unsubscribed: {email}")

    except Exception as e:
        logger.error(f"[EmailEvents] Processing error: {e}")
        session.rollback()
    finally:
        session.close()

    return {"received": True}
