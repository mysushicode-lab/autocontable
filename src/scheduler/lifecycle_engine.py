"""Lifecycle engine — manages email sequences and stage transitions.

Sequences follow SaaS Marketing Playbook principles:
- Quiz leads: diagnostic → témoignage → intégration → breakup (always CTA to signup)
- Trial Day 0: welcome + premier pas
- Trial Active: product tips → case study → offer help (Encharge/Dan Martel framework)
- Trial Ending: urgency → last chance
- Trial Expired: access suspended → special offer → final
- Paying: confirmation → advanced onboarding → review
- Churned: cancel confirm → feedback request → win-back
"""
import logging
from datetime import datetime, timedelta
from sqlalchemy.orm import Session

from src.storage.models import (
    EmailJob, QuizContact, Organization, User, LifecycleStage
)
from src.storage.database import SessionLocal

logger = logging.getLogger(__name__)


# ─── Sequence definitions ────────────────────────────────────────────────────
# Each sequence is a list of (email_type, delay_from_stage_entry)

SEQUENCES = {
    LifecycleStage.QUIZ_LEAD: [
        ('quiz_diagnostic', timedelta(minutes=0)),
        ('quiz_marie', timedelta(days=1)),
        ('quiz_integration', timedelta(days=3)),
        ('quiz_breakup', timedelta(days=7)),
    ],
    LifecycleStage.TRIAL_DAY0: [
        ('trial_welcome', timedelta(minutes=0)),
    ],
    LifecycleStage.TRIAL_ACTIVE: [
        ('trial_tip_1', timedelta(days=1)),
        ('trial_tip_2', timedelta(days=3)),
        ('trial_case_study', timedelta(days=5)),
        ('trial_offer_help', timedelta(days=6)),
    ],
    LifecycleStage.TRIAL_ENDING: [
        ('trial_urgency', timedelta(minutes=0)),
        ('trial_last_chance', timedelta(days=1)),
    ],
    LifecycleStage.TRIAL_EXPIRED: [
        ('expired_access_suspended', timedelta(minutes=0)),
        ('expired_special_offer', timedelta(days=3)),
        ('expired_final', timedelta(days=7)),
    ],
    LifecycleStage.PAYING: [
        ('paying_confirmation', timedelta(minutes=0)),
        ('paying_onboarding', timedelta(days=7)),
        ('paying_review', timedelta(days=30)),
    ],
    LifecycleStage.CHURNED: [
        ('churned_confirmation', timedelta(minutes=0)),
        ('churned_feedback', timedelta(days=3)),
        ('churned_winback', timedelta(days=14)),
    ],
}


def cancel_pending_emails(db: Session, *, quiz_contact_id: int = None,
                          organization_id: int = None, user_id: int = None):
    """Cancel all pending emails for a contact/org/user."""
    query = db.query(EmailJob).filter(EmailJob.status == 'pending')
    if quiz_contact_id:
        query = query.filter(EmailJob.quiz_contact_id == quiz_contact_id)
    if organization_id:
        query = query.filter(EmailJob.organization_id == organization_id)
    if user_id:
        query = query.filter(EmailJob.user_id == user_id)

    count = query.update({'status': 'cancelled', 'error_message': 'Stage transition'})
    logger.info(f"Cancelled {count} pending emails (quiz={quiz_contact_id}, org={organization_id}, user={user_id})")
    return count


def schedule_sequence(db: Session, stage: LifecycleStage, *,
                      quiz_contact_id: int = None,
                      organization_id: int = None,
                      user_id: int = None):
    """Schedule the email sequence for a lifecycle stage."""
    sequence = SEQUENCES.get(stage, [])
    if not sequence:
        return

    now = datetime.utcnow()
    for email_type, delay in sequence:
        job = EmailJob(
            quiz_contact_id=quiz_contact_id,
            organization_id=organization_id,
            user_id=user_id,
            lifecycle_stage=stage,
            email_type=email_type,
            scheduled_for=now + delay,
            status='pending'
        )
        db.add(job)

    logger.info(f"Scheduled {len(sequence)} emails for stage {stage.value} "
                f"(quiz={quiz_contact_id}, org={organization_id}, user={user_id})")


def transition_to_stage(db: Session, new_stage: LifecycleStage, *,
                        quiz_contact_id: int = None,
                        organization_id: int = None,
                        user_id: int = None):
    """Transition a contact/user to a new lifecycle stage.

    1. Cancel all pending emails from previous stage
    2. Update lifecycle_stage on QuizContact (if applicable)
    3. Schedule new sequence
    """
    cancel_pending_emails(db, quiz_contact_id=quiz_contact_id,
                          organization_id=organization_id, user_id=user_id)

    if quiz_contact_id:
        contact = db.query(QuizContact).filter_by(id=quiz_contact_id).first()
        if contact:
            contact.lifecycle_stage = new_stage
            contact.updated_at = datetime.utcnow()

    schedule_sequence(db, new_stage,
                      quiz_contact_id=quiz_contact_id,
                      organization_id=organization_id,
                      user_id=user_id)

    logger.info(f"Transitioned to {new_stage.value}")


# ─── Trigger functions (called by auth, payments, scheduler) ─────────────────

def on_quiz_completed(db: Session, quiz_contact_id: int):
    """Called when quiz is submitted. Starts quiz_lead sequence."""
    transition_to_stage(db, LifecycleStage.QUIZ_LEAD, quiz_contact_id=quiz_contact_id)


