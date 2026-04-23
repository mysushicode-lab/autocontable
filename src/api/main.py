"""
FastAPI REST API for invoice processing system
"""
from fastapi import FastAPI, HTTPException, Query, UploadFile, File
from fastapi.responses import FileResponse
from datetime import datetime, timedelta
from typing import List, Optional
from sqlalchemy.orm import Session
from sqlalchemy import or_
from pydantic import BaseModel
from src.storage.database import db
from src.storage.models import Invoice, BankTransaction, ReconciliationMatch, InvoiceStatus, Base
from src.reporting.report_generator import ReportGenerator
from src.reporting.exporter import Exporter
from src.invoice_processor import InvoiceProcessor
from src.classifier import SupplierClassifier, CategoryClassifier
from src.bank_importer.bank_importer import BankImporter
from src.reconciliation.reconciliation_engine import ReconciliationEngine
import os
import calendar
import json
import shutil

app = FastAPI(title="Invoice Processing API", version="1.0.0")


@app.on_event("startup")
def startup_event():
    """Create database tables on startup"""
    Base.metadata.create_all(bind=db.engine)

UPLOAD_ROOT = os.path.join("data", "uploads")
INVOICE_UPLOAD_DIR = os.path.join(UPLOAD_ROOT, "invoices")
BANK_UPLOAD_DIR = os.path.join(UPLOAD_ROOT, "bank_statements")


class ManualLinkPayload(BaseModel):
    invoice_id: int
    transaction_id: int
    notes: Optional[str] = None


def _ensure_directory(path: str) -> None:
    os.makedirs(path, exist_ok=True)


def _save_uploaded_file(upload: UploadFile, target_dir: str) -> str:
    _ensure_directory(target_dir)
    timestamp = datetime.utcnow().strftime("%Y%m%d%H%M%S%f")
    filename = f"{timestamp}_{os.path.basename(upload.filename)}"
    output_path = os.path.join(target_dir, filename)
    with open(output_path, "wb") as buffer:
        shutil.copyfileobj(upload.file, buffer)
    return output_path


def _build_invoice_number(file_path: str) -> str:
    basename = os.path.splitext(os.path.basename(file_path))[0]
    return f"MANUAL-{basename[:40]}-{datetime.utcnow().strftime('%Y%m%d%H%M%S')}"


def _serialize_match(match: ReconciliationMatch) -> dict:
    return {
        "id": match.id,
        "score": round((match.match_score or 0) * 100, 2),
        "status": match.status,
        "match_type": match.match_type,
        "invoice": {
            "id": match.invoice.id,
            "number": match.invoice.invoice_number,
            "supplier": match.invoice.supplier.name if match.invoice.supplier else None,
            "amount": match.invoice.amount,
            "date": match.invoice.date.isoformat() if match.invoice.date else None,
            "vehicle": match.invoice.vehicle_registration,
        },
        "transaction": {
            "db_id": match.transaction.id,
            "id": match.transaction.transaction_id,
            "amount": match.transaction.amount,
            "date": match.transaction.date.isoformat() if match.transaction.date else None,
            "description": match.transaction.description,
        },
    }


def _create_or_update_invoice(session: Session, file_path: str, extracted_data: dict) -> Invoice:
    supplier_classifier = SupplierClassifier(session)
    category_classifier = CategoryClassifier()
    supplier = supplier_classifier.detect_supplier(extracted_data)
    invoice_number = extracted_data.get("invoice_number") or _build_invoice_number(file_path)
    extraction_confidence = extracted_data.get("extraction_confidence", "low")

    invoice = session.query(Invoice).filter(Invoice.invoice_number == invoice_number).first()
    if invoice is None:
        invoice = Invoice(invoice_number=invoice_number)
        session.add(invoice)

    invoice.supplier_id = supplier.id if supplier else None
    invoice.amount = extracted_data.get("amount") or 0.0
    invoice.amount_tax = extracted_data.get("amount_tax")
    invoice.date = extracted_data.get("date") or datetime.utcnow()
    invoice.due_date = extracted_data.get("due_date")
    invoice.category = category_classifier.classify(extracted_data)
    invoice.status = InvoiceStatus.PROCESSED if extraction_confidence in {"high", "medium"} else InvoiceStatus.PENDING
    invoice.purchase_order = extracted_data.get("purchase_order")
    invoice.delivery_note = extracted_data.get("delivery_note")
    invoice.vehicle_registration = extracted_data.get("vehicle_registration")
    invoice.work_order_reference = extracted_data.get("work_order_reference")
    invoice.payment_method = extracted_data.get("payment_method")
    invoice.file_path = file_path
    invoice.email_subject = extracted_data.get("email_subject") or "Import manuel"
    invoice.email_from = extracted_data.get("email_from")
    invoice.email_date = extracted_data.get("email_date")
    invoice.extracted_data = json.dumps(extracted_data, default=str)

    session.commit()
    session.refresh(invoice)
    return invoice


