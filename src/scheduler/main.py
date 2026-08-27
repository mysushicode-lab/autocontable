"""
Automated multi-tenant scheduler for periodic invoice processing.

Runs as a standalone process (BlockingScheduler) and iterates over every
organisation that has IMAP credentials configured. Designed to be deployed
as a dedicated container alongside the API.
"""
import os
import logging
from datetime import datetime
from typing import List, Optional

from apscheduler.schedulers.blocking import BlockingScheduler
from apscheduler.triggers.interval import IntervalTrigger

import src.config  # noqa: F401

from src.email_ingestion import IMAPClient
from src.scheduler.email_sender import process_pending_emails
from src.scheduler.lifecycle_engine import check_trial_lifecycle, check_abandoned_accounts
from src.scheduler.sequenceScheduler import run_sequence_scheduler
from src.storage.models import Settings, Organization, ClientFile
from src.invoice_processor import InvoiceProcessor
from src.classifier import SupplierClassifier, CategoryClassifier
from src.storage.database import db
from src.storage.models import Invoice, InvoiceStatus, ProcessedFileHash, BankTransaction
from src.reconciliation import run_auto_reconciliation
from src.utils.quota import can_process_invoice, increment_invoice_count
import calendar

# Default global cadence (seconds) when an org doesn't override via settings
DEFAULT_INTERVAL_SECONDS = int(os.getenv('SCHEDULER_DEFAULT_INTERVAL', 480))

logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s %(name)s: %(message)s')
logger = logging.getLogger(__name__)


def _settings_dict(session, organization_id: int, keys: List[str]) -> dict:
    """Return settings as a dict for the given organisation, filtered by keys."""
    rows = session.query(Settings).filter(
        Settings.organization_id == organization_id,
        Settings.key.in_(keys),
    ).all()
    return {s.key: s.value for s in rows}


def get_imap_settings(organization_id: int) -> Optional[dict]:
    """Read IMAP credentials for a given organisation. Returns None if not configured."""
    session = db.get_session()
    try:
        d = _settings_dict(session, organization_id, [
            'imap_server', 'imap_port', 'email_address', 'email_password', 'email_folder',
        ])
        email_address = d.get('email_address')
        password = d.get('email_password')
        if not email_address or not password:
            return None
        try:
            port = int(d.get('imap_port') or 993)
        except (TypeError, ValueError):
            port = 993
        return {
            'server': d.get('imap_server', 'imap.gmail.com'),
            'port': port,
            'email': email_address,
            'password': password,
            'folder': d.get('email_folder', 'INBOX'),
        }
    finally:
        session.close()


def get_org_scheduler_settings(organization_id: int) -> dict:
    """Read scheduler options (interval / auto-reconciliation) for an organisation."""
    session = db.get_session()
    try:
        d = _settings_dict(session, organization_id, ['scheduler_interval', 'auto_reconciliation'])
        try:
            interval_minutes = float(d.get('scheduler_interval', '8'))
        except (TypeError, ValueError):
            interval_minutes = 8.0
        return {
            'interval_seconds': max(60, int(interval_minutes * 60)),
            'auto_reconciliation': (d.get('auto_reconciliation', 'true').lower() == 'true'),
        }
    finally:
        session.close()


def list_active_organizations() -> List[int]:
    """Return ids of organisations that have IMAP credentials configured."""
    session = db.get_session()
    try:
        orgs = session.query(Organization).all()
        active = []
        for org in orgs:
            d = _settings_dict(session, org.id, ['email_address', 'email_password'])
            if d.get('email_address') and d.get('email_password'):
                active.append(org.id)
        return active
    finally:
        session.close()


