"""ACD integration — file-based import (no API)."""
import os
import logging
from typing import List
from .base import BaseIntegration, IntegrationStatus, AccountingEntry, PushResult
from .registry import register

logger = logging.getLogger(__name__)


@register
class ACDIntegration(BaseIntegration):
    name = "acd"
    display_name = "ACD (Coala)"
    description = "Génère un fichier d'import au format ACD/Coala. Le comptable l'importe manuellement dans ACD."
    supports_api = False
    config_fields = [
        {"key": "code_dossier", "label": "Code dossier ACD", "type": "text", "required": True, "placeholder": "DOS001"},
        {"key": "journal_code", "label": "Code journal (défaut: AC)", "type": "text", "required": False, "placeholder": "AC"},
    ]

    def test_connection(self) -> IntegrationStatus:
        # File-based: always "connected" if config is provided
        if self.config.get("code_dossier"):
            return IntegrationStatus.CONNECTED
        return IntegrationStatus.DISCONNECTED

    def push_entries(self, entries: List[AccountingEntry]) -> PushResult:
        """Generate ACD import file (CSV format expected by ACD)."""
        code_dossier = self.config.get("code_dossier", "")
        if not code_dossier:
            return PushResult(success=False, entries_pushed=0, errors=["Code dossier manquant"])

        try:
            output_dir = os.path.join("data", "exports", "acd")
            os.makedirs(output_dir, exist_ok=True)

            # ACD import format: semicolon-separated
            # Columns: CodeDossier;CodeJournal;Date;Compte;Libelle;Debit;Credit;PieceRef
            filename = f"acd_import_{code_dossier}.csv"
            filepath = os.path.join(output_dir, filename)

            with open(filepath, 'w', encoding='utf-8-sig') as f:
                f.write("CodeDossier;CodeJournal;Date;NumCompte;Libelle;Debit;Credit;PieceRef\n")
                for e in entries:
                    date_formatted = e.date.replace('-', '')  # YYYYMMDD
                    debit_str = f"{e.debit:.2f}".replace('.', ',') if e.debit else "0,00"
                    credit_str = f"{e.credit:.2f}".replace('.', ',') if e.credit else "0,00"
                    f.write(f"{code_dossier};{e.journal_code};{date_formatted};{e.account_number};{e.label};{debit_str};{credit_str};{e.piece_ref}\n")

            return PushResult(
                success=True,
                entries_pushed=len(entries),
                errors=[],
                external_id=filepath,
            )
        except Exception as e:
            return PushResult(success=False, entries_pushed=0, errors=[str(e)])