def get_db():
    """Get database session"""
    session = db.get_session()
    try:
        yield session
    finally:
        session.close()


@app.post("/api/invoices/upload")
async def upload_invoice(file: UploadFile = File(...)):
    """Import a supplier invoice manually."""
    allowed_extensions = {".pdf", ".png", ".jpg", ".jpeg", ".tiff", ".bmp"}
    extension = os.path.splitext(file.filename or "")[1].lower()
    if extension not in allowed_extensions:
        raise HTTPException(status_code=400, detail="Unsupported invoice file format")

    saved_path = _save_uploaded_file(file, INVOICE_UPLOAD_DIR)
    session = db.get_session()
    try:
        processor = InvoiceProcessor()
        extracted_data = processor.process_invoice(saved_path)
        invoice = _create_or_update_invoice(session, saved_path, extracted_data)
        return {
            "message": "Invoice imported successfully",
            "invoice": {
                "id": invoice.id,
                "invoice_number": invoice.invoice_number,
                "amount": invoice.amount,
                "status": invoice.status.value if invoice.status else None,
                "supplier": invoice.supplier.name if invoice.supplier else None,
            }
        }
    except Exception as exc:
        session.rollback()
        raise HTTPException(status_code=400, detail=str(exc))
    finally:
        session.close()


@app.post("/api/transactions/import")
async def import_bank_statement(file: UploadFile = File(...)):
    """Import a bank statement from CSV/OFX/QFX."""
    allowed_extensions = {".csv", ".ofx", ".qfx"}
    extension = os.path.splitext(file.filename or "")[1].lower()
    if extension not in allowed_extensions:
        raise HTTPException(status_code=400, detail="Unsupported bank statement format")

    saved_path = _save_uploaded_file(file, BANK_UPLOAD_DIR)
    session = db.get_session()
    try:
        importer = BankImporter()
        transactions = importer.import_file(saved_path)
        imported_count = 0

        for tx in transactions:
            transaction_id = tx.get("reference") or tx.get("transaction_id")
            if not transaction_id:
                continue

            existing_transaction = session.query(BankTransaction).filter(
                BankTransaction.transaction_id == transaction_id
            ).first()
            if existing_transaction:
                continue

            session.add(BankTransaction(
                transaction_id=transaction_id,
                date=tx.get("date") or datetime.utcnow(),
                amount=tx.get("amount") or 0.0,
                description=tx.get("description") or "",
                reference=tx.get("reference"),
                account_number=tx.get("account_number"),
                category=tx.get("category"),
                source_file=saved_path,
            ))
            imported_count += 1

        session.commit()
        return {
            "message": "Bank statement imported successfully",
            "imported_count": imported_count,
            "file_path": saved_path,
        }
    except Exception as exc:
        session.rollback()
        raise HTTPException(status_code=400, detail=str(exc))
    finally:
        session.close()


@app.post("/api/reconciliation/run")
def run_reconciliation(month: Optional[int] = None, year: Optional[int] = None):
    """Run reconciliation automatically on current invoices and transactions."""
    session = db.get_session()
    try:
        invoice_query = session.query(Invoice).filter(
            Invoice.status.in_([InvoiceStatus.PROCESSED, InvoiceStatus.UNMATCHED])
        )
        transaction_query = session.query(BankTransaction)

        if month and year:
            last_day_num = calendar.monthrange(year, month)[1]
            first_day = datetime(year, month, 1)
            last_day = datetime(year, month, last_day_num, 23, 59, 59)
            invoice_query = invoice_query.filter(Invoice.date >= first_day, Invoice.date <= last_day)
            transaction_query = transaction_query.filter(BankTransaction.date >= first_day, BankTransaction.date <= last_day)

        engine = ReconciliationEngine(session)
        matches = engine.reconcile(invoice_query.all(), transaction_query.all())
        serialized_matches = [_serialize_match(match) for match in matches]
        return {
            "message": "Reconciliation completed",
            "matches_created": len(matches),
            "matches": serialized_matches,
        }
    except Exception as exc:
        session.rollback()
        raise HTTPException(status_code=400, detail=str(exc))
    finally:
        session.close()


