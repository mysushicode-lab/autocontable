"""
Automated scheduler for periodic invoice processing
"""
import os
from datetime import datetime
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.interval import IntervalTrigger
from dotenv import load_dotenv

from src.email_ingestion import EmailClient
from src.storage.models import Settings, Organization
from src.invoice_processor import InvoiceProcessor
from src.classifier import SupplierClassifier, CategoryClassifier
from src.storage.database import db
from src.storage.models import Invoice, InvoiceStatus, ProcessedFileHash
from src.reconciliation import ReconciliationEngine

# Load environment variables
load_dotenv(os.path.join(os.path.dirname(__file__), '../../.env'))

SCHEDULER_INTERVAL_MINUTES = int(os.getenv('SCHEDULER_INTERVAL_MINUTES', 5))


def get_imap_settings():
    """Read IMAP settings from database"""
    session = db.get_session()
    try:
        settings = session.query(Settings).filter(
            Settings.key.in_(['imap_server', 'imap_port', 'email_address', 'email_password', 'email_folder'])
        ).all()
        settings_dict = {s.key: s.value for s in settings}
        return {
            'server': settings_dict.get('imap_server', 'imap.gmail.com'),
            'port': int(settings_dict.get('imap_port', 993)),
            'email': settings_dict.get('email_address'),
            'password': settings_dict.get('email_password'),
            'folder': settings_dict.get('email_folder', 'INBOX')
        }
    finally:
        session.close()


def get_scheduler_settings():
    """Read scheduler settings from database"""
    session = db.get_session()
    try:
        settings = session.query(Settings).filter(
            Settings.key.in_(['scheduler_interval', 'auto_reconciliation'])
        ).all()
        settings_dict = {s.key: s.value for s in settings}
        interval_minutes = float(settings_dict.get('scheduler_interval', '0.166'))  # default 10 seconds
        auto_reconciliation = settings_dict.get('auto_reconciliation', 'true').lower() == 'true'
        return {
            'interval_seconds': int(interval_minutes * 60),
            'auto_reconciliation': auto_reconciliation
        }
    finally:
        session.close()


def get_organization_id():
    """Get the organization ID to use for scheduler operations"""
    session = db.get_session()
    try:
        # Try to get from settings first
        setting = session.query(Settings).filter(Settings.key == 'scheduler_organization_id').first()
        if setting and setting.value:
            return int(setting.value)
        # Fallback to first organization
        org = session.query(Organization).first()
        return org.id if org else 1
    finally:
        session.close()


