"""
Meta Conversions API (CAPI) - Server-side event tracking

Sends events from the server to bypass ad blockers and improve Event Match Quality.
https://developers.facebook.com/docs/marketing-api/conversions-api
"""

import os
import hashlib
import time
import requests
from typing import Dict, Any, Optional


def sha256(text: str) -> str:
    """Hash string with SHA-256 (required by Meta for PII like email/phone)"""
    return hashlib.sha256(text.lower().strip().encode()).hexdigest()


def send_meta_conversion_event(event: Dict[str, Any]) -> bool:
    """Send event to Meta Conversions API"""
    pixel_id = os.getenv('NEXT_PUBLIC_FACEBOOK_PIXEL_ID')
    access_token = os.getenv('META_CONVERSIONS_API_TOKEN')

    if not pixel_id or not access_token:
        print('[Meta CAPI] Missing configuration:', {
            'hasPixelId': bool(pixel_id),
            'hasAccessToken': bool(access_token),
        })
        return False

    try:
        url = f'https://graph.facebook.com/v21.0/{pixel_id}/events'

        # Add test_event_code in development to avoid polluting production metrics
        is_dev = os.getenv('FLASK_ENV') == 'development'
        test_event_code = 'TEST12345' if is_dev else None

        payload = {
            'data': [event],
            'access_token': access_token,
        }

        if test_event_code:
            payload['test_event_code'] = test_event_code

        response = requests.post(url, json=payload, timeout=10)
        result = response.json()

        if not response.ok:
            print('[Meta CAPI] API error:', result)
            return False

        print('[Meta CAPI] Event sent successfully:', {
            'event_name': event.get('event_name'),
            'event_id': event.get('event_id'),
            'events_received': result.get('events_received'),
            'fbtrace_id': result.get('fbtrace_id'),
            'test_mode': bool(test_event_code),
        })

        return True

    except Exception as error:
        print('[Meta CAPI] Failed to send event:', error)
        return False


def track_lead_server(
    email: str,
    lead_id: str,
    value: Optional[float] = None,
    currency: str = 'USD',
    user_agent: Optional[str] = None,
    ip_address: Optional[str] = None,
    event_id: Optional[str] = None,
    fbc: Optional[str] = None,
    fbp: Optional[str] = None,
    custom_data: Optional[Dict[str, Any]] = None,
) -> None:
    """Track Lead event (called from quiz email capture)"""
    email_hash = sha256(email)

    event = {
        'event_name': 'Lead',
        'event_time': int(time.time()),
        'event_id': event_id,
        'action_source': 'website',
        'user_data': {
            'em': email_hash,
            'client_ip_address': ip_address,
            'client_user_agent': user_agent,
            'fbc': fbc,
            'fbp': fbp,
            'external_id': lead_id,
        },
        'custom_data': {
            'content_name': 'accounting_quiz_lead',
            'lead_id': lead_id,
            'value': value,
            'currency': currency,
            **(custom_data or {}),
        },
    }

    send_meta_conversion_event(event)


def track_signup_server(
    email: str,
    user_id: str,
    source: str = 'direct',
    user_agent: Optional[str] = None,
    ip_address: Optional[str] = None,
    event_id: Optional[str] = None,
    fbc: Optional[str] = None,
    fbp: Optional[str] = None,
) -> None:
    """Track CompleteRegistration event (called from signup API)"""
    email_hash = sha256(email)

    event = {
        'event_name': 'CompleteRegistration',
        'event_time': int(time.time()),
        'event_id': event_id,
        'action_source': 'website',
        'user_data': {
            'em': email_hash,
            'client_ip_address': ip_address,
            'client_user_agent': user_agent,
            'fbc': fbc,
            'fbp': fbp,
            'external_id': user_id,
        },
        'custom_data': {
            'content_name': 'user_signup',
            'source': source,
            'user_id': user_id,
        },
    }

    send_meta_conversion_event(event)


def track_purchase_server(
    email: str,
    amount: float,
    currency: str,
    transaction_id: str,
    plan_name: str,
    user_agent: Optional[str] = None,
    ip_address: Optional[str] = None,
    event_id: Optional[str] = None,
    fbc: Optional[str] = None,
    fbp: Optional[str] = None,
    external_id: Optional[str] = None,
) -> None:
    """Track Purchase event (called from payment webhook)"""
    email_hash = sha256(email)

    event = {
        'event_name': 'Purchase',
        'event_time': int(time.time()),
        'event_id': event_id,
        'action_source': 'website',
        'user_data': {
            'em': email_hash,
            'client_ip_address': ip_address,
            'client_user_agent': user_agent,
            'fbc': fbc,
            'fbp': fbp,
            'external_id': external_id,
        },
        'custom_data': {
            'value': amount,
            'currency': currency,
            'content_name': plan_name,
            'content_type': 'product',
            'transaction_id': transaction_id,
        },
    }

    send_meta_conversion_event(event)