class InvoiceScheduler:
    """Multi-tenant scheduler. One periodic job iterates over all configured orgs."""

    def __init__(self):
        self.scheduler = BlockingScheduler(timezone='UTC')

    # ------------------------------------------------------------------
    # Per-org processing
    # ------------------------------------------------------------------
    def _is_already_processed(self, session, content_hash: str, organization_id: int) -> bool:
        if not content_hash:
            return False
        return session.query(ProcessedFileHash).filter(
            ProcessedFileHash.content_hash == content_hash,
            ProcessedFileHash.organization_id == organization_id,
        ).first() is not None

    def _register_hash(self, session, content_hash: str, filename: str, organization_id: int):
        if not content_hash:
            return
        exists = session.query(ProcessedFileHash).filter(
            ProcessedFileHash.content_hash == content_hash,
            ProcessedFileHash.organization_id == organization_id,
        ).first()
        if not exists:
            session.add(ProcessedFileHash(
                content_hash=content_hash,
                filename=filename,
                organization_id=organization_id,
            ))

    def _match_client_by_email(self, session, organization_id: int, email_from: str) -> Optional[int]:
        """Match sender email to a client dossier. Returns client_file_id or None."""
        if not email_from:
            return None
        # Extract email address from "Name <email@domain.com>" format
        import re
        match = re.search(r'[\w.+-]+@[\w-]+\.[\w.-]+', email_from)
        if not match:
            return None
        sender_email = match.group(0).lower()

        # Find client file with matching contact_email
        cf = session.query(ClientFile).filter(
            ClientFile.organization_id == organization_id,
            ClientFile.is_active == True,
        ).all()
        for client_file in cf:
            if client_file.contact_email and client_file.contact_email.lower() == sender_email:
                return client_file.id
        return None

    def _build_invoice(self, invoice_data: dict, organization_id: int) -> Invoice:
        extraction_confidence = invoice_data.get('extraction_confidence', 'low')
        invoice_number = invoice_data.get('invoice_number') or f"INV-{datetime.now().timestamp()}"
        return Invoice(
            invoice_number=invoice_number,
            supplier_id=invoice_data.get('supplier_id'),
            amount=invoice_data.get('amount') or 0,
            amount_ht=invoice_data.get('amount_ht'),
            amount_tax=invoice_data.get('amount_tax'),
            date=invoice_data.get('date') or datetime.now(),
            due_date=invoice_data.get('due_date'),
            category=invoice_data.get('category'),
            purchase_order=invoice_data.get('purchase_order'),
            delivery_note=invoice_data.get('delivery_note'),
            reference_number=invoice_data.get('reference_number'),
            work_order_reference=invoice_data.get('work_order_reference'),
            payment_method=invoice_data.get('payment_method'),
            organization_id=organization_id,
            file_path=invoice_data.get('file_path'),
            email_subject=invoice_data.get('email_subject'),
            email_from=invoice_data.get('email_from'),
            email_date=invoice_data.get('email_date'),
            message_id=invoice_data.get('message_id'),
            content_hash=invoice_data.get('content_hash'),
            status=InvoiceStatus.PROCESSED if extraction_confidence in {'high', 'medium'} else InvoiceStatus.PENDING,
        )

    def process_org_invoices(self, organization_id: int, since_date: Optional[datetime] = None) -> int:
        """Fetch and process new invoices for a single organisation.

        Returns the number of invoices created.
        """
        imap_settings = get_imap_settings(organization_id)
        if not imap_settings:
            logger.debug(f"Org {organization_id}: no IMAP configured, skipping")
            return 0

        logger.info(f"Org {organization_id}: starting invoice processing")
        if since_date:
            logger.info(f"Org {organization_id}: fetching emails since {since_date.strftime('%Y-%m-%d')}")

        session = db.get_session()
        email_client = None
        processed_count = 0
        try:
            email_client = IMAPClient(**imap_settings)
            emails = email_client.fetch_emails(
                folder=imap_settings.get('folder', 'INBOX'),
                search_subject='facture',
                since_date=since_date,
                mark_as_read=True
            )
            logger.info(f"Org {organization_id}: found {len(emails)} invoice emails")

            # Get org for quota check
            org = session.query(Organization).filter(Organization.id == organization_id).first()
            if not org:
                logger.warning(f"Org {organization_id}: not found in database")
                return

            invoice_processor = InvoiceProcessor()
            supplier_classifier = SupplierClassifier(session, org_id=organization_id)
            category_classifier = CategoryClassifier()

            for mail in emails:
                message_id = mail.get('message_id', '')
                from src.utils.paths import INVOICES_DIR
                attachments = email_client.download_attachments(mail, INVOICES_DIR)
                for idx, attachment_path in enumerate(attachments):
                    attachment = mail['attachments'][idx] if idx < len(mail['attachments']) else {}
                    content_hash = attachment.get('content_hash', '')
                    filename = attachment.get('filename', '')

                    if self._is_already_processed(session, content_hash, organization_id):
                        logger.info(f"Org {organization_id}: skipping already-processed {filename}")
                        continue

                    # Check quota before processing
                    can_process, error_msg = can_process_invoice(org, session)
                    if not can_process:
                        logger.warning(f"Org {organization_id}: {error_msg} - skipping remaining invoices")
                        break  # Stop processing for this org

                    email_metadata = {
                        'email_from': mail['from'],
                        'email_subject': mail['subject'],
                        'email_body': mail.get('body', ''),
                    }
                    invoice_data = invoice_processor.process_invoice(
                        attachment_path, email_metadata=email_metadata,
                    )

                    # Increment quota counter ONLY if AI was actually used (not Factur-X/OCR)
                    if invoice_data.get('ai_used') is True:
                        increment_invoice_count(org, session)
                    invoice_data.update({
                        'email_subject': mail['subject'],
                        'email_from': mail['from'],
                        'email_date': mail['date'],
                        'file_path': attachment_path,
                        'message_id': message_id,
                        'content_hash': content_hash,
                    })

                    if invoice_data.get('not_an_invoice'):
                        logger.info(f"Org {organization_id}: skipping non-invoice document {filename}")
                        continue

                    extraction_confidence = invoice_data.get('extraction_confidence', 'low')
                    if extraction_confidence == 'low' or invoice_data.get('is_invoice') is None:
                        logger.info(f"Org {organization_id}: skipping low-confidence extraction {filename}")
                        continue

                    supplier = supplier_classifier.detect_supplier(invoice_data)
                    if supplier:
                        invoice_data['supplier_id'] = supplier.id
                        supplier.organization_id = organization_id

                    if not invoice_data.get('category'):
                        category = category_classifier.classify(invoice_data)
                        if category:
                            invoice_data['category'] = category

                    invoice = self._build_invoice(invoice_data, organization_id)

                    # Auto-route to client dossier based on sender email
                    client_file_id = self._match_client_by_email(session, organization_id, mail.get('from', ''))
                    if client_file_id:
                        invoice.client_file_id = client_file_id

                    session.add(invoice)
                    self._register_hash(session, content_hash, filename, organization_id)
                    processed_count += 1

            session.commit()
            logger.info(f"Org {organization_id}: processed {processed_count} new invoices")
        except Exception as exc:
            logger.exception(f"Org {organization_id}: error processing invoices: {exc}")
            session.rollback()
        finally:
            if email_client is not None:
                try:
                    email_client.disconnect()
                except Exception:
                    pass
            session.close()
        return processed_count

    # ------------------------------------------------------------------
    # Auto-push accounting entries (scheduled)
    # ------------------------------------------------------------------
    def auto_push_entries(self):
        """Auto-push accounting entries to configured integrations at end of month."""
        from src.integrations import get_integration
        from src.api.integrations import _get_integration_config, _build_entries

        session = db.get_session()
        try:
            now = datetime.utcnow()
            # Only run on the last 2 days of the month or first day of next month
            last_day = calendar.monthrange(now.year, now.month)[1]
            if now.day < last_day - 1 and now.day != 1:
                return

            # Determine which month to push (previous month if we're on day 1)
            if now.day <= 2:
                if now.month == 1:
                    push_year, push_month = now.year - 1, 12
                else:
                    push_year, push_month = now.year, now.month - 1
            else:
                push_year, push_month = now.year, now.month

            # Iterate all orgs
            orgs = session.query(Organization).all()
            for org in orgs:
                # Find all client files with integrations configured
                client_files = session.query(ClientFile).filter(
                    ClientFile.organization_id == org.id,
                    ClientFile.is_active == True
                ).all()

                for cf in client_files:
                    config = _get_integration_config(session, org.id, cf.id)
                    if not config or not config.get("integration_name"):
                        continue

                    # Check if auto_push is enabled for this dossier
                    auto_push_enabled = config.get("auto_push", False)
                    if not auto_push_enabled:
                        continue

                    integration = get_integration(config["integration_name"], config)
                    if not integration:
                        continue

                    # Build and push entries
                    entries = _build_entries(session, org.id, cf.id, push_year, push_month)
                    if entries:
                        result = integration.push_entries(entries)
                        logger.info(f"[auto-push] {cf.name} ({config['integration_name']}): {result.entries_pushed} entries, success={result.success}")
        except Exception as e:
            logger.error(f"[auto-push] Error: {e}")
        finally:
            session.close()

    # ------------------------------------------------------------------
    # Tick: iterate over every configured org
    # ------------------------------------------------------------------
    def tick(self):
        """Single scheduler tick: iterate over every configured organisation."""
        org_ids = list_active_organizations()
        if not org_ids:
            logger.debug("No organisation has IMAP configured; nothing to do")
            return

        for org_id in org_ids:
            try:
                created = self.process_org_invoices(org_id)
                # If anything was created, also try to reconcile when enabled
                opts = get_org_scheduler_settings(org_id)
                if created and opts.get('auto_reconciliation'):
                    matches = run_auto_reconciliation(org_id)
                    if matches:
                        logger.info(f"Org {org_id}: auto-reconciliation created {matches} matches")
            except Exception as exc:
                logger.exception(f"Org {org_id}: tick failed: {exc}")

    # ------------------------------------------------------------------
    # Lifecycle
    # ------------------------------------------------------------------
    def start(self):
        logger.info("=== Starting multi-tenant Invoice Scheduler ===")

        # Initial fetch: emails since the start of the current month
        today = datetime.utcnow()
        start_of_month = today.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        try:
            org_ids = list_active_organizations()
            logger.info(f"Initial fetch for {len(org_ids)} organisation(s) since {start_of_month.strftime('%Y-%m-%d')}")
            for org_id in org_ids:
                try:
                    self.process_org_invoices(org_id, since_date=start_of_month)
                    opts = get_org_scheduler_settings(org_id)
                    if opts.get('auto_reconciliation'):
                        run_auto_reconciliation(org_id)
                except Exception as exc:
                    logger.exception(f"Org {org_id}: initial fetch failed: {exc}")
        except Exception as exc:
            logger.exception(f"Initial fetch failed: {exc}")

        # Recurring tick
        interval = DEFAULT_INTERVAL_SECONDS
        logger.info(f"Scheduling recurring tick every {interval}s")
        self.scheduler.add_job(
            self.tick,
            trigger=IntervalTrigger(seconds=interval),
            id='multi_tenant_tick',
            name='Multi-tenant invoice fetch',
            replace_existing=True,
            max_instances=1,
            misfire_grace_time=300,
        )

        # Auto-push job (check twice a day)
        logger.info("Scheduling auto-push job (12h interval)")
        self.scheduler.add_job(
            self.auto_push_entries,
            trigger=IntervalTrigger(hours=12),
            id='auto_push_entries',
            name='Auto-push accounting entries',
            replace_existing=True,
            max_instances=1,
            misfire_grace_time=3600,
        )

        # Email sender job (check every minute for pending emails)
        logger.info("Scheduling email sender job (1m interval)")
        self.scheduler.add_job(
            process_pending_emails,
            trigger=IntervalTrigger(minutes=1),
            id='email_sender',
            name='Send pending lifecycle emails',
            replace_existing=True,
            max_instances=1,
            misfire_grace_time=60,
        )

        # Trial lifecycle checker (every hour: detect trial_ending + trial_expired)
        logger.info("Scheduling trial lifecycle checker (1h interval)")
        self.scheduler.add_job(
            check_trial_lifecycle,
            trigger=IntervalTrigger(hours=1),
            id='trial_lifecycle',
            name='Check trial expiry and trigger emails',
            replace_existing=True,
            max_instances=1,
            misfire_grace_time=3600,
        )

        # Abandoned accounts checker (every 24 hours: detect signups with zero usage)
        logger.info("Scheduling abandoned accounts checker (24h interval)")
        self.scheduler.add_job(
            check_abandoned_accounts,
            trigger=IntervalTrigger(hours=24),
            id='abandoned_accounts',
            name='Detect abandoned accounts for retargeting',
            replace_existing=True,
            max_instances=1,
            misfire_grace_time=3600,
        )

        # Deep sequence scheduler (every 30 minutes)
        logger.info("Scheduling deep sequence scheduler (30m interval)")
        self.scheduler.add_job(
            run_sequence_scheduler,
            trigger=IntervalTrigger(minutes=30),
            id='sequence_scheduler',
            name='Email Sequence Scheduler',
            replace_existing=True,
            max_instances=1,
            misfire_grace_time=120,
        )

        # Monthly usage report — fire on 1st of each month at 8:00 UTC
        from apscheduler.triggers.cron import CronTrigger
        logger.info("Scheduling monthly usage report (1st of month, 8:00 UTC)")
        self.scheduler.add_job(
            _send_monthly_reports,
            trigger=CronTrigger(day=1, hour=8, minute=0),
            id='monthly_reports',
            name='Monthly usage report emails',
            replace_existing=True,
            max_instances=1,
            misfire_grace_time=3600,
        )

        try:
            self.scheduler.start()  # BlockingScheduler — keeps the process alive
        except (KeyboardInterrupt, SystemExit):
            logger.info("Scheduler stopped.")


def _send_monthly_reports():
    """Fire monthly_usage_report email to all active paying orgs."""
    from src.scheduler.lifecycle_engine import on_monthly_report
    from src.storage.models import Organization
    session = db.get_session()
    try:
        paying_orgs = session.query(Organization).filter(
            Organization.plan_type.in_(['starter', 'pro', 'reseau']),
            Organization.stripe_subscription_id.isnot(None),
        ).all()
        for org in paying_orgs:
            try:
                on_monthly_report(session, organization_id=org.id)
            except Exception as e:
                logger.error(f"[monthly_report] org {org.id}: {e}")
        session.commit()
        logger.info(f"[monthly_report] Queued reports for {len(paying_orgs)} orgs")
    except Exception as e:
        logger.error(f"[monthly_report] Fatal: {e}")
        session.rollback()
    finally:
        session.close()


def start_scheduler():
    """Entrypoint used when running `python -m src.scheduler.main`."""
    InvoiceScheduler().start()


if __name__ == "__main__":
    start_scheduler()
