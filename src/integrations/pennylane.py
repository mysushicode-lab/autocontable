"""Pennylane API integration — push accounting entries directly.
https://pennylane.readme.io/reference
"""
import logging
from typing import List, Optional, Dict
from .base import BaseIntegration, IntegrationStatus, AccountingEntry, PushResult
from .registry import register

logger = logging.getLogger(__name__)

API_BASE = "https://app.pennylane.com/api/external/v2"


@register
class PennylaneIntegration(BaseIntegration):
    name = "pennylane"
    display_name = "Pennylane"
    description = "Envoi direct des écritures comptables via l'API Pennylane."
    supports_api = True
    config_fields = [
        {"key": "api_token", "label": "Token API Pennylane", "type": "password", "required": True, "placeholder": "pk_..."},
        {"key": "journal_code", "label": "Code journal (defaut: AC)", "type": "text", "required": False, "placeholder": "AC"},
    ]

    def _headers(self) -> dict:
        return {
            "Authorization": f"Bearer {self.config.get('api_token', '')}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        }

    def _resolve_journal_id(self, session, journal_code: str) -> Optional[int]:
        """Resolve journal code (e.g. 'AC') to Pennylane journal_id."""
        import requests
        resp = requests.get(
            f"{API_BASE}/journals",
            headers=self._headers(),
            timeout=10,
        )
        if resp.status_code != 200:
            return None
        for journal in resp.json().get("journals", []):
            if journal.get("code") == journal_code:
                return journal.get("id")
        return None

    def _resolve_account_id(self, account_number: str) -> Optional[int]:
        """Resolve PCG account number to Pennylane ledger_account_id."""
        import requests
        resp = requests.get(
            f"{API_BASE}/ledger_accounts",
            params={"filter": f'[{{"field":"number","operator":"eq","value":"{account_number}"}}]'},
            headers=self._headers(),
            timeout=10,
        )
        if resp.status_code != 200:
            return None
        accounts = resp.json().get("ledger_accounts", [])
        if accounts:
            return accounts[0].get("id")
        return None

    def test_connection(self) -> IntegrationStatus:
        """Test Pennylane API connection via GET /me."""
        if not self.config.get("api_token"):
            return IntegrationStatus.DISCONNECTED

        try:
            import requests
            resp = requests.get(
                f"{API_BASE}/me",
                headers=self._headers(),
                timeout=10,
            )
            if resp.status_code == 200:
                return IntegrationStatus.CONNECTED
            if resp.status_code == 401:
                return IntegrationStatus.DISCONNECTED
            return IntegrationStatus.ERROR
        except Exception as e:
            logger.error(f"Pennylane connection test failed: {e}")
            return IntegrationStatus.ERROR

    def push_entries(self, entries: List[AccountingEntry]) -> PushResult:
        """Push accounting entries to Pennylane as ledger entries.
        https://pennylane.readme.io/reference/post_api-external-v2-ledger-entries
        """
        if not self.config.get("api_token"):
            return PushResult(success=False, entries_pushed=0, errors=["Token API manquant"])

        try:
            import requests

            journal_code = self.config.get("journal_code", "AC")
            journal_id = self._resolve_journal_id(None, journal_code)
            if not journal_id:
                return PushResult(success=False, entries_pushed=0, errors=[f"Journal '{journal_code}' introuvable dans Pennylane"])

            # Cache account resolutions
            account_cache: Dict[str, Optional[int]] = {}

            # Group entries by piece_ref (one ledger entry = multiple lines)
            grouped = {}
            for entry in entries:
                key = entry.piece_ref or entry.entry_number
                if key not in grouped:
                    grouped[key] = []
                grouped[key].append(entry)

            pushed = 0
            errors = []

            for piece_ref, lines in grouped.items():
                first = lines[0]

                ledger_entry_lines = []
                has_resolution_error = False

                for line in lines:
                    if line.account_number not in account_cache:
                        account_cache[line.account_number] = self._resolve_account_id(line.account_number)

                    account_id = account_cache[line.account_number]
                    if not account_id:
                        errors.append(f"{piece_ref}: compte '{line.account_number}' introuvable dans Pennylane")
                        has_resolution_error = True
                        break

                    ledger_entry_lines.append({
                        "ledger_account_id": account_id,
                        "label": line.label,
                        "debit": f"{line.debit:.2f}" if line.debit > 0 else "0.00",
                        "credit": f"{line.credit:.2f}" if line.credit > 0 else "0.00",
                    })

                if has_resolution_error:
                    continue

                payload = {
                    "date": first.date,
                    "label": first.label,
                    "journal_id": journal_id,
                    "piece_number": piece_ref,
                    "currency": "EUR",
                    "ledger_entry_lines": ledger_entry_lines,
                }

                resp = requests.post(
                    f"{API_BASE}/ledger_entries",
                    json=payload,
                    headers=self._headers(),
                    timeout=15,
                )

                if resp.status_code in (200, 201):
                    pushed += len(lines)
                else:
                    error_msg = resp.json().get("error", resp.text[:100]) if resp.text else str(resp.status_code)
                    errors.append(f"{piece_ref}: {error_msg}")

            return PushResult(success=len(errors) == 0, entries_pushed=pushed, errors=errors)

        except Exception as e:
            return PushResult(success=False, entries_pushed=0, errors=[str(e)])