def on_account_created(db: Session, user_id: int, organization_id: int, email: str):
    """Called when user creates an account (signup).

    - Links QuizContact if exists → cancel quiz emails
    - Starts trial_day0 + trial_active sequences
    """
    # Link QuizContact if this email took the quiz
    contact = db.query(QuizContact).filter_by(email=email).first()
    quiz_contact_id = None
    if contact:
        contact.state = 'account_created'
        contact.account_created_at = datetime.utcnow()
        contact.lifecycle_stage = LifecycleStage.TRIAL_DAY0
        quiz_contact_id = contact.id
        cancel_pending_emails(db, quiz_contact_id=contact.id)

    # Schedule welcome email (immediate)
    schedule_sequence(db, LifecycleStage.TRIAL_DAY0,
                      organization_id=organization_id,
                      user_id=user_id,
                      quiz_contact_id=quiz_contact_id)

    # Schedule trial_active sequence (starts J+1)
    schedule_sequence(db, LifecycleStage.TRIAL_ACTIVE,
                      organization_id=organization_id,
                      user_id=user_id,
                      quiz_contact_id=quiz_contact_id)


def on_trial_ending(db: Session, organization_id: int):
    """Called by scheduler when trial has 2 days left."""
    users = db.query(User).filter_by(organization_id=organization_id).all()
    for user in users:
        if user.email:
            cancel_pending_emails(db, organization_id=organization_id, user_id=user.id)
            schedule_sequence(db, LifecycleStage.TRIAL_ENDING,
                              organization_id=organization_id,
                              user_id=user.id)

    # Update QuizContact lifecycle if linked
    contact = None
    for user in users:
        if user.email:
            contact = db.query(QuizContact).filter_by(email=user.email).first()
            if contact:
                contact.lifecycle_stage = LifecycleStage.TRIAL_ENDING
                break


def on_trial_expired(db: Session, organization_id: int):
    """Called by scheduler when trial has expired."""
    users = db.query(User).filter_by(organization_id=organization_id).all()
    for user in users:
        if user.email:
            cancel_pending_emails(db, organization_id=organization_id, user_id=user.id)
            schedule_sequence(db, LifecycleStage.TRIAL_EXPIRED,
                              organization_id=organization_id,
                              user_id=user.id)

    for user in users:
        if user.email:
            contact = db.query(QuizContact).filter_by(email=user.email).first()
            if contact:
                contact.lifecycle_stage = LifecycleStage.TRIAL_EXPIRED
                break


def on_payment_confirmed(db: Session, organization_id: int):
    """Called by Stripe webhook when subscription is created/activated."""
    users = db.query(User).filter_by(organization_id=organization_id).all()
    for user in users:
        if user.email:
            cancel_pending_emails(db, organization_id=organization_id, user_id=user.id)
            schedule_sequence(db, LifecycleStage.PAYING,
                              organization_id=organization_id,
                              user_id=user.id)

    for user in users:
        if user.email:
            contact = db.query(QuizContact).filter_by(email=user.email).first()
            if contact:
                contact.lifecycle_stage = LifecycleStage.PAYING
                break


def on_subscription_cancelled(db: Session, organization_id: int):
    """Called by Stripe webhook when subscription is deleted."""
    users = db.query(User).filter_by(organization_id=organization_id).all()
    for user in users:
        if user.email:
            cancel_pending_emails(db, organization_id=organization_id, user_id=user.id)
            schedule_sequence(db, LifecycleStage.CHURNED,
                              organization_id=organization_id,
                              user_id=user.id)

    for user in users:
        if user.email:
            contact = db.query(QuizContact).filter_by(email=user.email).first()
            if contact:
                contact.lifecycle_stage = LifecycleStage.CHURNED
                break


# ─── Scheduler job: detect trial_ending and trial_expired ────────────────────

def check_trial_lifecycle():
    """Run every hour by scheduler. Detects orgs approaching trial end or expired."""
    db = SessionLocal()
    try:
        now = datetime.utcnow()
        two_days = timedelta(days=2)

        # Find orgs where trial ends in ≤ 2 days and still active
        ending_soon = db.query(Organization).filter(
            Organization.is_trial_active == True,
            Organization.trial_end_date != None,
            Organization.trial_end_date <= now + two_days,
            Organization.trial_end_date > now,
            Organization.stripe_subscription_id == None,
        ).all()

        for org in ending_soon:
            # Check if we already sent trial_ending emails
            existing = db.query(EmailJob).filter(
                EmailJob.organization_id == org.id,
                EmailJob.lifecycle_stage == LifecycleStage.TRIAL_ENDING,
            ).first()
            if not existing:
                logger.info(f"Trial ending soon for org {org.id} ({org.name})")
                on_trial_ending(db, org.id)

        # Find orgs where trial has expired
        expired = db.query(Organization).filter(
            Organization.is_trial_active == True,
            Organization.trial_end_date != None,
            Organization.trial_end_date <= now,
            Organization.stripe_subscription_id == None,
        ).all()

        for org in expired:
            existing = db.query(EmailJob).filter(
                EmailJob.organization_id == org.id,
                EmailJob.lifecycle_stage == LifecycleStage.TRIAL_EXPIRED,
            ).first()
            if not existing:
                logger.info(f"Trial expired for org {org.id} ({org.name})")
                on_trial_expired(db, org.id)

        db.commit()
    except Exception as e:
        logger.error(f"Error in trial lifecycle check: {e}")
        db.rollback()
    finally:
        db.close()
