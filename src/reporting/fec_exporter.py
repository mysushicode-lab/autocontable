"""
FEC (Fichier des Écritures Comptables) export functionality
"""
import os
from datetime import datetime
import calendar
from sqlalchemy.orm import Session
from src.storage.models import Invoice
from src.constants import PCG_COMPTES, DEFAULT_COMPTE, TVA_COMPTE, FOURN_COMPTE


class FECExporter:
    """FEC export functionality"""

    def __init__(self, session: Session, org_id: int = None):
        self.session = session
        self.org_id = org_id

    def _fetch_period_invoices(self, year: int, month: int):
        """Return invoices for the period, including cross-month matched invoices."""
        from src.storage.models import ReconciliationMatch, BankTransaction

        first_day = datetime(year, month, 1)
        last_day = datetime(year, month, calendar.monthrange(year, month)[1], 23, 59, 59)

        inv_q = self.session.query(Invoice).filter(Invoice.date >= first_day, Invoice.date <= last_day)
        if self.org_id:
            inv_q = inv_q.filter(Invoice.organization_id == self.org_id)
        invoices = inv_q.all()

        matches_q = self.session.query(ReconciliationMatch).join(Invoice).join(
            BankTransaction, ReconciliationMatch.transaction_id == BankTransaction.id
        ).filter(BankTransaction.date >= first_day, BankTransaction.date <= last_day)
        if self.org_id:
            matches_q = matches_q.filter(Invoice.organization_id == self.org_id)

        existing_ids = {inv.id for inv in invoices}
        extra = [m.invoice for m in matches_q if m.status != 'rejected' and m.invoice_id not in existing_ids]
        return first_day, last_day, invoices + extra

    def export_fec(self, year: int, month: int, siren: str = None) -> str:
        """
        Generate FEC-compliant export file (Fichier des Écritures Comptables).

        FEC format is required by French tax authorities (article A.47 A-1 du LPF).
        TAB-separated file with 18 columns, YYYYMMDD dates, comma decimal separator.

        Args:
            year: Year of the period
            month: Month of the period
            siren: SIREN number (9 digits, extracted from SIRET if available)

        Returns:
            Path to generated FEC file
        """
        _, _, all_invoices = self._fetch_period_invoices(year, month)

        # Use placeholder SIREN if not provided
        if not siren:
            siren = "000000000"

        # Determine closing date (last day of the month)
        last_day = datetime(year, month, calendar.monthrange(year, month)[1])
        closing_date_str = last_day.strftime('%Y%m%d')

        # Generate filename: {SIREN}FEC{YYYYMMDD}.txt
        filename = f"{siren}FEC{closing_date_str}.txt"
        from src.utils.paths import EXPORTS_DIR
        output_path = os.path.join(EXPORTS_DIR, f"org_{self.org_id}_{filename}")
        os.makedirs(os.path.dirname(output_path), exist_ok=True)

        fec_lines = []
        ecriture_counter = 1

        for inv in all_invoices:
            compte, libelle_compte = PCG_COMPTES.get(inv.category or '', DEFAULT_COMPTE)
            supplier = inv.supplier.name if inv.supplier else 'Fournisseur inconnu'
            supplier_id = str(inv.supplier_id) if inv.supplier_id else ''
            piece = inv.invoice_number or ''

            # Dates in YYYYMMDD format
            date_str = inv.date.strftime('%Y%m%d') if inv.date else ''
            piece_date_str = date_str  # invoice date = piece date
            valid_date_str = date_str  # validation date = invoice date

            tva = inv.amount_tax or 0
            ttc = inv.amount or 0
            ht = (inv.amount_ht or 0) or (ttc - tva)
            is_avoir = ttc < 0

            ecriture_num = f"AC-{str(ecriture_counter).zfill(6)}"
            libelle_base = f"{'Avoir' if is_avoir else 'Facture'} {supplier} — {piece}"

            # French locale: comma as decimal separator
            def format_amount(amount):
                return f"{abs(amount):.2f}".replace('.', ',')

            # Ligne 1: Compte de charge (6xx) — débit HT
            fec_lines.append([
                'AC',                           # JournalCode
                'Journal des achats',           # JournalLib
                ecriture_num,                   # EcritureNum
                date_str,                       # EcritureDate
                compte,                         # CompteNum
                libelle_compte,                 # CompteLib
                '',                             # CompAuxNum
                '',                             # CompAuxLib
                piece,                          # PieceRef
                piece_date_str,                 # PieceDate
                libelle_base,                   # EcritureLib
                format_amount(ht) if not is_avoir else '',  # Debit
                format_amount(ht) if is_avoir else '',      # Credit
                '',                             # EcritureLet
                '',                             # DateLet
                valid_date_str,                 # ValidDate
                '',                             # Montantdevise
                '',                             # Idevise
            ])

            # Ligne 2: TVA déductible (445660) — débit TVA
            if tva != 0:
                fec_lines.append([
                    'AC',
                    'Journal des achats',
                    ecriture_num,
                    date_str,
                    TVA_COMPTE[0],
                    TVA_COMPTE[1],
                    '',
                    '',
                    piece,
                    piece_date_str,
                    f"TVA — {libelle_base}",
                    format_amount(tva) if not is_avoir else '',
                    format_amount(tva) if is_avoir else '',
                    '',
                    '',
                    valid_date_str,
                    '',
                    '',
                ])

            # Ligne 3: Fournisseur (401000) — crédit TTC
            fec_lines.append([
                'AC',
                'Journal des achats',
                ecriture_num,
                date_str,
                FOURN_COMPTE[0],
                FOURN_COMPTE[1],
                supplier_id,                    # CompAuxNum (supplier code)
                supplier,                       # CompAuxLib (supplier name)
                piece,
                piece_date_str,
                f"Fournisseur — {supplier}",
                format_amount(ttc) if is_avoir else '',
                format_amount(ttc) if not is_avoir else '',
                '',
                '',
                valid_date_str,
                '',
                '',
            ])

            ecriture_counter += 1

        # Write FEC file: TAB-separated, UTF-8, no header
        with open(output_path, 'w', encoding='utf-8') as f:
            for line in fec_lines:
                f.write('\t'.join(line) + '\n')

        return output_path
