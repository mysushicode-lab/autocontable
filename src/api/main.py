"""
FastAPI REST API for invoice processing system
"""
from fastapi import FastAPI, HTTPException, Query, UploadFile, File, Header, Depends
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from datetime import datetime, timedelta
from typing import List, Optional
from sqlalchemy.orm import Session
from sqlalchemy import or_, text
from pydantic import BaseModel
from src.storage.database import db
from src.storage.models import Invoice, BankTransaction, ReconciliationMatch, InvoiceStatus, Settings, User, UserRole, Base, Supplier, ProcessedFileHash, Organization, UserToken
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
import hashlib
import secrets

app = FastAPI(title="Invoice Processing API", version="1.0.0")

# Mount uploads directory for static file serving
os.makedirs("data/uploads", exist_ok=True)
app.mount("/api/uploads", StaticFiles(directory="data/uploads"), name="uploads")


@app.on_event("startup")
def startup_event():
    """Create database tables on startup and run migrations"""
    Base.metadata.create_all(bind=db.engine)

    conn = db.engine.connect()

    # Recreate settings table without UNIQUE(key) constraint if needed
    try:
        idx_info = conn.execute(text("SELECT sql FROM sqlite_master WHERE type='index' AND tbl_name='settings' AND sql LIKE '%UNIQUE%key%'")).fetchall()
        if idx_info:
            conn.execute(text("ALTER TABLE settings RENAME TO settings_old"))
            conn.execute(text("""CREATE TABLE settings (
                id INTEGER PRIMARY KEY,
                key VARCHAR(100) NOT NULL,
                value TEXT,
                category VARCHAR(50) NOT NULL DEFAULT 'general',
                description TEXT,
                organization_id INTEGER REFERENCES organizations(id),
                updated_at DATETIME
            )"""))
            conn.execute(text("INSERT INTO settings SELECT id,key,value,category,description,NULL,updated_at FROM settings_old"))
            conn.execute(text("DROP TABLE settings_old"))
            conn.commit()
    except Exception as e:
        print(f"Settings migration: {e}")

    # Recreate suppliers table without global UNIQUE constraints if needed
    try:
        sup_sql = conn.execute(text("SELECT sql FROM sqlite_master WHERE type='table' AND name='suppliers'")).fetchone()
        if sup_sql and 'UNIQUE' in (sup_sql[0] or ''):
            conn.execute(text("ALTER TABLE suppliers RENAME TO suppliers_old"))
            conn.execute(text("""CREATE TABLE suppliers (
                id INTEGER PRIMARY KEY,
                name VARCHAR(200) NOT NULL,
                normalized_name VARCHAR(200) NOT NULL,
                organization_id INTEGER REFERENCES organizations(id),
                email VARCHAR(200),
                email_domain VARCHAR(100),
                category VARCHAR(100),
                vat_number VARCHAR(50),
                address TEXT,
                created_at DATETIME,
                updated_at DATETIME
            )"""))
            conn.execute(text("INSERT INTO suppliers SELECT id,name,normalized_name,NULL,email,email_domain,category,vat_number,address,created_at,updated_at FROM suppliers_old"))
            conn.execute(text("DROP TABLE suppliers_old"))
            conn.commit()
    except Exception as e:
        print(f"Suppliers migration: {e}")

    # Recreate invoices table without global UNIQUE on invoice_number if needed
    try:
        inv_sql = conn.execute(text("SELECT sql FROM sqlite_master WHERE type='index' AND tbl_name='invoices' AND sql LIKE '%UNIQUE%invoice_number%'")).fetchall()
        if inv_sql:
            conn.execute(text("ALTER TABLE invoices RENAME TO invoices_old"))
            conn.execute(text("""CREATE TABLE invoices (
                id INTEGER PRIMARY KEY,
                invoice_number VARCHAR(100) NOT NULL,
                supplier_id INTEGER REFERENCES suppliers(id),
                organization_id INTEGER REFERENCES organizations(id),
                amount FLOAT NOT NULL,
                amount_ht FLOAT,
                amount_tax FLOAT,
                date DATETIME NOT NULL,
                due_date DATETIME,
                category VARCHAR(100),
                status VARCHAR(50),
                purchase_order VARCHAR(100),
                delivery_note VARCHAR(100),
                vehicle_registration VARCHAR(20),
                work_order_reference VARCHAR(100),
                payment_method VARCHAR(50),
                file_path VARCHAR(500),
                email_subject VARCHAR(500),
                email_from VARCHAR(500),
                email_date DATETIME,
                message_id VARCHAR(200),
                content_hash VARCHAR(32),
                extracted_data TEXT,
                created_at DATETIME,
                updated_at DATETIME
            )"""))
            conn.execute(text("INSERT INTO invoices SELECT id,invoice_number,supplier_id,NULL,amount,amount_ht,amount_tax,date,due_date,category,status,purchase_order,delivery_note,vehicle_registration,work_order_reference,payment_method,file_path,email_subject,email_from,email_date,message_id,content_hash,extracted_data,created_at,updated_at FROM invoices_old"))
            conn.execute(text("DROP TABLE invoices_old"))
            conn.commit()
    except Exception as e:
        print(f"Invoices migration: {e}")

    # Recreate bank_transactions without global UNIQUE on transaction_id if needed
    try:
        bt_sql = conn.execute(text("SELECT sql FROM sqlite_master WHERE type='index' AND tbl_name='bank_transactions' AND sql LIKE '%UNIQUE%transaction_id%'")).fetchall()
        if bt_sql:
            conn.execute(text("ALTER TABLE bank_transactions RENAME TO bank_transactions_old"))
            conn.execute(text("""CREATE TABLE bank_transactions (
                id INTEGER PRIMARY KEY,
                transaction_id VARCHAR(100) NOT NULL,
                organization_id INTEGER REFERENCES organizations(id),
                date DATETIME NOT NULL,
                amount FLOAT NOT NULL,
                description TEXT NOT NULL,
                reference VARCHAR(200),
                account_number VARCHAR(50),
                category VARCHAR(100),
                source_file VARCHAR(500),
                created_at DATETIME
            )"""))
            conn.execute(text("INSERT INTO bank_transactions SELECT id,transaction_id,NULL,date,amount,description,reference,account_number,category,source_file,created_at FROM bank_transactions_old"))
            conn.execute(text("DROP TABLE bank_transactions_old"))
            conn.commit()
    except Exception as e:
        print(f"BankTransactions migration: {e}")

    # Add organization_id columns to remaining tables
    add_col_migrations = [
        "ALTER TABLE users ADD COLUMN organization_id INTEGER REFERENCES organizations(id)",
        "ALTER TABLE reconciliation_matches ADD COLUMN organization_id INTEGER REFERENCES organizations(id)",
        "ALTER TABLE processed_file_hashes ADD COLUMN organization_id INTEGER REFERENCES organizations(id)",
    ]
    for stmt in add_col_migrations:
        try:
            conn.execute(text(stmt))
            conn.commit()
        except Exception:
            pass

    conn.close()

    session = db.get_session()
    try:
        # Create default organization for existing data
        default_org = session.query(Organization).filter(Organization.id == 1).first()
        if not default_org:
            default_org = Organization(name="Organisation par défaut")
            session.add(default_org)
            session.flush()
            default_org_id = default_org.id
            session.commit()
        else:
            default_org_id = default_org.id

        # Assign existing users without org to default org
        session.execute(text(f"UPDATE users SET organization_id = {default_org_id} WHERE organization_id IS NULL"))
        session.execute(text(f"UPDATE invoices SET organization_id = {default_org_id} WHERE organization_id IS NULL"))
        session.execute(text(f"UPDATE suppliers SET organization_id = {default_org_id} WHERE organization_id IS NULL"))
        session.execute(text(f"UPDATE bank_transactions SET organization_id = {default_org_id} WHERE organization_id IS NULL"))
        session.execute(text(f"UPDATE reconciliation_matches SET organization_id = {default_org_id} WHERE organization_id IS NULL"))
        session.execute(text(f"UPDATE settings SET organization_id = {default_org_id} WHERE organization_id IS NULL"))
        session.execute(text(f"UPDATE processed_file_hashes SET organization_id = {default_org_id} WHERE organization_id IS NULL"))
        session.commit()

        # Create default admin user if not exists
        try:
            default_admin_username = os.environ.get('ADMIN_USERNAME', 'admin')
            default_admin_password = os.environ.get('ADMIN_PASSWORD', 'admin123')
            default_admin_email = os.environ.get('ADMIN_EMAIL', '')
            admin_exists = session.query(User).filter(User.username == default_admin_username).first()
            if not admin_exists:
                password_hash = hashlib.sha256(default_admin_password.encode()).hexdigest()
                admin = User(
                    username=default_admin_username,
                    password_hash=password_hash,
                    role=UserRole.ADMIN,
                    name='Administrateur',
                    email=default_admin_email or None,
                    organization_id=default_org_id
                )
                session.add(admin)
                session.commit()
        except Exception as e:
            print(f"Warning: Could not check/create admin user: {e}")
            session.rollback()

        # Insert default settings if not already set
        try:
            default_settings = [
                ('imap_server', 'imap.gmail.com', 'email', 'Serveur IMAP'),
                ('imap_port', '993', 'email', 'Port IMAP'),
                ('email_folder', 'INBOX', 'email', 'Dossier IMAP'),
                ('scheduler_interval', '0.166', 'scheduler', 'Intervalle en minutes (0.166 = toutes les 10 secondes)'),
                ('auto_reconciliation', 'true', 'scheduler', 'Rapprochement automatique'),
                ('company_name', '', 'general', 'Nom de votre entreprise (ignoré comme fournisseur par l\'IA)'),
            ]
            for key, value, category, description in default_settings:
                exists = session.query(Settings).filter(
                    Settings.key == key, Settings.organization_id == default_org_id
                ).first()
                if not exists:
                    session.add(Settings(key=key, value=value, category=category, description=description, organization_id=default_org_id))
            session.commit()
        except Exception as e:
            print(f"Warning: Could not insert default settings: {e}")
            session.rollback()
    finally:
        session.close()

