"""Integration management endpoints."""
import os
import json
import logging
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import FileResponse
from typing import Optional
from datetime import datetime

from src.storage.database import db
from src.storage.models import ClientFile, Invoice, InvoiceStatus, Supplier, Settings
from src.api.auth import get_current_user
from src.api.billing import require_feature
from src.integrations import get_integration, list_integrations
from src.integrations.base import AccountingEntry
from src.constants import PCG_COMPTES, DEFAULT_COMPTE, TVA_COMPTE, FOURN_COMPTE
from src.api.pcg import get_pcg_for_dossier
from src.api.webhooks import fire_webhook

logger = logging.getLogger(__name__)
router = APIRouter()

# API integrations pending partner certification — users can see them but not configure
_COMING_SOON = {"sage", "cegid"}


@router.get("/available")
def get_available_integrations():
    """List all available integrations with their config requirements (public endpoint)."""
    integrations = list_integrations()
    for i in integrations:
        i["coming_soon"] = i["name"] in _COMING_SOON
    return {"integrations": integrations}


@router.get("/test-public")
def test_public_endpoint():
    """Test public endpoint without auth."""
    return {"status": "ok", "message": "Public endpoint works"}


@router.get("/status/{client_file_id}")
def get_integration_status(client_file_id: int, current_user: dict = Depends(get_current_user)):
    """Get the integration status for a specific dossier."""
    session = db.get_session()
    try:
        org_id = current_user["organization_id"]
        cf = session.query(ClientFile).filter(
            ClientFile.id == client_file_id,
            ClientFile.organization_id == org_id
        ).first()
        if not cf:
            raise HTTPException(404, "Dossier non trouvé")

        # Read integration config from settings
        config = _get_integration_config(session, org_id, client_file_id)
        if not config or not config.get("integration_name"):
            return {"configured": False, "integration": None}

        integration = get_integration(config["integration_name"], config)
        if not integration:
            return {"configured": False, "integration": None}

        status = integration.get_status()
        return {
            "configured": True,
            "integration": config["integration_name"],
            "display_name": integration.display_name,
            "status": status.value,
            "supports_api": integration.supports_api,
        }
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


@router.post("/configure/{client_file_id}")
def configure_integration(client_file_id: int, payload: dict, current_user: dict = Depends(get_current_user)):
    """Configure an integration for a dossier.

    payload: {"integration_name": "sage", "config": {"client_id": "...", ...}}
    """
    session = db.get_session()
    try:
        org_id = current_user["organization_id"]
        cf = session.query(ClientFile).filter(
            ClientFile.id == client_file_id,
            ClientFile.organization_id == org_id
        ).first()
        if not cf:
            raise HTTPException(404, "Dossier non trouvé")

        integration_name = payload.get("integration_name")
        config = payload.get("config", {})

        # Block coming soon integrations
        if integration_name in _COMING_SOON:
            raise HTTPException(400, f"L'intégration {integration_name} est en cours de certification partenaire. Disponible prochainement.")

        # Validate integration exists
        integration = get_integration(integration_name, config)
        if not integration:
            raise HTTPException(400, f"Intégration inconnue: {integration_name}")

        # Save config as settings (one key per field, prefixed)
        _save_integration_config(session, org_id, client_file_id, integration_name, config)

        # Test connection
        status = integration.get_status()

        return {
            "success": True,
            "status": status.value,
            "message": "Intégration configurée" if status.value == "connected" else "Configuration sauvegardée (connexion échouée)"
        }
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


