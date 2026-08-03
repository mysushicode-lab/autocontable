"""Reporting endpoints"""
from fastapi import APIRouter, Depends, Request
from sqlalchemy.orm import Session
from typing import Optional
import os
import glob
from datetime import datetime

from src.storage.database import db
from src.reporting.report_generator import ReportGenerator
from src.reporting.exporter import Exporter
from src.api.auth import get_current_user
from src.api.audit import log_action
from src.utils.paths import EXPORTS_DIR

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
    current_user: dict = Depends(get_current_user),
    request: Request = None
):
    """Export invoices to CSV"""
    import os
    from fastapi.responses import FileResponse
    from datetime import datetime

    session = db.get_session()
    try:
        org_id = current_user["organization_id"]
        exporter = Exporter(session, org_id=org_id)
        os.makedirs(EXPORTS_DIR, exist_ok=True)
        filename = f"invoices_{year or datetime.now().year}_{month or datetime.now().month}.csv"
        # Scope output path by organization to avoid collisions between tenants
        output_path = os.path.join(EXPORTS_DIR, f"org_{org_id}_{filename}")
        exporter.export_invoices_to_csv(output_path, month, year)

        # Log audit trail
        ip_address = request.client.host if request else None
        log_action(
            session,
            org_id,
            current_user["id"],
            "export",
            "invoice",
            None,
            {"format": "csv", "year": year, "month": month},
            ip_address
        )

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
        org_id = current_user["organization_id"]
        exporter = Exporter(session, org_id=org_id)
        os.makedirs(EXPORTS_DIR, exist_ok=True)
        filename = f"transactions_{year or datetime.now().year}_{month or datetime.now().month}.csv"
        output_path = os.path.join(EXPORTS_DIR, f"org_{org_id}_{filename}")
        exporter.export_transactions_to_csv(output_path, month, year)
        return FileResponse(output_path, filename=filename)
    finally:
        session.close()


@router.get("/export/dossier")
def export_dossier_zip(year: int, month: int, current_user: dict = Depends(get_current_user), request: Request = None):
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

        os.makedirs(EXPORTS_DIR, exist_ok=True)
        zip_filename = f"dossier_comptable_{year}_{month:02d}.zip"
        zip_path = os.path.join(EXPORTS_DIR, f"org_{org_id}_{zip_filename}")

        exporter = Exporter(session, org_id=org_id)
        excel_filename = f"rapport_{year}_{month:02d}.xlsx"
        excel_path = os.path.join(EXPORTS_DIR, f"org_{org_id}_{excel_filename}")
        exporter.export_monthly_report_to_excel(excel_path, year, month)

        def safe_name(s: str) -> str:
            return re.sub(r'[\\/:*?"<>|]', '_', s or '')

        safe_data_root = os.path.realpath("data")

        def _safe_file(p):
            """Return realpath if within data/, else None."""
            r = os.path.realpath(p if os.path.isabs(p) else os.path.join(os.getcwd(), p.lstrip('/\\')))
            return r if r.startswith(safe_data_root + os.sep) and os.path.exists(r) else None

        with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zf:
            zf.write(excel_path, excel_filename)
            for inv in invoices:
                file_path = _safe_file(inv.file_path) if inv.file_path else None
                if file_path:
                    ext = os.path.splitext(file_path)[1].lower() or '.pdf'
                    date_str = inv.date.strftime('%Y%m%d') if inv.date else 'nodate'
                    supplier_str = safe_name(inv.supplier.name if inv.supplier else 'inconnu')
                    inv_num = safe_name(inv.invoice_number or 'nofacture')
                    arcname = f"factures/{date_str}_{supplier_str}_{inv_num}{ext}"
                    zf.write(file_path, arcname)

        # Log audit trail
        ip_address = request.client.host if request else None
        log_action(
            session,
            org_id,
            current_user["id"],
            "export",
            "invoice",
            None,
            {"format": "zip", "year": year, "month": month, "count": len(invoices)},
            ip_address
        )

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
        org_id = current_user["organization_id"]
        exporter = Exporter(session, org_id=org_id)
        os.makedirs(EXPORTS_DIR, exist_ok=True)
        filename = f"monthly_report_{year}_{month:02d}.xlsx"
        output_path = os.path.join(EXPORTS_DIR, f"org_{org_id}_{filename}")
        exporter.export_monthly_report_to_excel(output_path, year, month)
        return FileResponse(output_path, filename=filename)
    finally:
        session.close()