UPLOAD_ROOT = os.path.join("data", "uploads")
INVOICE_UPLOAD_DIR = os.path.join(UPLOAD_ROOT, "invoices")
BANK_UPLOAD_DIR = os.path.join(UPLOAD_ROOT, "bank_statements")


def get_current_user(authorization: Optional[str] = Header(None)) -> dict:
    """Validate Bearer token and return user info dict."""
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Token manquant")
    token = authorization[7:]
    session = db.get_session()
    try:
        user_token = session.query(UserToken).filter(UserToken.token == token).first()
        if not user_token:
            raise HTTPException(status_code=401, detail="Token invalide ou expiré")
        user = session.query(User).filter(User.id == user_token.user_id).first()
        if not user:
            raise HTTPException(status_code=401, detail="Utilisateur introuvable")
        return {
            "id": user.id,
            "username": user.username,
            "name": user.name,
            "role": user.role.value,
            "organization_id": user.organization_id,
            "email": user.email,
            "profile_photo": user.profile_photo,
        }
    finally:
        session.close()


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


def _create_or_update_invoice(session: Session, file_path: str, extracted_data: dict, organization_id: int) -> Invoice:
    supplier_classifier = SupplierClassifier(session)
    category_classifier = CategoryClassifier()
    supplier = supplier_classifier.detect_supplier(extracted_data)
    invoice_number = extracted_data.get("invoice_number") or _build_invoice_number(file_path)
    extraction_confidence = extracted_data.get("extraction_confidence", "low")

    invoice = session.query(Invoice).filter(Invoice.invoice_number == invoice_number).first()
    if invoice is None:
        invoice = Invoice(invoice_number=invoice_number, organization_id=organization_id)
        session.add(invoice)
    else:
        invoice.organization_id = organization_id

    invoice.supplier_id = supplier.id if supplier else None
    invoice.amount = extracted_data.get("amount") or 0.0
    invoice.amount_ht = extracted_data.get("amount_ht")
    invoice.amount_tax = extracted_data.get("amount_tax")
    invoice.date = extracted_data.get("date") or datetime.utcnow()
    invoice.due_date = extracted_data.get("due_date")
    invoice.category = extracted_data.get("category") or category_classifier.classify(extracted_data)
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