@router.post("/push/{client_file_id}")
def push_entries(client_file_id: int, payload: dict = None, current_user: dict = Depends(get_current_user), request: Request = None):
    """Push validated accounting entries to the configured integration.

    payload (optional): {"year": 2026, "month": 1} — defaults to current month
    """
    session = db.get_session()
    try:
        org_id = current_user["organization_id"]
        cf = session.query(ClientFile).filter(
            ClientFile.id == client_file_id,
            ClientFile.organization_id == org_id
        ).first()
        if not cf:
            raise HTTPException(404, "Dossier non trouvé")

        # Get integration config
        config = _get_integration_config(session, org_id, client_file_id)
        if not config or not config.get("integration_name"):
            raise HTTPException(400, "Aucune intégration configurée pour ce dossier")

        integration = get_integration(config["integration_name"], config)
        if not integration:
            raise HTTPException(400, "Intégration non disponible")

        # Determine period
        now = datetime.utcnow()
        year = (payload or {}).get("year", now.year)
        month = (payload or {}).get("month", now.month)

        # Build accounting entries from confirmed invoices
        entries = _build_entries(session, org_id, client_file_id, year, month)

        if not entries:
            return {"success": True, "entries_pushed": 0, "message": "Aucune écriture à pousser pour cette période"}

        # Push
        result = integration.push_entries(entries)

        # Audit log
        try:
            from src.api.audit import log_action
            log_action(
                session, org_id, current_user["id"],
                "export", "integration",
                entity_id=client_file_id,
                details={
                    "integration": config["integration_name"],
                    "entries_pushed": result.entries_pushed,
                    "period": f"{year}-{month:02d}",
                    "success": result.success,
                },
                ip_address=request.client.host if request else None,
            )
        except Exception:
            pass

        # Fire webhook
        fire_webhook(org_id, "entries.pushed", {
            "client_file_id": client_file_id,
            "integration": config["integration_name"],
            "entries_pushed": result.entries_pushed,
            "period": f"{year}-{month:02d}",
            "success": result.success,
        })

        return {
            "success": result.success,
            "entries_pushed": result.entries_pushed,
            "errors": result.errors,
            "external_id": result.external_id,
        }
    finally:
        session.close()


@router.post("/test/{client_file_id}")
def test_integration(client_file_id: int, current_user: dict = Depends(get_current_user)):
    """Test the integration connection for a dossier."""
    session = db.get_session()
    try:
        org_id = current_user["organization_id"]
        config = _get_integration_config(session, org_id, client_file_id)
        if not config or not config.get("integration_name"):
            raise HTTPException(400, "Aucune intégration configurée")

        integration = get_integration(config["integration_name"], config)
        if not integration:
            raise HTTPException(400, "Intégration non disponible")

        status = integration.test_connection()
        return {"status": status.value, "integration": config["integration_name"]}
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


@router.get("/download/{client_file_id}")
def download_export_file(client_file_id: int, current_user: dict = Depends(get_current_user)):
    """Download the last generated export file (for file-based integrations)."""
    session = db.get_session()
    try:
        org_id = current_user["organization_id"]
        config = _get_integration_config(session, org_id, client_file_id)
        if not config or not config.get("integration_name"):
            raise HTTPException(400, "Aucune intégration configurée")

        integration = get_integration(config["integration_name"], config)
        if not integration or integration.supports_api:
            raise HTTPException(400, "Cette intégration n'utilise pas de fichier d'export")

        # Find the most recent export file for this integration
        # The external_id from push_entries contains the file path
        # For now, just check if the file exists based on integration type
        from src.utils.paths import EXPORTS_DIR
        export_dirs = {
            "acd": os.path.join(EXPORTS_DIR, "acd"),
            "quadratus": os.path.join(EXPORTS_DIR, "quadratus"),
            "fec": os.path.join(EXPORTS_DIR, "fec"),
        }

        export_dir = export_dirs.get(config["integration_name"])
        if not export_dir or not os.path.isdir(export_dir):
            raise HTTPException(404, "Aucun fichier d'export trouvé")

        import glob
        files = sorted(glob.glob(os.path.join(export_dir, "*")), key=os.path.getmtime, reverse=True)
        if not files:
            raise HTTPException(404, "Aucun fichier d'export trouvé")

        return FileResponse(files[0], filename=os.path.basename(files[0]))
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


# ─── Helpers ─────────────────────────────────────────────────────────────────

