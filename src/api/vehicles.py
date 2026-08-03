"""Reference endpoints (formerly vehicle)"""
from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session

from src.storage.database import db
from src.storage.models import Invoice
from src.api.auth import get_current_user

router = APIRouter()


@router.get("/{reference}/history")
def get_reference_history(reference: str, current_user: dict = Depends(get_current_user)):
    """Get invoice history aggregated by reference number (license plate, project number, etc.)."""
    session = db.get_session()
    try:
        normalized_reference = reference.upper()
        invoices = session.query(Invoice).filter(
            Invoice.reference_number == normalized_reference,
            Invoice.organization_id == current_user["organization_id"]
        ).order_by(Invoice.date.desc()).all()

        if not invoices:
            raise HTTPException(status_code=404, detail="Reference history not found")

        total_spent = sum(invoice.amount or 0 for invoice in invoices)
        categories = {}
        history = []
        for invoice in invoices:
            category = invoice.category or "Non catégorisé"
            categories.setdefault(category, {"count": 0, "amount": 0})
            categories[category]["count"] += 1
            categories[category]["amount"] += invoice.amount or 0
            history.append({
                "invoice_id": invoice.id,
                "file_path": invoice.file_path,
                "date": invoice.date.isoformat() if invoice.date else None,
                "description": invoice.category or "Facture fournisseur",
                "amount": invoice.amount,
                "category": category,
                "invoice_number": invoice.invoice_number,
                "supplier": invoice.supplier.name if invoice.supplier else None,
                "work_order_reference": invoice.work_order_reference,
                "reference_number": invoice.reference_number
            })

        return {
            "registration": normalized_reference,
            "total_spent": total_spent,
            "intervention_count": len(invoices),
            "last_visit": invoices[0].date.isoformat() if invoices[0].date else None,
            "history": history,
            "categories": categories
        }
    finally:
        session.close()