class UpdateInvoiceRequest(BaseModel):
    invoice_number: Optional[str] = None
    supplier_name: Optional[str] = None
    amount: Optional[float] = None
    amount_ht: Optional[float] = None
    amount_tax: Optional[float] = None
    date: Optional[str] = None
    due_date: Optional[str] = None
    category: Optional[str] = None
    vehicle_registration: Optional[str] = None
    work_order_reference: Optional[str] = None
    purchase_order: Optional[str] = None
    payment_method: Optional[str] = None
    status: Optional[str] = None


@app.post("/api/invoices/upload")
async def upload_invoice(file: UploadFile = File(...), current_user: dict = Depends(get_current_user)):
    """Import a supplier invoice manually."""
    allowed_extensions = {".pdf", ".png", ".jpg", ".jpeg", ".tiff", ".bmp"}
    extension = os.path.splitext(file.filename or "")[1].lower()
    if extension not in allowed_extensions:
        raise HTTPException(status_code=400, detail="Unsupported invoice file format")

    file_bytes = await file.read()
    content_hash = hashlib.md5(file_bytes).hexdigest()
    file.file.seek(0)

    saved_path = _save_uploaded_file(file, INVOICE_UPLOAD_DIR)
    session = db.get_session()
    try:
        already_done = session.query(ProcessedFileHash).filter(
            ProcessedFileHash.content_hash == content_hash
        ).first()
        if already_done:
            existing_invoice = session.query(Invoice).filter(
                Invoice.content_hash == content_hash
            ).first()
            if existing_invoice:
                return {
                    "message": "Facture déjà importée (fichier identique)",
                    "invoice": {
                        "id": existing_invoice.id,
                        "invoice_number": existing_invoice.invoice_number,
                        "amount": existing_invoice.amount,
                        "status": existing_invoice.status.value if existing_invoice.status else None,
                        "supplier": existing_invoice.supplier.name if existing_invoice.supplier else None,
                    }
                }
            # Invoice was deleted — remove hash to allow re-import
            session.delete(already_done)
            session.commit()

        processor = InvoiceProcessor()
        extracted_data = processor.process_invoice(saved_path)
        invoice = _create_or_update_invoice(session, saved_path, extracted_data, current_user["organization_id"])
        invoice.content_hash = content_hash
        if invoice.supplier:
            invoice.supplier.organization_id = current_user["organization_id"]
        if not session.query(ProcessedFileHash).filter(ProcessedFileHash.content_hash == content_hash).first():
            session.add(ProcessedFileHash(content_hash=content_hash, filename=file.filename, organization_id=current_user["organization_id"]))
        session.commit()
        session.refresh(invoice)
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
async def import_bank_statement(file: UploadFile = File(...), current_user: dict = Depends(get_current_user)):
    """Import a bank statement from CSV/OFX/QFX/PDF."""
    allowed_extensions = {".csv", ".ofx", ".qfx", ".pdf"}
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
                raw = f"{tx.get('date')}{tx.get('amount')}{tx.get('description', '')}"
                transaction_id = "PDF-" + hashlib.md5(raw.encode()).hexdigest()[:16]

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
                organization_id=current_user["organization_id"],
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
def run_reconciliation(month: Optional[int] = None, year: Optional[int] = None, current_user: dict = Depends(get_current_user)):
    """Run reconciliation automatically on current invoices and transactions."""
    session = db.get_session()
    org_id = current_user["organization_id"]
    try:
        invoice_query = session.query(Invoice).filter(
            Invoice.status.in_([InvoiceStatus.PROCESSED, InvoiceStatus.UNMATCHED]),
            Invoice.organization_id == org_id
        )
        transaction_query = session.query(BankTransaction).filter(BankTransaction.organization_id == org_id)


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
def confirm_match(match_id: int, current_user: dict = Depends(get_current_user)):
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
def reject_match(match_id: int, current_user: dict = Depends(get_current_user)):
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
def create_manual_link(payload: ManualLinkPayload, current_user: dict = Depends(get_current_user)):
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
    year: Optional[int] = None,
    current_user: dict = Depends(get_current_user)
):
    """Get detailed reconciliation payload for the UI."""
    session = db.get_session()
    org_id = current_user["organization_id"]
    try:
        invoice_query = session.query(Invoice).filter(Invoice.organization_id == org_id)
        match_query = session.query(ReconciliationMatch).filter(ReconciliationMatch.organization_id == org_id).join(Invoice).join(BankTransaction, ReconciliationMatch.transaction_id == BankTransaction.id)
        transaction_query = session.query(BankTransaction).filter(BankTransaction.organization_id == org_id)

        if month and year:
            last_day_num = calendar.monthrange(year, month)[1]
            first_day = datetime(year, month, 1)
            last_day = datetime(year, month, last_day_num, 23, 59, 59)
            invoice_query = invoice_query.filter(Invoice.date >= first_day, Invoice.date <= last_day)
            match_query = match_query.filter(
                or_(Invoice.date >= first_day, BankTransaction.date >= first_day),
                or_(Invoice.date <= last_day, BankTransaction.date <= last_day),
            )
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
def get_vehicle_history(registration: str, current_user: dict = Depends(get_current_user)):
    """Get invoice history aggregated by vehicle registration."""
    session = db.get_session()
    try:
        normalized_registration = registration.upper()
        invoices = session.query(Invoice).filter(
            Invoice.vehicle_registration == normalized_registration,
            Invoice.organization_id == current_user["organization_id"]
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
    year: Optional[int] = None,
    current_user: dict = Depends(get_current_user)
):
    """List all invoices with optional filters"""
    session = db.get_session()
    try:
        query = session.query(Invoice).filter(Invoice.organization_id == current_user["organization_id"])
        
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
                    "amount_ht": inv.amount_ht,
                    "amount_tax": inv.amount_tax,
                    "date": inv.date.isoformat() if inv.date else None,
                    "due_date": inv.due_date.isoformat() if inv.due_date else None,
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


