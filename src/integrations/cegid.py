"""Cegid (YourCegid / Loop) integration."""
import logging
from typing import List, Dict
from .base import BaseIntegration, IntegrationStatus, AccountingEntry, PushResult
from .registry import register

logger = logging.getLogger(__name__)


@register
class CegidIntegration(BaseIntegration):
    name = "cegid"
    display_name = "Cegid (Loop / YourCegid)"
    description = "Envoi des écritures via l'API Cegid Loop ou export au format d'import Cegid."
    supports_api = True
    config_fields = [
        {"key": "api_url", "label": "URL API Cegid", "type": "text", "required": True, "placeholder": "https://api.cegid.com/v1"},
        {"key": "api_key", "label": "Clé API", "type": "password", "required": True, "placeholder": ""},
        {"key": "company_code", "label": "Code société", "type": "text", "required": True, "placeholder": ""},
        {"key": "journal_code", "label": "Code journal (défaut: AC)", "type": "text", "required": False, "placeholder": "AC"},
    ]

    def test_connection(self) -> IntegrationStatus:
        api_url = self.config.get("api_url")
        api_key = self.config.get("api_key")
        if not api_url or not api_key:
            return IntegrationStatus.DISCONNECTED
        try:
            import requests
            resp = requests.get(
                f"{api_url}/companies",
                headers={"Authorization": f"Bearer {api_key}"},
                timeout=10,
            )
            return IntegrationStatus.CONNECTED if resp.status_code == 200 else IntegrationStatus.ERROR
        except Exception:
            return IntegrationStatus.ERROR

    def push_entries(self, entries: List[AccountingEntry]) -> PushResult:
        api_url = self.config.get("api_url")
        api_key = self.config.get("api_key")
        company_code = self.config.get("company_code")

        if not all([api_url, api_key, company_code]):
            return PushResult(success=False, entries_pushed=0, errors=["Configuration incomplète"])

        try:
            import requests
            headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}

            # Cegid expects entries grouped by piece
            payload = {
                "company_code": company_code,
                "entries": [
                    {
                        "journal_code": e.journal_code,
                        "date": e.date,
                        "piece_number": e.piece_ref,
                        "account": e.account_number,
                        "label": e.label,
                        "debit": e.debit,
                        "credit": e.credit,
                        "auxiliary_account": e.auxiliary_account,
                    }
                    for e in entries
                ]
            }

            resp = requests.post(
                f"{api_url}/companies/{company_code}/journal-entries",
                json=payload,
                headers=headers,
                timeout=30,
            )

            if resp.status_code in (200, 201):
                return PushResult(success=True, entries_pushed=len(entries), errors=[])
            return PushResult(success=False, entries_pushed=0, errors=[f"HTTP {resp.status_code}: {resp.text[:200]}"])

        except Exception as e:
            return PushResult(success=False, entries_pushed=0, errors=[str(e)])
