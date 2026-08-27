"""Server-side analytics tracking for Meta Ads funnel events."""
import logging
import os
import urllib.request
import json as _json
import hashlib
import time

logger = logging.getLogger(__name__)


def track_meta_event(
    email: str,
    event_name: str,
    first_name: str = None,
    custom_data: dict = None,
    user_data_extra: dict = None
) -> bool:
    """
    Send event to Meta Conversions API (server-side tracking).

    Tracked events:
    - Lead: Quiz completed + email captured
    - Purchase: Paid plan activation
    - StartTrial: Trial activation (from signup)
    - InitiateCheckout: High-intent signals (trial ending soon, pricing viewed)

    Args:
        email: Contact email
        event_name: Facebook event name ('Lead', 'Purchase', 'StartTrial', etc.)
        first_name: Contact first name (optional, for hashing)
        custom_data: Additional event data (value, currency, content_type, etc.)
        user_data_extra: Additional user data (phone, address, etc.)

    Returns:
        bool: True if event sent successfully, False otherwise
    """
    pixel_id = os.getenv('FACEBOOK_PIXEL_ID')
    api_token = os.getenv('FACEBOOK_CONVERSIONS_API_TOKEN')

    if not pixel_id or not api_token:
        logger.debug('[Meta API] Conversions API not configured')
        return False

    try:
        # Hash PII for privacy compliance (SHA-256)
        hashed_email = hashlib.sha256(email.lower().encode()).hexdigest()

        user_data = {'em': hashed_email}

        # Add first name hash if provided
        if first_name:
            hashed_fn = hashlib.sha256(first_name.lower().encode()).hexdigest()
            user_data['fn'] = hashed_fn

        # Merge additional user data if provided
        if user_data_extra:
            user_data.update(user_data_extra)

        # Build event payload
        event_payload = {
            'event_name': event_name,
            'event_time': int(time.time()),
            'user_data': user_data,
            'action_source': 'website',
            'event_source_url': os.getenv('FRONTEND_URL', 'http://localhost:3000'),
            'custom_data': custom_data or {
                'value': 0,
                'currency': 'EUR',
            }
        }

        # Send to Meta
        payload = {
            'data': [event_payload],
            'access_token': api_token
        }

        data = _json.dumps(payload).encode()
        req = urllib.request.Request(
            f'https://graph.facebook.com/v18.0/{pixel_id}/events',
            data=data,
            headers={'Content-Type': 'application/json'},
            method='POST',
        )

        with urllib.request.urlopen(req, timeout=10) as resp:
            logger.info(f'[Meta Conversions API] {event_name} event sent for {email} — status {resp.status}')
            return True

    except Exception as exc:
        logger.warning(f'[Meta API] Failed to send {event_name} event for {email}: {exc}')
        return False


def track_trial_start(user_email: str, user_name: str = None, plan: str = 'free') -> None:
    """Track trial activation in Meta Ads."""
    track_meta_event(
        email=user_email,
        event_name='StartTrial',
        first_name=user_name,
        custom_data={
            'value': 0,
            'currency': 'EUR',
            'content_name': f'Trial Start - {plan}',
            'content_type': 'trial',
        }
    )


def track_trial_ending_soon(user_email: str, user_name: str = None, days_left: int = 3) -> None:
    """Track trial ending soon (urgency signal for retargeting)."""
    track_meta_event(
        email=user_email,
        event_name='InitiateCheckout',
        first_name=user_name,
        custom_data={
            'value': 0,
            'currency': 'EUR',
            'content_name': f'Trial Ending Soon ({days_left} days)',
            'content_type': 'urgency_signal',
        }
    )


def track_purchase(user_email: str, user_name: str = None, value: float = 0, plan: str = 'unknown', currency: str = 'EUR') -> None:
    """Track purchase/upgrade in Meta Ads."""
    track_meta_event(
        email=user_email,
        event_name='Purchase',
        first_name=user_name,
        custom_data={
            'value': value,
            'currency': currency,
            'content_name': f'Purchase - {plan}',
            'content_type': 'purchase',
        }
    )


def track_account_abandoned(user_email: str, user_name: str = None, days_since_signup: int = 1) -> None:
    """Track abandoned account (signed up but zero product usage) for retargeting."""
    track_meta_event(
        email=user_email,
        event_name='CustomEvent',
        first_name=user_name,
        custom_data={
            'value': 0,
            'currency': 'EUR',
            'content_name': f'Account Abandoned ({days_since_signup}d)',
            'content_type': 'churn_signal',
        }
    )