@app.delete("/api/invoices/{invoice_id}")
def delete_invoice(invoice_id: int, current_user: dict = Depends(get_current_user)):
    """Delete an invoice and its reconciliation matches"""
    session = db.get_session()
    try:
        invoice = session.query(Invoice).filter(Invoice.id == invoice_id, Invoice.organization_id == current_user["organization_id"]).first()
        if not invoice:
            raise HTTPException(status_code=404, detail="Invoice not found")
        session.query(ReconciliationMatch).filter(ReconciliationMatch.invoice_id == invoice_id).delete()
        if invoice.file_path and os.path.exists(invoice.file_path):
            try:
                os.remove(invoice.file_path)
            except Exception:
                pass
        session.delete(invoice)
        session.commit()
        return {"message": "Invoice deleted"}
    finally:
        session.close()


@app.put("/api/invoices/{invoice_id}")
def update_invoice(invoice_id: int, request: UpdateInvoiceRequest, current_user: dict = Depends(get_current_user)):
    """Update invoice fields and propagate changes"""
    session = db.get_session()
    try:
        invoice = session.query(Invoice).filter(Invoice.id == invoice_id, Invoice.organization_id == current_user["organization_id"]).first()
        if not invoice:
            raise HTTPException(status_code=404, detail="Invoice not found")
        if request.invoice_number is not None:
            invoice.invoice_number = request.invoice_number
        if request.amount is not None:
            invoice.amount = request.amount
        if request.amount_ht is not None:
            invoice.amount_ht = request.amount_ht
        if request.amount_tax is not None:
            invoice.amount_tax = request.amount_tax
        if request.date is not None:
            invoice.date = datetime.fromisoformat(request.date)
        if request.due_date is not None:
            invoice.due_date = datetime.fromisoformat(request.due_date) if request.due_date else None
        if request.category is not None:
            invoice.category = request.category
        if request.vehicle_registration is not None:
            invoice.vehicle_registration = request.vehicle_registration.upper() if request.vehicle_registration else None
        if request.work_order_reference is not None:
            invoice.work_order_reference = request.work_order_reference
        if request.purchase_order is not None:
            invoice.purchase_order = request.purchase_order
        if request.payment_method is not None:
            invoice.payment_method = request.payment_method
        if request.status is not None:
            try:
                invoice.status = InvoiceStatus(request.status)
            except ValueError:
                pass
        if request.supplier_name is not None:
            if request.supplier_name:
                supplier = session.query(Supplier).filter(Supplier.name == request.supplier_name).first()
                if not supplier:
                    normalized = request.supplier_name.lower().strip()
                    supplier = Supplier(name=request.supplier_name, normalized_name=normalized)
                    session.add(supplier)
                    session.flush()
                invoice.supplier_id = supplier.id
            else:
                invoice.supplier_id = None
        session.commit()
        session.refresh(invoice)
        return {
            "message": "Invoice updated",
            "invoice": {
                "id": invoice.id,
                "invoice_number": invoice.invoice_number,
                "supplier": invoice.supplier.name if invoice.supplier else None,
                "amount": invoice.amount,
                "amount_ht": invoice.amount_ht,
                "amount_tax": invoice.amount_tax,
                "date": invoice.date.isoformat() if invoice.date else None,
                "due_date": invoice.due_date.isoformat() if invoice.due_date else None,
                "category": invoice.category,
                "vehicle_registration": invoice.vehicle_registration,
                "work_order_reference": invoice.work_order_reference,
                "purchase_order": invoice.purchase_order,
                "payment_method": invoice.payment_method,
                "status": invoice.status.value if invoice.status else None,
            }
        }
    finally:
        session.close()


