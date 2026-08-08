"""Integration configuration and accounting entry helpers."""
import json
import logging
from datetime import datetime
from calendar import monthrange

from src.storage.models import Settings, Invoice, InvoiceStatus
from src.integrations.base import AccountingEntry
from src.api.pcg import get_pcg_for_dossier

logger = logging.getLogger(__name__)


def get_integration_config(session, org_id: int, client_file_id: int) -> dict:
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


def save_integration_config(session, org_id: int, client_file_id: int, integration_name: str, config: dict):
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


def build_entries(session, org_id: int, client_file_id: int, year: int, month: int) -> list:
    """Build AccountingEntry list from confirmed invoices for the period.

    Creates double-entry accounting lines:
    - Line 1: Charge account (HT)
    - Line 2: VAT account (if applicable)
    - Line 3: Supplier account (TTC)

    Args:
        session: Database session
        org_id: Organization ID
        client_file_id: Dossier ID
        year: Year of entries to export
        month: Month of entries to export (1-12)

    Returns:
        List of AccountingEntry objects ready for integration push
    """
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
