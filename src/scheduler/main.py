"""
Automated scheduler for periodic invoice processing
"""
import os
from datetime import datetime
from apscheduler.schedulers.blocking import BlockingScheduler
from apscheduler.triggers.interval import IntervalTrigger
from dotenv import load_dotenv

from src.email_ingestion import EmailClient
from src.invoice_processor import InvoiceProcessor
from src.classifier import SupplierClassifier, CategoryClassifier
from src.storage.database import db
from src.storage.models import Invoice, InvoiceStatus
from src.reconciliation import ReconciliationEngine

# Load environment variables
load_dotenv(os.path.join(os.path.dirname(__file__), '../../config/.env'))

SCHEDULER_INTERVAL_MINUTES = int(os.getenv('SCHEDULER_INTERVAL_MINUTES', 5))


class InvoiceScheduler:
    """Scheduler for automated invoice processing"""
    
    def __init__(self):
        self.scheduler = BlockingScheduler()
        self.interval_minutes = SCHEDULER_INTERVAL_MINUTES
    
    def _find_existing_invoice(self, session, message_id: str, content_hash: str, subject: str):
        if content_hash:
            existing = session.query(Invoice).filter(
                Invoice.content_hash == content_hash
            ).first()
            if existing:
                return existing

        if message_id and subject:
            return session.query(Invoice).filter(
                Invoice.message_id == message_id,
                Invoice.email_subject == subject
            ).first()

        return None

    def _build_invoice(self, invoice_data: dict) -> Invoice:
        extraction_confidence = invoice_data.get('extraction_confidence', 'low')
        
        # AI is fully responsible for invoice number extraction (from PDF or email subject)
        # If AI returns null, generate a fallback number
        invoice_number = invoice_data.get('invoice_number') or f"INV-{datetime.now().timestamp()}"
        
        return Invoice(
            invoice_number=invoice_number,
            supplier_id=invoice_data.get('supplier_id'),
            amount=invoice_data.get('amount') or 0,
            amount_tax=invoice_data.get('amount_tax'),
            date=invoice_data.get('date') or datetime.now(),
            due_date=invoice_data.get('due_date'),
            category=invoice_data.get('category'),
            purchase_order=invoice_data.get('purchase_order'),
            delivery_note=invoice_data.get('delivery_note'),
            vehicle_registration=invoice_data.get('vehicle_registration'),
            work_order_reference=invoice_data.get('work_order_reference'),
            payment_method=invoice_data.get('payment_method'),
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
            # Fetch emails (with optional date filter for startup)
            email_client = EmailClient()
            emails = email_client.fetch_invoices(mark_as_read=False, since_date=since_date)
            
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
                    
                    existing = self._find_existing_invoice(
                        session,
                        message_id,
                        content_hash,
                        email['subject']
                    )
                    
                    if existing:
                        print(f"[{datetime.now()}] Skipping duplicate: {filename} (hash: {content_hash[:8]}...)")
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
                    
                    # Classify category
                    category = category_classifier.classify(invoice_data)
                    if category:
                        invoice_data['category'] = category

                    invoice = self._build_invoice(invoice_data)
                    
                    session.add(invoice)
                    processed_count += 1
            
            session.commit()
            
            # Mark emails as read
            if processed_count > 0:
                email_client.fetch_invoices(mark_as_read=True)
            
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
        
        # STEP 1: Initial fetch - get emails from start of current month
        # This ensures recent invoices are processed immediately on startup
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
        
        # Schedule invoice processing (without since_date - will get recent emails)
        self.scheduler.add_job(
            self.process_new_invoices,
            trigger=IntervalTrigger(minutes=self.interval_minutes),
            id='process_invoices',
            name='Process New Invoices',
            replace_existing=True,
            max_instances=1,
            misfire_grace_time=300
        )
        
        # Schedule reconciliation
        self.scheduler.add_job(
            self.run_reconciliation,
            trigger=IntervalTrigger(minutes=self.interval_minutes * 2),
            id='run_reconciliation',
            name='Run Reconciliation',
            replace_existing=True,
            max_instances=1,
            misfire_grace_time=300
        )
        
        print(f"[{datetime.now()}] Scheduler ready. Running every {self.interval_minutes} minutes.")
        print(f"[{datetime.now()}] Press Ctrl+C to stop.")
        
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