@app.get("/api/invoices/{invoice_id}")
def get_invoice(invoice_id: int, current_user: dict = Depends(get_current_user)):
    """Get single invoice by ID"""
    session = db.get_session()
    try:
        invoice = session.query(Invoice).filter(Invoice.id == invoice_id, Invoice.organization_id == current_user["organization_id"]).first()
        
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
def download_invoice_pdf(invoice_id: int, current_user: dict = Depends(get_current_user)):
    """Download invoice PDF file"""
    session = db.get_session()
    try:
        invoice = session.query(Invoice).filter(Invoice.id == invoice_id, Invoice.organization_id == current_user["organization_id"]).first()
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
    year: Optional[int] = None,
    current_user: dict = Depends(get_current_user)
):
    """List all bank transactions"""
    session = db.get_session()
    try:
        query = session.query(BankTransaction).filter(BankTransaction.organization_id == current_user["organization_id"])
        
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
    year: Optional[int] = None,
    current_user: dict = Depends(get_current_user)
):
    """Get reconciliation status"""
    session = db.get_session()
    try:
        query = session.query(ReconciliationMatch).filter(ReconciliationMatch.organization_id == current_user["organization_id"]).join(Invoice).join(BankTransaction, ReconciliationMatch.transaction_id == BankTransaction.id)
        
        if month and year:
            last_day_num = calendar.monthrange(year, month)[1]
            first_day = datetime(year, month, 1)
            last_day = datetime(year, month, last_day_num, 23, 59, 59)
            query = query.filter(
                or_(Invoice.date >= first_day, BankTransaction.date >= first_day),
                or_(Invoice.date <= last_day, BankTransaction.date <= last_day),
            )
        
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
def get_monthly_report(year: int, month: int, current_user: dict = Depends(get_current_user)):
    """Get monthly totals report"""
    session = db.get_session()
    try:
        report_gen = ReportGenerator(session, org_id=current_user["organization_id"])
        return report_gen.monthly_totals(year, month)
    finally:
        session.close()


