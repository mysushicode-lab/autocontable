"""Email sender worker - sends scheduled lifecycle emails via SendGrid."""
import os
import logging
from datetime import datetime
from sendgrid import SendGridAPIClient
from sendgrid.helpers.mail import Mail, To

from src.storage.database import SessionLocal
from src.storage.models import EmailJob, QuizContact, Organization, User

logger = logging.getLogger(__name__)

SENDGRID_API_KEY = os.getenv("SENDGRID_API_KEY")
SENDGRID_FROM_EMAIL = os.getenv("SENDGRID_FROM_EMAIL", "contact@factpilot.fr")
FRONTEND_URL = os.getenv("FRONTEND_URL", "http://localhost:3000")


def get_template(email_type: str) -> dict:
    """Get email template by type. Checks lifecycle templates first, falls back to legacy."""
    from src.scheduler.lifecycle_templates import LIFECYCLE_TEMPLATES
    return LIFECYCLE_TEMPLATES.get(email_type)


def get_recipient_info(db, job: EmailJob) -> dict:
    """Resolve recipient email, name, and context variables for a job."""
    info = {
        'email': None,
        'first_name': 'there',
        'client_count': 0,
        'time_lost_week': 0,
        'time_lost_month': 0,
        'time_lost_year': 0,
        'plan_name': 'Starter',
        'days_left': 0,
        'invoices_count': 0,
        'matches_count': 0,
        'time_saved': 0,
    }

    if job.quiz_contact_id:
        contact = db.query(QuizContact).filter_by(id=job.quiz_contact_id).first()
        if contact:
            info['email'] = contact.email
            info['first_name'] = contact.first_name or 'there'
            info['client_count'] = contact.client_count or 0
            info['time_lost_week'] = contact.time_lost_week or 0
            info['time_lost_month'] = contact.time_lost_month or 0
            info['time_lost_year'] = contact.time_lost_year or 0

    if job.user_id:
        user = db.query(User).filter_by(id=job.user_id).first()
        if user:
            info['email'] = user.email
            info['first_name'] = user.name or info['first_name']

    if job.organization_id:
        org = db.query(Organization).filter_by(id=job.organization_id).first()
        if org:
            info['plan_name'] = (org.plan_type or 'starter').capitalize()
            if org.trial_end_date:
                days_left = (org.trial_end_date - datetime.utcnow()).days
                info['days_left'] = max(0, days_left)
            info['invoices_count'] = org.invoices_processed_this_month or 0

    if not info['email'] and job.user_id:
        user = db.query(User).filter_by(id=job.user_id).first()
        if user:
            info['email'] = user.email

    return info


# Must match billing.py PRICING_TIERS and quota.py PLAN_QUOTAS
PLAN_PRICES = {'free': 0, 'starter': 49, 'pro': 149, 'reseau': 0}
PLAN_QUOTAS = {'free': 80, 'starter': 400, 'pro': 1500, 'reseau': 99999}
MONTHS_FR = ['janvier','février','mars','avril','mai','juin',
             'juillet','août','septembre','octobre','novembre','décembre']


def personalize_content(content: str, info: dict) -> str:
    """Replace all [[placeholder]] variables in content."""
    from datetime import timedelta
    annual_loss = int((info.get('time_lost_year', 0)) * 50)
    deletion_date = (datetime.utcnow() + timedelta(days=23)).strftime("%d/%m/%Y")
    plan_key = str(info.get('plan_name', 'starter')).lower()
    plan_price = PLAN_PRICES.get(plan_key, 29)
    quota_limit = PLAN_QUOTAS.get(plan_key, 500)
    quota_used = info.get('invoices_count', 0)
    quota_percent = int(quota_used / quota_limit * 100) if quota_limit > 0 else 0
    now = datetime.utcnow()
    report_month = MONTHS_FR[now.month - 1] + ' ' + str(now.year)

    replacements = {
        '[[email]]': str(info.get('email', '')),
        '[[firstName]]': str(info.get('first_name', 'there')),
        '[[client_count]]': str(info.get('client_count', 0)),
        '[[time_lost_week]]': str(info.get('time_lost_week', 0)),
        '[[time_lost_month]]': str(info.get('time_lost_month', 0)),
        '[[time_lost_year]]': str(info.get('time_lost_year', 0)),
        '[[annual_loss]]': str(annual_loss),
        '[[plan_name]]': str(info.get('plan_name', 'Starter')),
        '[[plan_price]]': str(plan_price),
        '[[days_left]]': str(info.get('days_left', 0)),
        '[[invoices_count]]': str(info.get('invoices_count', 0)),
        '[[matches_count]]': str(info.get('matches_count', 0)),
        '[[time_saved]]': str(info.get('time_saved', 0)),
        '[[quota_used]]': str(quota_used),
        '[[quota_limit]]': str(quota_limit),
        '[[quota_percent]]': str(quota_percent),
        '[[report_month]]': report_month,
        '[[deletion_date]]': deletion_date,
        '[[signup_url]]': f"{FRONTEND_URL}/auth/register",
        '[[app_url]]': f"{FRONTEND_URL}/dashboard",
        '[[upgrade_url]]': f"{FRONTEND_URL}/settings/billing",
    }

    result = content
    for placeholder, value in replacements.items():
        result = result.replace(placeholder, value)
    return result