def _get_integration_config(session, org_id: int, client_file_id: int) -> dict:
    """Read integration config from settings for a specific dossier."""
    settings = session.query(Settings).filter(
        Settings.organization_id == org_id,
        Settings.key == f"integration_config_{client_file_id}",
        Settings.category == "integration",
    ).first()
    if not settings or not settings.value:
        return {}
    try:
        return json.loads(settings.value)
    except (json.JSONDecodeError, TypeError):
        return {}


def _save_integration_config(session, org_id: int, client_file_id: int, integration_name: str, config: dict):
    """Save integration config as a settings entry."""
    key = f"integration_config_{client_file_id}"
    full_config = {"integration_name": integration_name, **config}

    existing = session.query(Settings).filter(
        Settings.organization_id == org_id,
        Settings.key == key,
        Settings.category == "integration",
    ).first()

    if existing:
        existing.value = json.dumps(full_config)
    else:
        from src.storage.models import Settings as SettingsModel
        new_setting = SettingsModel(
            organization_id=org_id,
            key=key,
            value=json.dumps(full_config),
            category="integration",
        )
        session.add(new_setting)
    session.commit()


def _build_entries(session, org_id: int, client_file_id: int, year: int, month: int) -> list:
    """Build AccountingEntry list from confirmed invoices for the period."""
    from calendar import monthrange

    first_day = datetime(year, month, 1)
    last_day = datetime(year, month, monthrange(year, month)[1], 23, 59, 59)

    invoices = session.query(Invoice).filter(
        Invoice.organization_id == org_id,
        Invoice.client_file_id == client_file_id,
        Invoice.status.in_([InvoiceStatus.MATCHED, InvoiceStatus.PROCESSED]),
        Invoice.date >= first_day,
        Invoice.date <= last_day,
    ).all()

    # Get per-dossier PCG mapping
    pcg = get_pcg_for_dossier(session, org_id, client_file_id)

    entries = []
    counter = 1

    for inv in invoices:
        compte, libelle_compte = pcg["comptes"].get(inv.category or '', pcg["default"])
        supplier_name = inv.supplier.name if inv.supplier else 'Fournisseur inconnu'
        supplier_id = str(inv.supplier_id) if inv.supplier_id else ''
        piece = inv.invoice_number or ''
        date_str = inv.date.strftime('%Y-%m-%d') if inv.date else ''

        tva = inv.amount_tax or 0
        ttc = inv.amount or 0
        ht = (inv.amount_ht or 0) or (ttc - tva)
        is_avoir = ttc < 0

        entry_num = f"AC-{str(counter).zfill(6)}"
        label = f"{'Avoir' if is_avoir else 'Facture'} {supplier_name} — {piece}"

        # Line 1: Charge account (debit HT)
        entries.append(AccountingEntry(
            date=date_str,
            journal_code="AC",
            entry_number=entry_num,
            account_number=compte,
            account_label=libelle_compte,
            auxiliary_account="",
            auxiliary_label="",
            piece_ref=piece,
            label=label,
            debit=abs(ht) if not is_avoir else 0,
            credit=abs(ht) if is_avoir else 0,
        ))

        # Line 2: TVA (debit TVA)
        if tva:
            entries.append(AccountingEntry(
                date=date_str,
                journal_code="AC",
                entry_number=entry_num,
                account_number=pcg["tva"][0],
                account_label=pcg["tva"][1],
                auxiliary_account="",
                auxiliary_label="",
                piece_ref=piece,
                label=f"TVA — {label}",
                debit=abs(tva) if not is_avoir else 0,
                credit=abs(tva) if is_avoir else 0,
            ))

        # Line 3: Supplier (credit TTC)
        entries.append(AccountingEntry(
            date=date_str,
            journal_code="AC",
            entry_number=entry_num,
            account_number=pcg["fournisseur"][0],
            account_label=pcg["fournisseur"][1],
            auxiliary_account=supplier_id,
            auxiliary_label=supplier_name,
            piece_ref=piece,
            label=f"Fournisseur — {supplier_name}",
            debit=abs(ttc) if is_avoir else 0,
            credit=abs(ttc) if not is_avoir else 0,
        ))

        counter += 1

    return entries
