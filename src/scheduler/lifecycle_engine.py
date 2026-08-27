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
import threading
from datetime import datetime, timedelta
from sqlalchemy.orm import Session

from src.storage.models import (
    EmailJob, QuizContact, Organization, User, LifecycleStage
)
from src.storage.database import SessionLocal
from src.scheduler.analytics_tracking import track_trial_ending_soon, track_account_abandoned

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
        ('paying_confirmation',           timedelta(minutes=0)),
        ('paying_onboarding',             timedelta(days=7)),
        ('educational_best_practices',    timedelta(days=14)),
        ('paying_review',                 timedelta(days=30)),
        ('educational_advanced_features', timedelta(days=45)),
        ('referral_program_intro',        timedelta(days=50)),
        ('review_request',                timedelta(days=60)),
        ('quarterly_check_in',            timedelta(days=90)),
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
    - Sends trial_welcome immediately (not via queue)
    - Starts trial_active sequence via scheduler
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

    # Send trial_welcome immediately — bypass the queue
    try:
        from src.scheduler.email_sender import send_lifecycle_email
        user = db.query(User).filter_by(id=user_id).first()
        org = db.query(Organization).filter_by(id=organization_id).first()
        first_name = (user.name if user else None) or 'there'
        info = {
            'email': email,
            'first_name': first_name,
            'client_count': 0,
            'time_lost_week': 0,
            'time_lost_month': 0,
            'time_lost_year': 0,
            'plan_name': (org.plan_type or 'starter').capitalize() if org else 'Starter',
            'days_left': max(0, (org.trial_end_date - datetime.utcnow()).days) if org and org.trial_end_date else 0,
            'invoices_count': 0,
            'matches_count': 0,
            'time_saved': 0,
        }
        send_lifecycle_email(email=email, first_name=first_name, email_type='trial_welcome', info=info)
    except Exception as e:
        logger.error(f"Failed to send immediate trial_welcome to {email}: {e}")

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

            # Track trial ending soon in Meta Ads (urgency signal for retargeting)
            try:
                import threading
                threading.Thread(
                    target=track_trial_ending_soon,
                    args=(user.email, user.name, 3),
                    daemon=True
                ).start()
            except Exception as e:
                logger.warning(f"Failed to track trial_ending_soon for {user.email}: {e}")

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


# ─── Event triggers: payment, quota, monthly report ─────────────────────────

def on_payment_failed(db: Session, organization_id: int, attempt: int = 1):
    """Called by Stripe webhook on invoice.payment_failed. attempt = 1|2|3."""
    email_type_map = {1: 'payment_failed_1', 2: 'payment_failed_2', 3: 'payment_failed_3'}
    email_type = email_type_map.get(attempt, 'payment_failed_1')
    users = db.query(User).filter_by(organization_id=organization_id).all()
    for user in users:
        if user.email:
            from src.scheduler.email_sender import send_lifecycle_email
            info = _build_org_info(db, organization_id, user)
            send_lifecycle_email(email=user.email, first_name=user.name or '', email_type=email_type, info=info)


def on_quota_reached_80(db: Session, organization_id: int):
    """Called when org hits 80% of monthly invoice quota."""
    users = db.query(User).filter_by(organization_id=organization_id).all()
    for user in users:
        if user.email:
            existing = db.query(EmailJob).filter(
                EmailJob.organization_id == organization_id,
                EmailJob.email_type == 'quota_80_percent',
                EmailJob.status.in_(['pending', 'sent']),
            ).first()
            if not existing:
                job = EmailJob(
                    organization_id=organization_id,
                    user_id=user.id,
                    lifecycle_stage=LifecycleStage.PAYING,
                    email_type='quota_80_percent',
                    scheduled_for=datetime.utcnow(),
                    status='pending'
                )
                db.add(job)


def on_monthly_report(db: Session, organization_id: int):
    """Call once a month (e.g., 1st of each month) for active paying orgs."""
    users = db.query(User).filter_by(organization_id=organization_id).all()
    for user in users:
        if user.email:
            job = EmailJob(
                organization_id=organization_id,
                user_id=user.id,
                lifecycle_stage=LifecycleStage.PAYING,
                email_type='monthly_usage_report',
                scheduled_for=datetime.utcnow(),
                status='pending'
            )
            db.add(job)


def on_low_engagement(db: Session, organization_id: int, is_paying: bool = False):
    """Called when a paying org shows no activity for 14+ days."""
    email_type = 'paying_low_engagement_check_in' if is_paying else 'low_engagement_re_spark'
    users = db.query(User).filter_by(organization_id=organization_id).all()
    for user in users:
        if user.email:
            existing = db.query(EmailJob).filter(
                EmailJob.organization_id == organization_id,
                EmailJob.email_type == email_type,
                EmailJob.status.in_(['pending', 'sent']),
            ).first()
            if not existing:
                job = EmailJob(
                    organization_id=organization_id,
                    user_id=user.id,
                    lifecycle_stage=LifecycleStage.PAYING,
                    email_type=email_type,
                    scheduled_for=datetime.utcnow(),
                    status='pending'
                )
                db.add(job)


def _build_org_info(db: Session, organization_id: int, user) -> dict:
    """Build info dict for a user/org — used by event-triggered sends."""
    org = db.query(Organization).filter_by(id=organization_id).first()
    return {
        'email': user.email,
        'first_name': user.name or '',
        'client_count': 0,
        'time_lost_week': 0,
        'time_lost_month': 0,
        'time_lost_year': 0,
        'plan_name': (org.plan_type or 'starter').capitalize() if org else 'Starter',
        'days_left': 0,
        'invoices_count': org.invoices_processed_this_month if org else 0,
        'matches_count': 0,
        'time_saved': 0,
    }


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


def check_abandoned_accounts():
    """Run daily: detect users who signed up but never imported an invoice."""
    db = SessionLocal()
    try:
        now = datetime.utcnow()
        one_day_ago = now - timedelta(days=1)

        # Find users created 1+ days ago with active trial and ZERO invoices
        from src.storage.models import Invoice
        from sqlalchemy import func

        abandoned_users = db.query(User).filter(
            User.created_at < one_day_ago,
            User.organization_id != None
        ).all()

        for user in abandoned_users:
            org = db.query(Organization).filter(Organization.id == user.organization_id).first()
            if not org:
                continue

            # Check if they have any invoices imported
            invoice_count = db.query(func.count(Invoice.id)).filter(
                Invoice.organization_id == org.id
            ).scalar()

            if invoice_count == 0 and org.is_trial_active:
                # Track account abandoned in Meta Ads
                try:
                    days_since = (now - user.created_at).days
                    import threading
                    threading.Thread(
                        target=track_account_abandoned,
                        args=(user.email, user.name, days_since),
                        daemon=True
                    ).start()
                except Exception as e:
                    logger.warning(f"Failed to track abandoned account for {user.email}: {e}")

        db.commit()
    except Exception as e:
        logger.error(f"Error checking abandoned accounts: {e}")
        db.rollback()
    finally:
        db.close()
