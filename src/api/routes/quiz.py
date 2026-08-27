"""Quiz submission and email automation endpoints."""
from datetime import datetime
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.exc import IntegrityError
import logging
import os
import urllib.request
import json as _json
import hashlib
import time
import threading

from src.storage.database import db
from src.storage.models import QuizContact, EmailJob

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/quiz", tags=["quiz"])


def _add_to_sendgrid_list(email: str, first_name: str) -> None:
    """Add contact to SendGrid Marketing list (best-effort, runs in background thread)."""
    api_key = os.getenv('SENDGRID_API_KEY')
    if not api_key:
        return
    list_id = os.getenv('SENDGRID_MARKETING_LIST_ID')
    body = {'contacts': [{'email': email, 'first_name': first_name}]}
    if list_id:
        body['list_ids'] = [list_id]
    try:
        data = _json.dumps(body).encode()
        req = urllib.request.Request(
            'https://api.sendgrid.com/v3/marketing/contacts',
            data=data,
            headers={'Authorization': f'Bearer {api_key}', 'Content-Type': 'application/json'},
            method='PUT',
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            logger.info(f"[SG Marketing] Added {email} — status {resp.status}")
    except Exception as exc:
        logger.warning(f"[SG Marketing] Failed for {email}: {exc}")


def _send_to_meta_conversions_api(
    email: str,
    first_name: str,
    event_name: str = 'Lead',
    custom_data: dict = None,
    user_data_extra: dict = None
) -> bool:
    """
    Send Lead event to Meta Conversions API (server-side tracking).

    Advantages over client-side pixel:
    - Works even if client-side pixel is blocked by adblocker
    - Hashed PII ensures privacy compliance (GDPR/CCPA)
    - Server-verified data improves conversion quality
    - Can include backend context (server_id, phone, etc.)

    Args:
        email: Contact email
        first_name: Contact first name
        event_name: Facebook event name ('Lead', 'Purchase', etc.)
        custom_data: Additional event data (value, currency, etc.)
        user_data_extra: Additional user data (phone, address, etc.)

    Returns:
        bool: True if event sent successfully, False otherwise
    """
    pixel_id = os.getenv('FACEBOOK_PIXEL_ID')
    api_token = os.getenv('FACEBOOK_CONVERSIONS_API_TOKEN')

    if not pixel_id or not api_token:
        logger.debug('[Meta API] Conversions API not configured (FACEBOOK_PIXEL_ID or FACEBOOK_CONVERSIONS_API_TOKEN missing)')
        return False

    try:
        # Hash PII for privacy compliance (SHA-256)
        hashed_email = hashlib.sha256(email.lower().encode()).hexdigest()
        hashed_fn = hashlib.sha256(first_name.lower().encode()).hexdigest()

        user_data = {
            'em': hashed_email,
            'fn': hashed_fn,
        }

        # Merge additional user data if provided
        if user_data_extra:
            user_data.update(user_data_extra)

        # Build event payload
        event_payload = {
            'event_name': event_name,
            'event_time': int(time.time()),
            'user_data': user_data,
            'action_source': 'website',
            'event_source_url': os.getenv('FRONTEND_URL', 'http://localhost:3000') + '/quiz/email',
            'custom_data': custom_data or {
                'value': 0,
                'currency': 'EUR',
                'content_name': 'Quiz Lead',
                'content_type': 'lead',
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
            response_data = _json.loads(resp.read().decode())
            logger.info(f'[Meta Conversions API] {event_name} event sent for {email} — status {resp.status}')
            return True

    except Exception as exc:
        logger.warning(f'[Meta API] Failed to send {event_name} event for {email}: {exc}')
        return False


class QuizSubmitRequest(BaseModel):
    first_name: str
    email: str
    answers: dict


def get_profile_from_answers(answers: dict) -> str:
    """Map quiz answers to profile (cabinet_optimiseur, cabinet_croissance, etc)."""
    try:
        client_count = answers.get('client-count', {})
        time_spent = answers.get('time-spent', {})
        emotion = answers.get('emotion', {})

        clients = client_count.get('value')
        time = time_spent.get('value')
        mood = emotion.get('value')

        # Cabinet Optimiseur
        if clients == '<20' and time == '<10h' and mood == 'optimistic':
            return 'cabinet_optimiseur'

        # Cabinet en Crise
        if time == '>30h' or mood == 'burnout':
            return 'cabinet_crise'

        # Cabinet Débordé
        if (clients == '50-100' or clients == '>100') and (time == '20-30h' or mood == 'overwhelmed'):
            return 'cabinet_deborde'

        # Cabinet en Croissance (default)
        return 'cabinet_croissance'
    except Exception as e:
        logger.warning(f"Error mapping profile: {e}")
        return 'cabinet_croissance'


def calculate_time_lost(answers: dict) -> dict:
    """Calculate time lost from quiz answers."""
    try:
        time_spent = answers.get('time-spent', {})
        hours_week = time_spent.get('hoursWeek', 0)

        return {
            'week': hours_week,
            'month': hours_week * 4,
            'year': hours_week * 4 * 12
        }
    except Exception as e:
        logger.warning(f"Error calculating time lost: {e}")
        return {'week': 0, 'month': 0, 'year': 0}




@router.post("/submit")
def submit_quiz(body: QuizSubmitRequest):
    """Submit quiz answers and create email sequence."""
    session = db.get_session()
    try:
        first_name = body.first_name
        email = body.email
        answers = body.answers

        # Calculate profile and time lost
        profile = get_profile_from_answers(answers)
        time_lost = calculate_time_lost(answers)
        client_count = answers.get('client-count', {}).get('avgClients', 0)

        # Create or update QuizContact in our DB
        quiz_contact = session.query(QuizContact).filter_by(email=email).first()

        if quiz_contact:
            # Update existing
            quiz_contact.state = 'quiz_done_no_account'
            quiz_contact.first_name = first_name
            quiz_contact.client_count = client_count
            quiz_contact.time_lost_week = time_lost['week']
            quiz_contact.time_lost_month = time_lost['month']
            quiz_contact.time_lost_year = time_lost['year']
            quiz_contact.quiz_completed_at = datetime.utcnow()
        else:
            # Create new
            quiz_contact = QuizContact(
                email=email,
                first_name=first_name,
                state='quiz_done_no_account',
                client_count=client_count,
                time_lost_week=time_lost['week'],
                time_lost_month=time_lost['month'],
                time_lost_year=time_lost['year'],
                quiz_completed_at=datetime.utcnow()
            )
            session.add(quiz_contact)

        session.commit()
        session.refresh(quiz_contact)

        # Lifecycle: schedule quiz_lead email sequence
        from src.scheduler.lifecycle_engine import on_quiz_completed
        on_quiz_completed(session, quiz_contact_id=quiz_contact.id)

        session.commit()

        # Background tasks (async, non-blocking)
        def background_tasks():
            # Add to SendGrid Marketing list
            _add_to_sendgrid_list(email, first_name)

            # Send Lead event to Meta Conversions API (server-side tracking)
            _send_to_meta_conversions_api(
                email=email,
                first_name=first_name,
                event_name='Lead',
                custom_data={
                    'value': 0,
                    'currency': 'EUR',
                    'content_name': 'Quiz Lead',
                    'content_type': 'lead',
                    'profile_type': profile,
                    'time_lost_year': time_lost['year'],
                    'client_count': client_count,
                }
            )

        threading.Thread(target=background_tasks, daemon=True).start()

        logger.info(f"Quiz submitted for {email}, scheduled 4 emails + Meta Lead event")

        return {
            'success': True,
            'contact_id': quiz_contact.id,
            'profile': profile,
            'client_count': client_count,
            'time_lost_per_year': time_lost['year'],
            'message': 'Quiz submitted! Check your email.'
        }

    except IntegrityError:
        session.rollback()
        logger.warning(f"Contact {email} already exists")
        return {
            'success': True,
            'message': 'You already submitted the quiz! Check your email.'
        }
    except Exception as e:
        session.rollback()
        logger.error(f"Quiz submission error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        session.close()


@router.get("/jobs/pending")
def get_pending_jobs():
    """Get all pending email jobs (for debugging)."""
    session = db.get_session()
    try:
        jobs = session.query(EmailJob).filter(
        EmailJob.status == 'pending',
        EmailJob.scheduled_for <= datetime.utcnow()
    ).all()

        return {
            'total': len(jobs),
            'jobs': [
                {
                    'id': j.id,
                    'email': j.quiz_contact.email,
                    'type': j.email_type,
                    'scheduled_for': j.scheduled_for.isoformat()
                }
                for j in jobs
            ]
        }
    finally:
        session.close()