@app.post("/api/reconciliation/{match_id}/confirm")
def confirm_match(match_id: int):
    """Confirm a proposed reconciliation match."""
    session = db.get_session()
    try:
        match = session.query(ReconciliationMatch).filter(ReconciliationMatch.id == match_id).first()
        if not match:
            raise HTTPException(status_code=404, detail="Match not found")

        match.status = "confirmed"
        match.matched_by = "user"
        match.invoice.status = InvoiceStatus.MATCHED
        session.commit()
        session.refresh(match)
        return {"message": "Match confirmed", "match": _serialize_match(match)}
    finally:
        session.close()


@app.post("/api/reconciliation/{match_id}/reject")
def reject_match(match_id: int):
    """Reject a proposed reconciliation match."""
    session = db.get_session()
    try:
        match = session.query(ReconciliationMatch).filter(ReconciliationMatch.id == match_id).first()
        if not match:
            raise HTTPException(status_code=404, detail="Match not found")

        match.status = "rejected"
        match.matched_by = "user"
        match.invoice.status = InvoiceStatus.UNMATCHED
        session.commit()
        session.refresh(match)
        return {"message": "Match rejected", "match": _serialize_match(match)}
    finally:
        session.close()


@app.post("/api/reconciliation/manual-link")
def create_manual_link(payload: ManualLinkPayload):
    """Create a manual invoice to bank transaction link."""
    session = db.get_session()
    try:
        invoice = session.query(Invoice).filter(Invoice.id == payload.invoice_id).first()
        transaction = session.query(BankTransaction).filter(BankTransaction.id == payload.transaction_id).first()

        if not invoice:
            raise HTTPException(status_code=404, detail="Invoice not found")
        if not transaction:
            raise HTTPException(status_code=404, detail="Bank transaction not found")

        transaction_already_linked = session.query(ReconciliationMatch).filter(
            ReconciliationMatch.transaction_id == transaction.id,
            ReconciliationMatch.invoice_id != invoice.id,
            ReconciliationMatch.status != "rejected",
        ).first()
        if transaction_already_linked:
            raise HTTPException(status_code=400, detail="Bank transaction is already linked to another invoice")

        existing_match = session.query(ReconciliationMatch).filter(
            ReconciliationMatch.invoice_id == invoice.id,
            ReconciliationMatch.transaction_id == transaction.id,
        ).first()
        if existing_match:
            existing_match.status = "confirmed"
            existing_match.match_type = "manual"
            existing_match.notes = payload.notes
            existing_match.matched_by = "user"
            invoice.status = InvoiceStatus.MATCHED
            session.commit()
            session.refresh(existing_match)
            return {"message": "Manual link updated", "match": _serialize_match(existing_match)}

        manual_match = ReconciliationMatch(
            invoice_id=invoice.id,
            transaction_id=transaction.id,
            match_score=1.0,
            match_type="manual",
            status="confirmed",
            notes=payload.notes,
            matched_by="user",
        )
        session.add(manual_match)
        invoice.status = InvoiceStatus.MATCHED
        session.commit()
        session.refresh(manual_match)
        return {"message": "Manual link created", "match": _serialize_match(manual_match)}
    finally:
        session.close()