@app.get("/api/reports/trends")
def get_trends_report(months: int = 12, current_user: dict = Depends(get_current_user)):
    """Get N-month trends for evolution chart (1, 2, 3, 6, 12, 24, etc.)"""
    session = db.get_session()
    try:
        report_gen = ReportGenerator(session, org_id=current_user["organization_id"])
        return report_gen.monthly_trends(months=months)
    finally:
        session.close()


@app.post("/api/emails/fetch")
def trigger_email_fetch(since_days: int = 30, current_user: dict = Depends(get_current_user)):
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
    year: Optional[int] = None,
    current_user: dict = Depends(get_current_user)
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
    year: Optional[int] = None,
    current_user: dict = Depends(get_current_user)
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
def export_monthly_report_excel(year: int, month: int, current_user: dict = Depends(get_current_user)):
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


# Settings API endpoints
class SettingUpdate(BaseModel):
    value: str


@app.get("/api/settings")
def get_settings(category: Optional[str] = None, current_user: dict = Depends(get_current_user)):
    """Get all settings or filtered by category"""
    session = db.get_session()
    try:
        query = session.query(Settings).filter(Settings.organization_id == current_user["organization_id"])
        if category:
            query = query.filter(Settings.category == category)
        settings = query.all()
        return {
            "settings": [
                {
                    "key": s.key,
                    "value": s.value,
                    "category": s.category,
                    "description": s.description,
                    "updated_at": s.updated_at.isoformat() if s.updated_at else None
                }
                for s in settings
            ]
        }
    finally:
        session.close()