def _record_sent_event(email: str, email_type: str):
    """Record a 'sent' EmailEvent for engagement tracking (best-effort, non-blocking)."""
    try:
        from src.storage.models import EmailEvent, User, QuizContact
        session = SessionLocal()
        try:
            user    = session.query(User).filter(User.email == email).first()
            contact = session.query(QuizContact).filter(QuizContact.email == email).first()
            ev = EmailEvent(
                organization_id=user.organization_id if user else None,
                user_id=user.id if user else None,
                quiz_contact_id=contact.id if contact else None,
                email_type=email_type,
                event='sent',
            )
            session.add(ev)
            session.commit()
        finally:
            session.close()
    except Exception as e:
        logger.debug(f"[EmailSender] _record_sent_event failed silently: {e}")


def send_lifecycle_email(email: str, first_name: str, email_type: str, info: dict) -> bool:
    """Send a lifecycle email via SendGrid."""
    try:
        if not SENDGRID_API_KEY:
            logger.warning("SendGrid API key not configured")
            return False

        template = get_template(email_type)
        if not template:
            logger.error(f"No template found for email type: {email_type}")
            return False

        subject = personalize_content(template['subject'], info)
        html_content = personalize_content(template['html'], info)

        message = Mail(
            from_email=SENDGRID_FROM_EMAIL,
            to_emails=To(email=email, name=first_name),
            subject=subject,
            html_content=html_content
        )

        sg = SendGridAPIClient(SENDGRID_API_KEY)
        response = sg.send(message)

        if response.status_code in [200, 201, 202]:
            logger.info(f"[EMAIL SENT] {email_type} → {email} (status {response.status_code})")
            _record_sent_event(email, email_type)
            return True
        else:
            logger.error(f"[EMAIL FAILED] {email_type} → {email} (status {response.status_code})")
            return False

    except Exception as e:
        logger.error(f"Error sending {email_type} to {email}: {e}")
        return False


def process_pending_emails():
    """Process all pending email jobs that are due."""
    db = SessionLocal()

    try:
        now = datetime.utcnow()

        pending_jobs = db.query(EmailJob).filter(
            EmailJob.status == 'pending',
            EmailJob.scheduled_for <= now
        ).all()

        if not pending_jobs:
            return

        logger.info(f"Processing {len(pending_jobs)} pending emails")

        for job in pending_jobs:
            try:
                info = get_recipient_info(db, job)

                if not info['email']:
                    job.status = 'failed'
                    job.error_message = 'No recipient email found'
                    continue

                # Skip if quiz contact has already created an account (for quiz_lead emails only)
                if job.quiz_contact_id and job.email_type.startswith('quiz_'):
                    contact = db.query(QuizContact).filter_by(id=job.quiz_contact_id).first()
                    if contact and contact.state == 'account_created':
                        job.status = 'cancelled'
                        job.error_message = 'Account created - quiz emails cancelled'
                        continue

                success = send_lifecycle_email(
                    email=info['email'],
                    first_name=info['first_name'],
                    email_type=job.email_type,
                    info=info
                )

                if success:
                    job.status = 'sent'
                    job.sent_at = datetime.utcnow()
                else:
                    job.status = 'failed'
                    job.error_message = 'SendGrid delivery error'

            except Exception as e:
                job.status = 'failed'
                job.error_message = str(e)[:500]
                logger.error(f"Error processing job {job.id}: {e}")

        db.commit()
        logger.info("Email processing complete")

    except Exception as e:
        logger.error(f"Fatal error in email processor: {e}")
        db.rollback()
    finally:
        db.close()


if __name__ == '__main__':
    process_pending_emails()