@app.get("/api/reconciliation/details")
def get_reconciliation_details(
    month: Optional[int] = None,
    year: Optional[int] = None
):
    """Get detailed reconciliation payload for the UI."""
    session = db.get_session()
    try:
        invoice_query = session.query(Invoice)
        match_query = session.query(ReconciliationMatch).join(Invoice)
        transaction_query = session.query(BankTransaction)

        if month and year:
            last_day_num = calendar.monthrange(year, month)[1]
            first_day = datetime(year, month, 1)
            last_day = datetime(year, month, last_day_num, 23, 59, 59)
            invoice_query = invoice_query.filter(Invoice.date >= first_day, Invoice.date <= last_day)
            match_query = match_query.filter(Invoice.date >= first_day, Invoice.date <= last_day)
            transaction_query = transaction_query.filter(BankTransaction.date >= first_day, BankTransaction.date <= last_day)

        matches = match_query.all()
        matched_transaction_ids = {match.transaction_id for match in matches}
        unmatched_invoices = invoice_query.filter(Invoice.status == InvoiceStatus.UNMATCHED).all()
        bank_only_transactions = transaction_query.filter(
            ~BankTransaction.id.in_(matched_transaction_ids) if matched_transaction_ids else True
        ).all()

        return {
            "matches": [
                {
                    "id": match.id,
                    "score": round((match.match_score or 0) * 100, 2),
                    "status": match.status,
                    "invoice": {
                        "id": match.invoice.id,
                        "number": match.invoice.invoice_number,
                        "supplier": match.invoice.supplier.name if match.invoice.supplier else None,
                        "amount": match.invoice.amount,
                        "date": match.invoice.date.isoformat() if match.invoice.date else None,
                        "vehicle": match.invoice.vehicle_registration
                    },
                    "transaction": {
                        "id": match.transaction.transaction_id,
                        "amount": match.transaction.amount,
                        "date": match.transaction.date.isoformat() if match.transaction.date else None,
                        "description": match.transaction.description
                    }
                }
                for match in matches
            ],
            "unmatched_invoices": [
                {
                    "id": invoice.id,
                    "invoice": {
                        "number": invoice.invoice_number,
                        "supplier": invoice.supplier.name if invoice.supplier else None,
                        "amount": invoice.amount,
                        "date": invoice.date.isoformat() if invoice.date else None
                    },
                    "vehicle": invoice.vehicle_registration
                }
                for invoice in unmatched_invoices
            ],
            "bank_only": [
                {
                    "db_id": tx.id,
                    "id": tx.transaction_id,
                    "amount": tx.amount,
                    "date": tx.date.isoformat() if tx.date else None,
                    "description": tx.description
                }
                for tx in bank_only_transactions
            ]
        }
    finally:
        session.close()


@app.get("/api/vehicles/{registration}/history")
def get_vehicle_history(registration: str):
    """Get invoice history aggregated by vehicle registration."""
    session = db.get_session()
    try:
        normalized_registration = registration.upper()
        invoices = session.query(Invoice).filter(
            Invoice.vehicle_registration == normalized_registration
        ).order_by(Invoice.date.desc()).all()

        if not invoices:
            raise HTTPException(status_code=404, detail="Vehicle history not found")

        total_spent = sum(invoice.amount or 0 for invoice in invoices)
        categories = {}
        history = []
        for invoice in invoices:
            category = invoice.category or "Non catégorisé"
            categories.setdefault(category, {"count": 0, "amount": 0})
            categories[category]["count"] += 1
            categories[category]["amount"] += invoice.amount or 0
            history.append({
                "date": invoice.date.isoformat() if invoice.date else None,
                "description": invoice.category or "Facture fournisseur",
                "amount": invoice.amount,
                "category": category,
                "invoice_number": invoice.invoice_number,
                "supplier": invoice.supplier.name if invoice.supplier else None,
                "work_order_reference": invoice.work_order_reference
            })

        return {
            "registration": normalized_registration,
            "total_spent": total_spent,
            "intervention_count": len(invoices),
            "last_visit": invoices[0].date.isoformat() if invoices[0].date else None,
            "history": history,
            "categories": categories
        }
    finally:
        session.close()


@app.get("/")
def root():
    """Root endpoint"""
    return {
        "message": "Invoice Processing & Bank Reconciliation API",
        "version": "1.0.0"
    }


