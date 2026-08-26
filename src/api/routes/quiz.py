"""Quiz submission and email automation endpoints."""
from datetime import datetime
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.exc import IntegrityError
import logging
import os
import urllib.request
import json as _json

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

        # Add to SendGrid Marketing list (async, non-blocking)
        import threading
        threading.Thread(
            target=_add_to_sendgrid_list,
            args=(email, first_name),
            daemon=True
        ).start()

        logger.info(f"Quiz submitted for {email}, scheduled 4 emails")

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