class InvoiceScheduler:
    """Scheduler for automated invoice processing"""
    
    def __init__(self):
        self.scheduler = BackgroundScheduler()
        self.interval_minutes = SCHEDULER_INTERVAL_MINUTES
    
    def _is_already_processed(self, session, content_hash: str, organization_id: int) -> bool:
        """Check permanent hash registry — returns True if file was ever processed, even if invoice was later deleted."""
        if not content_hash:
            return False
        return session.query(ProcessedFileHash).filter(
            ProcessedFileHash.content_hash == content_hash,
            ProcessedFileHash.organization_id == organization_id
        ).first() is not None

    def _register_hash(self, session, content_hash: str, filename: str, organization_id: int):
        """Permanently register a file hash so it is never re-processed."""
        if not content_hash:
            return
        if not session.query(ProcessedFileHash).filter(
            ProcessedFileHash.content_hash == content_hash,
            ProcessedFileHash.organization_id == organization_id
        ).first():
            session.add(ProcessedFileHash(content_hash=content_hash, filename=filename, organization_id=organization_id))

    def _build_invoice(self, invoice_data: dict, organization_id: int) -> Invoice:
        extraction_confidence = invoice_data.get('extraction_confidence', 'low')
        
        # AI is fully responsible for invoice number extraction (from PDF or email subject)
        # If AI returns null, generate a fallback number
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
            status=InvoiceStatus.PROCESSED if extraction_confidence in {'high', 'medium'} else InvoiceStatus.PENDING
        )
    
    def process_new_invoices(self, since_date: datetime = None):
        """Fetch and process new invoices from email
        
        Args:
            since_date: Only fetch emails after this date (for initial startup fetch)
        """
        print(f"[{datetime.now()}] Starting invoice processing...")
        if since_date:
            print(f"[{datetime.now()}] Fetching emails since {since_date.strftime('%Y-%m-%d')}...")
        
        session = db.get_session()
        
        try:
            # Get organization ID
            organization_id = get_organization_id()
            print(f"[{datetime.now()}] Using organization_id: {organization_id}")
            
            # Fetch emails (with optional date filter for startup)
            imap_settings = get_imap_settings()
            email_client = EmailClient(**imap_settings)
            emails = email_client.fetch_invoices(mark_as_read=True, since_date=since_date)
            
            print(f"[{datetime.now()}] Found {len(emails)} invoice emails")
            
            # Initialize processors
            invoice_processor = InvoiceProcessor()
            supplier_classifier = SupplierClassifier(session)
            category_classifier = CategoryClassifier()
            
            processed_count = 0
            
            for email in emails:
                message_id = email.get('message_id', '')
                
                # Download attachments
                attachments = email_client.download_attachments(email, 'data/invoices')
                
                for idx, attachment_path in enumerate(attachments):
                    attachment = email['attachments'][idx] if idx < len(email['attachments']) else {}
                    content_hash = attachment.get('content_hash', '')
                    filename = attachment.get('filename', '')

                    if self._is_already_processed(session, content_hash, organization_id):
                        print(f"[{datetime.now()}] Skipping already-processed file: {filename} (hash: {content_hash[:8]}...)")
                        continue
                    
                    # Prepare email metadata for AI
                    email_metadata = {
                        'email_from': email['from'],
                        'email_subject': email['subject'],
                        'email_body': email.get('body', '')
                    }
                    
                    # Process invoice with AI (if enabled) and metadata
                    invoice_data = invoice_processor.process_invoice(
                        attachment_path,
                        email_metadata=email_metadata
                    )
                    
                    # Add email metadata
                    invoice_data['email_subject'] = email['subject']
                    invoice_data['email_from'] = email['from']
                    invoice_data['email_date'] = email['date']
                    invoice_data['file_path'] = attachment_path
                    invoice_data['message_id'] = message_id
                    invoice_data['content_hash'] = content_hash
                    
                    # Skip non-invoice documents identified by AI
                    if invoice_data.get('not_an_invoice'):
                        print(f"[{datetime.now()}] Skipping non-invoice document: {filename} (type: {invoice_data.get('ai_document_type', 'unknown')})")
                        continue
                    
                    supplier = supplier_classifier.detect_supplier(invoice_data)
                    if supplier:
                        invoice_data['supplier_id'] = supplier.id
                        # Also set organization_id on supplier
                        supplier.organization_id = organization_id
                    
                    # Classify category — AI provides directly; keyword classifier as fallback only
                    if not invoice_data.get('category'):
                        category = category_classifier.classify(invoice_data)
                        if category:
                            invoice_data['category'] = category

                    invoice = self._build_invoice(invoice_data, organization_id)
                    session.add(invoice)
                    self._register_hash(session, content_hash, filename, organization_id)
                    processed_count += 1
            
            session.commit()
            
            print(f"[{datetime.now()}] Processed {processed_count} new invoices")
            
        except Exception as e:
            print(f"[{datetime.now()}] Error processing invoices: {e}")
            session.rollback()
        finally:
            if 'email_client' in locals():
                email_client.disconnect()
            session.close()
    
    def run_reconciliation(self):
        """Run reconciliation on processed invoices"""
        print(f"[{datetime.now()}] Starting reconciliation...")
        
        session = db.get_session()
        
        try:
            engine = ReconciliationEngine(session)
            matches = engine.reconcile()
            
            print(f"[{datetime.now()}] Created {len(matches)} reconciliation matches")
            
        except Exception as e:
            print(f"[{datetime.now()}] Error during reconciliation: {e}")
        finally:
            session.close()
    
    def start(self):
        """Start the scheduler with initial current-month fetch"""
        print(f"[{datetime.now()}] === Starting Invoice Scheduler ===")

        # Read scheduler settings from DB
        sched_settings = get_scheduler_settings()
        interval_seconds = sched_settings['interval_seconds'] or 10  # fallback to 10 seconds
        auto_reconciliation = sched_settings['auto_reconciliation']
        print(f"[{datetime.now()}] Interval: {interval_seconds}s | Auto-reconciliation: {auto_reconciliation}")

        # STEP 1: Initial fetch - get emails from start of current month
        today = datetime.now()
        start_of_month = today.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        
        print(f"[{datetime.now()}] Step 1: Initial fetch - processing emails since {start_of_month.strftime('%Y-%m-%d')}...")
        try:
            self.process_new_invoices(since_date=start_of_month)
            print(f"[{datetime.now()}] Initial fetch completed.")
        except Exception as e:
            print(f"[{datetime.now()}] Error during initial fetch: {e}")
            print(f"[{datetime.now()}] Continuing with scheduler anyway...")
        
        # STEP 2: Schedule regular jobs
        print(f"[{datetime.now()}] Step 2: Setting up scheduled jobs...")
        
        # Schedule invoice processing
        self.scheduler.add_job(
            self.process_new_invoices,
            trigger=IntervalTrigger(seconds=interval_seconds),
            id='process_invoices',
            name='Process New Invoices',
            replace_existing=True,
            max_instances=1,
            misfire_grace_time=300
        )
        
        # Schedule reconciliation only if enabled
        if auto_reconciliation:
            self.scheduler.add_job(
                self.run_reconciliation,
                trigger=IntervalTrigger(seconds=interval_seconds * 2),
                id='run_reconciliation',
                name='Run Reconciliation',
                replace_existing=True,
                max_instances=1,
                misfire_grace_time=300
            )
        
        print(f"[{datetime.now()}] Scheduler ready. Running every {interval_seconds}s.")
        
        # STEP 3: Start scheduler (blocking)
        try:
            self.scheduler.start()
        except (KeyboardInterrupt, SystemExit):
            print(f"[{datetime.now()}] Scheduler stopped.")


def start_scheduler():
    """Start the invoice scheduler"""
    scheduler = InvoiceScheduler()
    scheduler.start()


if __name__ == "__main__":
    start_scheduler()
