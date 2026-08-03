"""Quadratus integration — generates .qcompta import file."""
import os
import logging
from typing import List
from .base import BaseIntegration, IntegrationStatus, AccountingEntry, PushResult
from .registry import register

logger = logging.getLogger(__name__)


@register
class QuadratusIntegration(BaseIntegration):
    name = "quadratus"
    display_name = "Quadratus (Cegid Quadra)"
    description = "Génère un fichier au format Quadratus (.txt) importable dans QuadraCompta."
    supports_api = False
    config_fields = [
        {"key": "code_dossier", "label": "Code dossier Quadratus", "type": "text", "required": True, "placeholder": ""},
        {"key": "journal_code", "label": "Code journal (défaut: AC)", "type": "text", "required": False, "placeholder": "AC"},
    ]

    def test_connection(self) -> IntegrationStatus:
        if self.config.get("code_dossier"):
            return IntegrationStatus.CONNECTED
        return IntegrationStatus.DISCONNECTED

    def push_entries(self, entries: List[AccountingEntry]) -> PushResult:
        """Generate Quadratus-format import file.

        Quadratus format: fixed-width text file
        M = mouvement line
        Positions: Type(1) + JournalCode(2) + Date(6,DDMMYY) + Filler(1) + Compte(8) + Libelle(25) + Sens(1,D/C) + Montant(13,centimes) + PieceRef(8)
        """
        code_dossier = self.config.get("code_dossier", "")
        if not code_dossier:
            return PushResult(success=False, entries_pushed=0, errors=["Code dossier manquant"])

        try:
            output_dir = os.path.join("data", "exports", "quadratus")
            os.makedirs(output_dir, exist_ok=True)

            filename = f"quadra_{code_dossier}.txt"
            filepath = os.path.join(output_dir, filename)

            with open(filepath, 'w', encoding='ascii', errors='replace') as f:
                for e in entries:
                    # Date: DDMMYY
                    parts = e.date.split('-')
                    date_str = f"{parts[2]}{parts[1]}{parts[0][2:]}" if len(parts) == 3 else "010126"

                    journal = (e.journal_code or "AC")[:2].ljust(2)
                    compte = (e.account_number or "")[:8].ljust(8)
                    libelle = (e.label or "")[:25].ljust(25)

                    if e.debit > 0:
                        sens = "D"
                        montant = int(round(e.debit * 100))
                    else:
                        sens = "C"
                        montant = int(round(e.credit * 100))

                    montant_str = str(montant).rjust(13, '0')
                    piece = (e.piece_ref or "")[:8].ljust(8)

                    line = f"M{journal}{date_str} {compte}{libelle}{sens}{montant_str}{piece}"
                    f.write(line + "\n")

            return PushResult(
                success=True,
                entries_pushed=len(entries),
                errors=[],
                external_id=filepath,
            )
        except Exception as e:
            return PushResult(success=False, entries_pushed=0, errors=[str(e)])
