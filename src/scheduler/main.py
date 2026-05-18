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
from dotenv import load_dotenv

from src.email_ingestion import EmailClient
from src.storage.models import Settings, Organization
from src.invoice_processor import InvoiceProcessor
from src.classifier import SupplierClassifier, CategoryClassifier
from src.storage.database import db
from src.storage.models import Invoice, InvoiceStatus, ProcessedFileHash, BankTransaction
from src.reconciliation import run_auto_reconciliation

# Load environment variables
load_dotenv(os.path.join(os.path.dirname(__file__), '../../.env'))

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
            vehicle_registration=invoice_data.get('vehicle_registration'),
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
            email_client = EmailClient(**imap_settings)
            emails = email_client.fetch_invoices(mark_as_read=True, since_date=since_date)
            logger.info(f"Org {organization_id}: found {len(emails)} invoice emails")

            invoice_processor = InvoiceProcessor()
            supplier_classifier = SupplierClassifier(session, org_id=organization_id)
            category_classifier = CategoryClassifier()

            for mail in emails:
                message_id = mail.get('message_id', '')
                attachments = email_client.download_attachments(mail, 'data/invoices')
                for idx, attachment_path in enumerate(attachments):
                    attachment = mail['attachments'][idx] if idx < len(mail['attachments']) else {}
                    content_hash = attachment.get('content_hash', '')
                    filename = attachment.get('filename', '')

                    if self._is_already_processed(session, content_hash, organization_id):
                        logger.info(f"Org {organization_id}: skipping already-processed {filename}")
                        continue

                    email_metadata = {
                        'email_from': mail['from'],
                        'email_subject': mail['subject'],
                        'email_body': mail.get('body', ''),
                    }
                    invoice_data = invoice_processor.process_invoice(
                        attachment_path, email_metadata=email_metadata,
                    )
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

        try:
            self.scheduler.start()  # BlockingScheduler — keeps the process alive
        except (KeyboardInterrupt, SystemExit):
            logger.info("Scheduler stopped.")


def start_scheduler():
    """Entrypoint used when running `python -m src.scheduler.main`."""
    InvoiceScheduler().start()


if __name__ == "__main__":
    start_scheduler()