@app.put("/api/settings/{key}")
def update_setting(key: str, update: SettingUpdate, current_user: dict = Depends(get_current_user)):
    """Update a setting value"""
    session = db.get_session()
    org_id = current_user["organization_id"]
    try:
        setting = session.query(Settings).filter(Settings.key == key, Settings.organization_id == org_id).first()
        if not setting:
            setting = Settings(key=key, value=update.value, category="general", organization_id=org_id)
            session.add(setting)
        else:
            setting.value = update.value
        session.commit()
        return {"message": "Setting updated", "key": key, "value": update.value}
    finally:
        session.close()


class TestImapRequest(BaseModel):
    server: str
    port: int
    email: str
    password: str


@app.post("/api/settings/test-imap")
def test_imap_connection(request: TestImapRequest):
    """Test IMAP connection with provided credentials"""
    import imaplib
    import ssl
    try:
        context = ssl.create_default_context()
        mail = imaplib.IMAP4_SSL(request.server, request.port, ssl_context=context)
        mail.login(request.email, request.password)
        mail.logout()
        return {"success": True, "message": "Connexion réussie"}
    except imaplib.IMAP4.error as e:
        return {"success": False, "message": f"Erreur d'authentification : {str(e)}"}
    except ConnectionRefusedError:
        return {"success": False, "message": "Connexion refusée - vérifiez le serveur et le port"}
    except ssl.SSLError as e:
        return {"success": False, "message": f"Erreur SSL : {str(e)}"}
    except OSError as e:
        return {"success": False, "message": f"Serveur introuvable : {str(e)}"}
    except Exception as e:
        return {"success": False, "message": f"Erreur : {str(e)}"}


# Auth endpoints
class LoginRequest(BaseModel):
    username: str
    password: str


class CreateUserRequest(BaseModel):
    username: str
    password: str
    name: str
    email: Optional[str] = None
    role: str = "accountant"


class RegisterRequest(BaseModel):
    username: str
    password: str
    name: str
    email: Optional[str] = None


@app.post("/api/auth/register")
def register(request: RegisterRequest):
    """Public registration — creates a new organization and admin account."""
    session = db.get_session()
    try:
        if session.query(User).filter(User.username == request.username).first():
            raise HTTPException(status_code=400, detail="Ce nom d'utilisateur est déjà pris.")
        org = Organization(name=request.name)
        session.add(org)
        session.flush()
        org_id = org.id
        password_hash = hashlib.sha256(request.password.encode()).hexdigest()
        user = User(
            username=request.username,
            password_hash=password_hash,
            name=request.name,
            email=request.email,
            role=UserRole.ADMIN,
            organization_id=org_id
        )
        session.add(user)
        session.flush()
        user_id = user.id
        default_settings = [
            ('imap_server', 'imap.gmail.com', 'email', 'Serveur IMAP'),
            ('imap_port', '993', 'email', 'Port IMAP'),
            ('email_folder', 'INBOX', 'email', 'Dossier IMAP'),
            ('scheduler_interval', '0.166', 'scheduler', 'Intervalle en minutes'),
            ('auto_reconciliation', 'true', 'scheduler', 'Rapprochement automatique'),
            ('company_name', request.name, 'general', 'Nom de votre entreprise'),
        ]
        for key, value, category, description in default_settings:
            session.add(Settings(key=key, value=value, category=category, description=description, organization_id=org_id))
        token_value = secrets.token_hex(32)
        user_token = UserToken(token=token_value, user_id=user_id)
        session.add(user_token)
        session.commit()
        return {
            "token": token_value,
            "user": {
                "id": user_id,
                "username": request.username,
                "name": request.name,
                "role": UserRole.ADMIN.value,
                "organization_id": org_id,
                "email": request.email,
                "profile_photo": None
            }
        }
    finally:
        session.close()


@app.post("/api/auth/login")
def login(request: LoginRequest):
    """Login - validates credentials and returns stored token"""
    session = db.get_session()
    try:
        user = session.query(User).filter(User.username == request.username).first()
        if not user:
            raise HTTPException(status_code=401, detail="Identifiants invalides")
        password_hash = hashlib.sha256(request.password.encode()).hexdigest()
        if user.password_hash != password_hash:
            raise HTTPException(status_code=401, detail="Identifiants invalides")
        token_value = secrets.token_hex(32)
        user_token = UserToken(token=token_value, user_id=user.id)
        session.add(user_token)
        session.commit()
        return {
            "token": token_value,
            "user": {
                "id": user.id,
                "username": user.username,
                "name": user.name,
                "role": user.role.value,
                "organization_id": user.organization_id,
                "email": user.email,
                "profile_photo": user.profile_photo
            }
        }
    finally:
        session.close()


