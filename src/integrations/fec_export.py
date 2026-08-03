"""FEC export integration — fallback for software without API."""
import os
import logging
from typing import List
from .base import BaseIntegration, IntegrationStatus, AccountingEntry, PushResult
from .registry import register

logger = logging.getLogger(__name__)


@register
class FECIntegration(BaseIntegration):
    name = "fec"
    display_name = "Export FEC (générique)"
    description = "Génère un fichier FEC standard importable dans tout logiciel comptable français."
    supports_api = False
    config_fields = [
        {"key": "siren", "label": "SIREN (9 chiffres)", "type": "text", "required": False, "placeholder": "123456789"},
        {"key": "journal_code", "label": "Code journal (défaut: AC)", "type": "text", "required": False, "placeholder": "AC"},
    ]

    def test_connection(self) -> IntegrationStatus:
        return IntegrationStatus.CONNECTED

    def push_entries(self, entries: List[AccountingEntry]) -> PushResult:
        """Generate FEC file from entries."""
        siren = self.config.get("siren", "000000000")

        try:
            from datetime import datetime
            output_dir = os.path.join("data", "exports", "fec")
            os.makedirs(output_dir, exist_ok=True)

            today = datetime.utcnow().strftime('%Y%m%d')
            filename = f"{siren}FEC{today}.txt"
            filepath = os.path.join(output_dir, filename)

            with open(filepath, 'w', encoding='utf-8') as f:
                for e in entries:
                    date_fec = e.date.replace('-', '') if e.date else ''
                    debit_str = f"{e.debit:.2f}".replace('.', ',') if e.debit else "0,00"
                    credit_str = f"{e.credit:.2f}".replace('.', ',') if e.credit else "0,00"

                    fields = [
                        e.journal_code,           # JournalCode
                        "Journal des achats",     # JournalLib
                        e.entry_number,           # EcritureNum
                        date_fec,                 # EcritureDate
                        e.account_number,         # CompteNum
                        e.account_label,          # CompteLib
                        e.auxiliary_account,      # CompAuxNum
                        e.auxiliary_label,        # CompAuxLib
                        e.piece_ref,              # PieceRef
                        date_fec,                 # PieceDate
                        e.label,                  # EcritureLib
                        debit_str,                # Debit
                        credit_str,               # Credit
                        "",                       # EcritureLet
                        "",                       # DateLet
                        date_fec,                 # ValidDate
                        "",                       # Montantdevise
                        "",                       # Idevise
                    ]
                    f.write("\t".join(fields) + "\n")

            return PushResult(
                success=True,
                entries_pushed=len(entries),
                errors=[],
                external_id=filepath,
            )
        except Exception as e:
            return PushResult(success=False, entries_pushed=0, errors=[str(e)])