@app.get("/api/invoices")
def list_invoices(
    status: Optional[str] = None,
    category: Optional[str] = None,
    search: Optional[str] = None,
    vehicle_registration: Optional[str] = None,
    month: Optional[int] = None,
    year: Optional[int] = None
):
    """List all invoices with optional filters"""
    session = db.get_session()
    try:
        query = session.query(Invoice)
        
        if status:
            query = query.filter(Invoice.status == InvoiceStatus(status))

        if category:
            query = query.filter(Invoice.category == category)

        if vehicle_registration:
            query = query.filter(Invoice.vehicle_registration == vehicle_registration.upper())

        if search:
            pattern = f"%{search}%"
            query = query.filter(
                or_(
                    Invoice.invoice_number.ilike(pattern),
                    Invoice.vehicle_registration.ilike(pattern),
                    Invoice.work_order_reference.ilike(pattern),
                    Invoice.email_subject.ilike(pattern)
                )
            )
        
        if month and year:
            last_day_num = calendar.monthrange(year, month)[1]
            first_day = datetime(year, month, 1)
            last_day = datetime(year, month, last_day_num, 23, 59, 59)
            query = query.filter(Invoice.date >= first_day, Invoice.date <= last_day)
        
        invoices = query.all()
        
        return {
            "count": len(invoices),
            "invoices": [
                {
                    "id": inv.id,
                    "invoice_number": inv.invoice_number,
                    "supplier": inv.supplier.name if inv.supplier else None,
                    "amount": inv.amount,
                    "date": inv.date.isoformat() if inv.date else None,
                    "category": inv.category,
                    "status": inv.status.value if inv.status else None,
                    "purchase_order": inv.purchase_order,
                    "delivery_note": inv.delivery_note,
                    "vehicle_registration": inv.vehicle_registration,
                    "work_order_reference": inv.work_order_reference,
                    "payment_method": inv.payment_method
                }
                for inv in invoices
            ]
        }
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid invoice status")
    finally:
        session.close()


@app.get("/api/invoices/{invoice_id}")
def get_invoice(invoice_id: int):
    """Get single invoice by ID"""
    session = db.get_session()
    try:
        invoice = session.query(Invoice).filter(Invoice.id == invoice_id).first()
        
        if not invoice:
            raise HTTPException(status_code=404, detail="Invoice not found")
        
        return {
            "id": invoice.id,
            "invoice_number": invoice.invoice_number,
            "supplier": invoice.supplier.name if invoice.supplier else None,
            "amount": invoice.amount,
            "amount_tax": invoice.amount_tax,
            "date": invoice.date.isoformat() if invoice.date else None,
            "due_date": invoice.due_date.isoformat() if invoice.due_date else None,
            "category": invoice.category,
            "status": invoice.status.value if invoice.status else None,
            "purchase_order": invoice.purchase_order,
            "delivery_note": invoice.delivery_note,
            "vehicle_registration": invoice.vehicle_registration,
            "work_order_reference": invoice.work_order_reference,
            "payment_method": invoice.payment_method,
            "file_path": invoice.file_path,
            "email_subject": invoice.email_subject,
            "email_from": invoice.email_from
        }
    finally:
        session.close()


@app.get("/api/invoices/{invoice_id}/download")
def download_invoice_pdf(invoice_id: int):
    """Download invoice PDF file"""
    session = db.get_session()
    try:
        invoice = session.query(Invoice).filter(Invoice.id == invoice_id).first()
        if not invoice:
            raise HTTPException(status_code=404, detail="Invoice not found")
        
        if not invoice.file_path or not os.path.exists(invoice.file_path):
            raise HTTPException(status_code=404, detail="PDF file not found")
        
        return FileResponse(
            invoice.file_path,
            media_type="application/pdf",
            filename=os.path.basename(invoice.file_path)
        )
    finally:
        session.close()


@app.get("/api/transactions")
def list_transactions(
    month: Optional[int] = None,
    year: Optional[int] = None
):
    """List all bank transactions"""
    session = db.get_session()
    try:
        query = session.query(BankTransaction)
        
        if month and year:
            last_day_num = calendar.monthrange(year, month)[1]
            first_day = datetime(year, month, 1)
            last_day = datetime(year, month, last_day_num, 23, 59, 59)
            query = query.filter(BankTransaction.date >= first_day, BankTransaction.date <= last_day)
        
        transactions = query.all()
        
        return {
            "count": len(transactions),
            "transactions": [
                {
                    "id": tx.id,
                    "transaction_id": tx.transaction_id,
                    "date": tx.date.isoformat() if tx.date else None,
                    "amount": tx.amount,
                    "description": tx.description,
                    "reference": tx.reference,
                    "category": tx.category
                }
                for tx in transactions
            ]
        }
    finally:
        session.close()


