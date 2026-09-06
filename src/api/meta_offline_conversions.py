"""
Meta Offline Conversions API

Track conversions that happen outside the website:
- Phone orders
- In-person sales
- CRM-tracked deals
- Post-trial conversions

https://developers.facebook.com/docs/marketing-api/offline-conversions
"""

import os
import time
import requests
from typing import Dict, Any, Optional
from .meta_conversions import sha256


def upload_offline_conversion(
    event_name: str,
    event_time: int,
    email: Optional[str] = None,
    phone: Optional[str] = None,
    first_name: Optional[str] = None,
    last_name: Optional[str] = None,
    value: Optional[float] = None,
    currency: str = 'USD',
    order_id: Optional[str] = None,
    custom_data: Optional[Dict[str, Any]] = None,
) -> bool:
    """Upload offline conversion to Meta"""
    pixel_id = os.getenv('NEXT_PUBLIC_FACEBOOK_PIXEL_ID')
    access_token = os.getenv('META_CONVERSIONS_API_TOKEN')

    if not pixel_id or not access_token:
        print('[Offline Conversions] Missing configuration')
        return False

    try:
        # Hash PII
        user_data = {}
        if email:
            user_data['em'] = sha256(email)
        if phone:
            user_data['ph'] = sha256(phone.replace('-', '').replace(' ', ''))
        if first_name:
            user_data['fn'] = sha256(first_name)
        if last_name:
            user_data['ln'] = sha256(last_name)

        payload = {
            'data': [{
                'event_name': event_name,
                'event_time': event_time,
                'user_data': user_data,
                'custom_data': {
                    'value': value,
                    'currency': currency,
                    'order_id': order_id,
                    **(custom_data or {}),
                },
                'action_source': 'physical_store',  # or 'phone_call', 'email'
            }],
            'access_token': access_token,
        }

        url = f'https://graph.facebook.com/v21.0/{pixel_id}/events'
        response = requests.post(url, json=payload, timeout=10)
        result = response.json()

        if not response.ok:
            print('[Offline Conversions] API error:', result)
            return False

        print('[Offline Conversions] Event uploaded:', {
            'event_name': event_name,
            'events_received': result.get('events_received'),
            'fbtrace_id': result.get('fbtrace_id'),
        })

        return True

    except Exception as error:
        print('[Offline Conversions] Upload failed:', error)
        return False


def track_phone_order(
    email: str,
    customer_name: str,
    order_value: float,
    order_id: str,
    phone: Optional[str] = None,
    order_date: Optional[int] = None,
) -> None:
    """Track phone order conversion"""
    name_parts = customer_name.split(' ', 1)
    first_name = name_parts[0] if name_parts else None
    last_name = name_parts[1] if len(name_parts) > 1 else None

    upload_offline_conversion(
        event_name='Purchase',
        event_time=order_date or int(time.time()),
        email=email,
        phone=phone,
        first_name=first_name,
        last_name=last_name,
        value=order_value,
        currency='USD',
        order_id=order_id,
        custom_data={'source': 'phone_order'},
    )


def sync_crm_deal(
    email: str,
    deal_value: float,
    deal_id: str,
    closed_date: int,
    customer_name: Optional[str] = None,
) -> None:
    """Sync CRM closed deal to Meta"""
    name_parts = customer_name.split(' ', 1) if customer_name else []
    first_name = name_parts[0] if name_parts else None
    last_name = name_parts[1] if len(name_parts) > 1 else None

    upload_offline_conversion(
        event_name='Purchase',
        event_time=closed_date,
        email=email,
        first_name=first_name,
        last_name=last_name,
        value=deal_value,
        currency='USD',
        order_id=deal_id,
        custom_data={
            'source': 'crm',
            'deal_stage': 'closed_won',
        },
    )
