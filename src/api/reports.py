"""Reporting endpoints"""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import Optional

from src.storage.database import db
from src.reporting.report_generator import ReportGenerator
from src.reporting.exporter import Exporter
from src.api.auth import get_current_user

router = APIRouter()


@router.get("/monthly")
@router.get("/monthly/")
def get_monthly_report(year: int, month: int, current_user: dict = Depends(get_current_user)):
    """Get monthly totals report"""
    session = db.get_session()
    try:
        report_gen = ReportGenerator(session, org_id=current_user["organization_id"])
        return report_gen.monthly_totals(year, month)
    finally:
        session.close()


@router.get("/trends")
@router.get("/trends/")
def get_trends_report(months: int = 12, current_user: dict = Depends(get_current_user)):
    """Get N-month trends for evolution chart (1, 2, 3, 6, 12, 24, etc.)"""
    session = db.get_session()
    try:
        report_gen = ReportGenerator(session, org_id=current_user["organization_id"])
        return report_gen.monthly_trends(months=months)
    finally:
        session.close()


@router.get("/export/invoices")
@router.get("/export/invoices/")
def export_invoices_csv(
    month: Optional[int] = None,
    year: Optional[int] = None,
    current_user: dict = Depends(get_current_user)
):
    """Export invoices to CSV"""
    import os
    from fastapi.responses import FileResponse
    from datetime import datetime
    
    session = db.get_session()
    try:
        exporter = Exporter(session, org_id=current_user["organization_id"])
        filename = f"invoices_{year or datetime.now().year}_{month or datetime.now().month}.csv"
        output_path = os.path.join("data/exports", filename)
        exporter.export_invoices_to_csv(output_path, month, year)
        return FileResponse(output_path, filename=filename)
    finally:
        session.close()


@router.get("/export/transactions")
@router.get("/export/transactions/")
def export_transactions_csv(
    month: Optional[int] = None,
    year: Optional[int] = None,
    current_user: dict = Depends(get_current_user)
):
    """Export transactions to CSV"""
    import os
    from fastapi.responses import FileResponse
    from datetime import datetime
    
    session = db.get_session()
    try:
        exporter = Exporter(session, org_id=current_user["organization_id"])
        filename = f"transactions_{year or datetime.now().year}_{month or datetime.now().month}.csv"
        output_path = os.path.join("data/exports", filename)
        exporter.export_transactions_to_csv(output_path, month, year)
        return FileResponse(output_path, filename=filename)
    finally:
        session.close()


@router.get("/export/dossier")
def export_dossier_zip(year: int, month: int, current_user: dict = Depends(get_current_user)):
    """Export full accounting dossier as ZIP: Excel report + all invoice PDFs for the period"""
    import os, zipfile, re, calendar as cal
    from fastapi.responses import FileResponse
    from datetime import datetime
    from src.storage.models import Invoice

    session = db.get_session()
    try:
        org_id = current_user["organization_id"]
        first_day = datetime(year, month, 1)
        last_day = datetime(year, month, cal.monthrange(year, month)[1], 23, 59, 59)

        invoices = session.query(Invoice).filter(
            Invoice.organization_id == org_id,
            Invoice.date >= first_day,
            Invoice.date <= last_day,
        ).all()

        os.makedirs("data/exports", exist_ok=True)
        zip_filename = f"dossier_comptable_{year}_{month:02d}.zip"
        zip_path = os.path.join("data/exports", zip_filename)

        exporter = Exporter(session, org_id=org_id)
        excel_filename = f"rapport_{year}_{month:02d}.xlsx"
        excel_path = os.path.join("data/exports", excel_filename)
        exporter.export_monthly_report_to_excel(excel_path, year, month)

        def safe_name(s: str) -> str:
            return re.sub(r'[\\/:*?"<>|]', '_', s or '')

        with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zf:
            zf.write(excel_path, excel_filename)
            for inv in invoices:
                if inv.file_path and os.path.exists(inv.file_path):
                    ext = os.path.splitext(inv.file_path)[1].lower() or '.pdf'
                    date_str = inv.date.strftime('%Y%m%d') if inv.date else 'nodate'
                    supplier_str = safe_name(inv.supplier.name if inv.supplier else 'inconnu')
                    inv_num = safe_name(inv.invoice_number or 'nofacture')
                    arcname = f"factures/{date_str}_{supplier_str}_{inv_num}{ext}"
                    zf.write(inv.file_path, arcname)

        return FileResponse(zip_path, media_type="application/zip", filename=zip_filename)
    finally:
        session.close()


@router.get("/export/monthly-report")
def export_monthly_report_excel(year: int, month: int, current_user: dict = Depends(get_current_user)):
    """Export monthly report to Excel"""
    import os
    from fastapi.responses import FileResponse
    
    session = db.get_session()
    try:
        exporter = Exporter(session, org_id=current_user["organization_id"])
        filename = f"monthly_report_{year}_{month:02d}.xlsx"
        output_path = os.path.join("data/exports", filename)
        exporter.export_monthly_report_to_excel(output_path, year, month)
        return FileResponse(output_path, filename=filename)
    finally:
        session.close()