@app.get("/api/reconciliation")
def get_reconciliation_status(
    month: Optional[int] = None,
    year: Optional[int] = None
):
    """Get reconciliation status"""
    session = db.get_session()
    try:
        query = session.query(ReconciliationMatch).join(Invoice)
        
        if month and year:
            last_day_num = calendar.monthrange(year, month)[1]
            first_day = datetime(year, month, 1)
            last_day = datetime(year, month, last_day_num, 23, 59, 59)
            query = query.filter(Invoice.date >= first_day, Invoice.date <= last_day)
        
        matches = query.all()
        
        confirmed = sum(1 for m in matches if m.status == 'confirmed')
        pending = sum(1 for m in matches if m.status == 'pending')
        rejected = sum(1 for m in matches if m.status == 'rejected')
        
        return {
            "total_matches": len(matches),
            "confirmed": confirmed,
            "pending": pending,
            "rejected": rejected
        }
    finally:
        session.close()


@app.get("/api/reports/monthly")
def get_monthly_report(year: int, month: int):
    """Get monthly totals report"""
    session = db.get_session()
    try:
        report_gen = ReportGenerator(session)
        return report_gen.monthly_totals(year, month)
    finally:
        session.close()


@app.get("/api/reports/trends")
def get_trends_report(months: int = 12):
    """Get N-month trends for evolution chart (1, 2, 3, 6, 12, 24, etc.)"""
    session = db.get_session()
    try:
        report_gen = ReportGenerator(session)
        return report_gen.monthly_trends(months=months)
    finally:
        session.close()


@app.post("/api/emails/fetch")
def trigger_email_fetch(since_days: int = 30):
    """
    Trigger immediate email fetching and processing.
    Called on frontend startup or on demand.
    
    Args:
        since_days: Fetch emails from last N days (default: 30)
    """
    from src.scheduler.main import InvoiceScheduler
    
    try:
        scheduler = InvoiceScheduler()
        since_date = datetime.now() - timedelta(days=since_days)
        
        # Run processing in background thread to not block API
        import threading
        def run_fetch():
            try:
                scheduler.process_new_invoices(since_date=since_date)
            except Exception as e:
                print(f"[Background] Error fetching emails: {e}")
        
        thread = threading.Thread(target=run_fetch, daemon=True)
        thread.start()
        
        return {
            "message": f"Email fetch triggered for last {since_days} days",
            "since_date": since_date.isoformat(),
            "status": "processing"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/export/invoices")
def export_invoices_csv(
    month: Optional[int] = None,
    year: Optional[int] = None
):
    """Export invoices to CSV"""
    session = db.get_session()
    try:
        exporter = Exporter(session)
        filename = f"invoices_{year or datetime.now().year}_{month or datetime.now().month}.csv"
        output_path = os.path.join("data/exports", filename)
        exporter.export_invoices_to_csv(output_path, month, year)
        return FileResponse(output_path, filename=filename)
    finally:
        session.close()


@app.get("/api/export/transactions")
def export_transactions_csv(
    month: Optional[int] = None,
    year: Optional[int] = None
):
    """Export transactions to CSV"""
    session = db.get_session()
    try:
        exporter = Exporter(session)
        filename = f"transactions_{year or datetime.now().year}_{month or datetime.now().month}.csv"
        output_path = os.path.join("data/exports", filename)
        exporter.export_transactions_to_csv(output_path, month, year)
        return FileResponse(output_path, filename=filename)
    finally:
        session.close()


@app.get("/api/export/monthly-report")
def export_monthly_report_excel(year: int, month: int):
    """Export monthly report to Excel"""
    session = db.get_session()
    try:
        exporter = Exporter(session)
        filename = f"monthly_report_{year}_{month:02d}.xlsx"
        output_path = os.path.join("data/exports", filename)
        exporter.export_monthly_report_to_excel(output_path, year, month)
        return FileResponse(output_path, filename=filename)
    finally:
        session.close()


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