@router.get("/export/grand-livre")
def export_grand_livre_excel(year: int, month: int, current_user: dict = Depends(get_current_user)):
    """Export Grand Livre to Excel"""
    import os
    from fastapi.responses import FileResponse
    
    session = db.get_session()
    try:
        org_id = current_user["organization_id"]
        exporter = Exporter(session, org_id=org_id)
        os.makedirs(EXPORTS_DIR, exist_ok=True)
        filename = f"grand_livre_{year}_{month:02d}.xlsx"
        output_path = os.path.join(EXPORTS_DIR, f"org_{org_id}_{filename}")
        exporter.export_grand_livre_to_excel(output_path, year, month)
        return FileResponse(output_path, filename=filename)
    finally:
        session.close()


@router.get("/export/balance")
def export_balance_excel(year: int, month: int, current_user: dict = Depends(get_current_user)):
    """Export Balance to Excel"""
    import os
    from fastapi.responses import FileResponse

    session = db.get_session()
    try:
        org_id = current_user["organization_id"]
        exporter = Exporter(session, org_id=org_id)
        os.makedirs(EXPORTS_DIR, exist_ok=True)
        filename = f"balance_{year}_{month:02d}.xlsx"
        output_path = os.path.join(EXPORTS_DIR, f"org_{org_id}_{filename}")
        exporter.export_balance_to_excel(output_path, year, month)
        return FileResponse(output_path, filename=filename)
    finally:
        session.close()


@router.get("/export/fec")
def export_fec(year: int, month: int, current_user: dict = Depends(get_current_user), request: Request = None):
    """Export FEC (Fichier des Écritures Comptables) for DGFiP"""
    import os
    from fastapi.responses import FileResponse
    from src.storage.models import ClientFile

    session = db.get_session()
    try:
        org_id = current_user["organization_id"]
        exporter = Exporter(session, org_id=org_id)

        # Try to get SIREN from active client file
        siren = None
        client_file = session.query(ClientFile).filter(
            ClientFile.organization_id == org_id,
            ClientFile.is_active == True
        ).first()

        if client_file and client_file.siret:
            # SIREN is the first 9 digits of SIRET
            siren = client_file.siret[:9] if len(client_file.siret) >= 9 else None

        # Generate FEC file
        os.makedirs(EXPORTS_DIR, exist_ok=True)
        file_path = exporter.export_fec(year, month, siren)

        # Extract filename from path for response
        filename = os.path.basename(file_path)

        # Log audit trail
        ip_address = request.client.host if request else None
        log_action(
            session,
            org_id,
            current_user["id"],
            "export",
            "fec",
            None,
            {"format": "fec", "year": year, "month": month, "siren": siren or "000000000"},
            ip_address
        )

        return FileResponse(file_path, media_type="text/plain; charset=utf-8", filename=filename)
    finally:
        session.close()


@router.get("/backup-status")
def get_backup_status(current_user: dict = Depends(get_current_user)):
    """Get backup status (most recent backup info)."""
    backup_dir = os.getenv('BACKUP_DIR', '/app/backups')
    if not os.path.isdir(backup_dir):
        return {"has_backups": False, "message": "No backup directory found"}

    backups = sorted(glob.glob(os.path.join(backup_dir, "autocontable_backup_*.tar.gz")), reverse=True)
    if not backups:
        return {"has_backups": False, "message": "No backups found"}

    latest = backups[0]
    stat = os.stat(latest)
    return {
        "has_backups": True,
        "latest_backup": os.path.basename(latest),
        "latest_date": datetime.fromtimestamp(stat.st_mtime).isoformat(),
        "size_mb": round(stat.st_size / (1024 * 1024), 2),
        "total_backups": len(backups),
    }