@app.delete("/api/auth/delete-account")
def delete_own_account(current_user: dict = Depends(get_current_user)):
    """Delete the authenticated user's own account"""
    session = db.get_session()
    try:
        user = session.query(User).filter(User.id == current_user["id"]).first()
        if not user:
            raise HTTPException(status_code=404, detail="Compte introuvable")
        session.query(UserToken).filter(UserToken.user_id == user.id).delete()
        session.delete(user)
        session.commit()
        return {"message": "Compte supprimé"}
    finally:
        session.close()


@app.get("/api/users")
def list_users(current_user: dict = Depends(get_current_user)):
    """List all users in the same organization"""
    session = db.get_session()
    try:
        users = session.query(User).filter(User.organization_id == current_user["organization_id"]).all()
        return {
            "users": [
                {
                    "id": u.id,
                    "username": u.username,
                    "name": u.name,
                    "email": u.email,
                    "role": u.role.value,
                    "created_at": u.created_at.isoformat() if u.created_at else None
                }
                for u in users
            ]
        }
    finally:
        session.close()


@app.post("/api/users")
def create_user(request: CreateUserRequest, current_user: dict = Depends(get_current_user)):
    """Create a new user in the same organization"""
    session = db.get_session()
    try:
        if session.query(User).filter(User.username == request.username).first():
            raise HTTPException(status_code=400, detail="Username already exists")

        password_hash = hashlib.sha256(request.password.encode()).hexdigest()
        user = User(
            username=request.username,
            password_hash=password_hash,
            name=request.name,
            email=request.email,
            role=UserRole.ADMIN if request.role == "admin" else UserRole.ACCOUNTANT,
            organization_id=current_user["organization_id"]
        )
        session.add(user)
        session.commit()
        return {"message": "User created", "id": user.id}
    finally:
        session.close()


@app.delete("/api/users/{user_id}")
def delete_user(user_id: int, current_user: dict = Depends(get_current_user)):
    """Delete a user"""
    session = db.get_session()
    try:
        user = session.query(User).filter(User.id == user_id, User.organization_id == current_user["organization_id"]).first()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        if user.id == current_user["id"]:
            raise HTTPException(status_code=400, detail="Vous ne pouvez pas supprimer votre propre compte")
        session.delete(user)
        session.commit()
        return {"message": "User deleted"}
    finally:
        session.close()


class UpdateUserRequest(BaseModel):
    name: Optional[str] = None
    email: Optional[str] = None


@app.put("/api/users/{user_id}")
def update_user(user_id: int, request: UpdateUserRequest, current_user: dict = Depends(get_current_user)):
    """Update user name and email"""
    session = db.get_session()
    try:
        user = session.query(User).filter(User.id == user_id, User.organization_id == current_user["organization_id"]).first()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        if request.name is not None:
            user.name = request.name
        if request.email is not None:
            user.email = request.email

        session.commit()
        session.refresh(user)
        return {
            "message": "User updated",
            "user": {
                "id": user.id,
                "username": user.username,
                "name": user.name,
                "email": user.email,
                "role": user.role.value,
                "profile_photo": user.profile_photo
            }
        }
    finally:
        session.close()


@app.post("/api/users/{user_id}/profile-photo")
def upload_profile_photo(user_id: int, file: UploadFile = File(...), current_user: dict = Depends(get_current_user)):
    """Upload profile photo for a user"""
    session = db.get_session()
    try:
        user = session.query(User).filter(User.id == user_id, User.organization_id == current_user["organization_id"]).first()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        # Validate file type
        if not file.content_type or not file.content_type.startswith('image/'):
            raise HTTPException(status_code=400, detail="File must be an image")

        # Create uploads directory if not exists
        upload_dir = os.path.join("data", "uploads", "profile_photos")
        os.makedirs(upload_dir, exist_ok=True)

        # Generate filename
        ext = os.path.splitext(file.filename)[1]
        filename = f"user_{user_id}{ext}"
        filepath = os.path.join(upload_dir, filename)

        # Save file
        with open(filepath, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        # Update user record
        user.profile_photo = f"/api/uploads/profile_photos/{filename}"
        session.commit()

        return {"message": "Profile photo updated", "photo_url": user.profile_photo}
    finally:
        session.close()


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
