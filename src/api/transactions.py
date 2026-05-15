"""Transaction endpoints"""
from fastapi import APIRouter, UploadFile, File, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import Optional
from datetime import datetime
import os
import calendar
import hashlib

from src.storage.database import db
from src.storage.models import BankTransaction, ReconciliationMatch
from src.bank_importer.bank_importer import BankImporter
from src.api.utils import save_uploaded_file
from src.api.auth import get_current_user, check_trial_active

router = APIRouter()

UPLOAD_ROOT = os.path.join("data", "uploads")
BANK_UPLOAD_DIR = os.path.join(UPLOAD_ROOT, "bank_statements")


@router.post("/import")
async def import_bank_statement(file: UploadFile = File(...), current_user: dict = Depends(check_trial_active)):
    """Import a bank statement from CSV/OFX/QFX/PDF."""
    import os
    allowed_extensions = {".csv", ".ofx", ".qfx", ".pdf"}
    extension = os.path.splitext(file.filename or "")[1].lower()
    if extension not in allowed_extensions:
        raise HTTPException(status_code=400, detail="Unsupported bank statement format")

    saved_path = save_uploaded_file(file, BANK_UPLOAD_DIR)
    session = db.get_session()
    try:
        # Calculate file hash for duplicate detection
        file_hash = hashlib.md5(open(saved_path, 'rb').read()).hexdigest()
        
        # Check if the same file (by hash) has been imported for the same month
        existing_same_hash = session.query(BankTransaction).filter(
            BankTransaction.organization_id == current_user["organization_id"],
            BankTransaction.file_hash == file_hash
        ).first()
        
        if existing_same_hash:
            existing_date = existing_same_hash.date
            file_month = existing_date.month
            file_year = existing_date.year
            
            raise HTTPException(
                status_code=400, 
                detail=f"Ce relevé bancaire a déjà été importé pour {file_month}/{file_year}"
            )
        
        # Determine the month from the file content or current date
        importer = BankImporter()
        transactions = importer.import_file(saved_path)
        
        imported_count = 0

        for tx in transactions:
            transaction_id = tx.get("reference") or tx.get("transaction_id")
            if not transaction_id:
                raw = f"{tx.get('date')}{tx.get('amount')}{tx.get('description', '')}"
                transaction_id = "PDF-" + hashlib.md5(raw.encode()).hexdigest()[:16]

            # Check for duplicate transaction_id (transaction-level duplicate)
            existing_transaction = session.query(BankTransaction).filter(
                BankTransaction.transaction_id == transaction_id,
                BankTransaction.organization_id == current_user["organization_id"]
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
                file_hash=file_hash,
                organization_id=current_user["organization_id"],
            ))
            imported_count += 1

        session.commit()
        return {
            "message": "Bank statement imported successfully",
            "imported_count": imported_count,
            "file_path": saved_path,
        }
    except HTTPException:
        session.rollback()
        raise
    except Exception as exc:
        session.rollback()
        raise HTTPException(status_code=400, detail=str(exc))
    finally:
        session.close()


@router.get("/")
@router.get("")
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


@router.delete("/{transaction_id}")
def delete_transaction(transaction_id: int, current_user: dict = Depends(get_current_user)):
    """Delete a bank transaction"""
    session = db.get_session()
    try:
        transaction = session.query(BankTransaction).filter(
            BankTransaction.id == transaction_id,
            BankTransaction.organization_id == current_user["organization_id"]
        ).first()
        
        if not transaction:
            raise HTTPException(status_code=404, detail="Transaction not found")
        
        # Delete any reconciliation matches that reference this transaction
        session.query(ReconciliationMatch).filter(
            ReconciliationMatch.transaction_id == transaction_id
        ).delete()
        
        session.delete(transaction)
        session.commit()
        
        return {"message": "Transaction deleted successfully"}
    except Exception as exc:
        session.rollback()
        raise HTTPException(status_code=400, detail=str(exc))
    finally:
        session.close()


@router.delete("/month/{year}/{month}")
def delete_transactions_by_month(year: int, month: int, current_user: dict = Depends(get_current_user)):
    """Delete all transactions for a specific month"""
    session = db.get_session()
    try:
        last_day_num = calendar.monthrange(year, month)[1]
        first_day = datetime(year, month, 1)
        last_day = datetime(year, month, last_day_num, 23, 59, 59)
        
        transactions = session.query(BankTransaction).filter(
            BankTransaction.organization_id == current_user["organization_id"],
            BankTransaction.date >= first_day,
            BankTransaction.date <= last_day
        ).all()
        
        transaction_ids = [tx.id for tx in transactions]
        
        # Delete reconciliation matches for these transactions
        if transaction_ids:
            session.query(ReconciliationMatch).filter(
                ReconciliationMatch.transaction_id.in_(transaction_ids)
            ).delete()
        
        deleted_count = len(transactions)
        for tx in transactions:
            session.delete(tx)
        
        session.commit()
        
        return {"message": f"{deleted_count} transactions deleted successfully", "deleted_count": deleted_count}
    except Exception as exc:
        session.rollback()
        raise HTTPException(status_code=400, detail=str(exc))
    finally:
        session.close()
