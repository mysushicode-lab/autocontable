"""Sage Business Cloud API integration."""
import logging
from typing import List, Dict
from .base import BaseIntegration, IntegrationStatus, AccountingEntry, PushResult
from .registry import register

logger = logging.getLogger(__name__)


@register
class SageIntegration(BaseIntegration):
    name = "sage"
    display_name = "Sage Business Cloud"
    description = "Envoi direct des écritures via l'API Sage Business Cloud Comptabilité."
    supports_api = True
    config_fields = [
        {"key": "client_id", "label": "Client ID (API Sage)", "type": "text", "required": True, "placeholder": "votre-client-id"},
        {"key": "client_secret", "label": "Client Secret", "type": "password", "required": True, "placeholder": ""},
        {"key": "company_id", "label": "ID Société Sage", "type": "text", "required": True, "placeholder": ""},
        {"key": "journal_code", "label": "Code journal (défaut: AC)", "type": "text", "required": False, "placeholder": "AC"},
    ]

    def test_connection(self) -> IntegrationStatus:
        """Test Sage API connection using OAuth2 client credentials."""
        client_id = self.config.get("client_id")
        client_secret = self.config.get("client_secret")
        if not client_id or not client_secret:
            return IntegrationStatus.DISCONNECTED

        try:
            import requests
            # Sage OAuth2 token endpoint
            token_resp = requests.post(
                "https://oauth.accounting.sage.com/token",
                data={
                    "grant_type": "client_credentials",
                    "client_id": client_id,
                    "client_secret": client_secret,
                    "scope": "full_access",
                },
                timeout=10,
            )
            if token_resp.status_code == 200:
                return IntegrationStatus.CONNECTED
            return IntegrationStatus.ERROR
        except Exception as e:
            logger.error(f"Sage connection test failed: {e}")
            return IntegrationStatus.ERROR

    def push_entries(self, entries: List[AccountingEntry]) -> PushResult:
        """Push entries to Sage via API."""
        client_id = self.config.get("client_id")
        client_secret = self.config.get("client_secret")
        company_id = self.config.get("company_id")

        if not all([client_id, client_secret, company_id]):
            return PushResult(success=False, entries_pushed=0, errors=["Configuration incomplète"])

        try:
            import requests

            # Get OAuth token
            token_resp = requests.post(
                "https://oauth.accounting.sage.com/token",
                data={
                    "grant_type": "client_credentials",
                    "client_id": client_id,
                    "client_secret": client_secret,
                    "scope": "full_access",
                },
                timeout=10,
            )
            if token_resp.status_code != 200:
                return PushResult(success=False, entries_pushed=0, errors=["Échec d'authentification Sage"])

            token = token_resp.json()["access_token"]
            headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}

            # Push entries as journal entries
            pushed = 0
            errors = []

            for entry in entries:
                payload = {
                    "journal": {"code": entry.journal_code},
                    "transaction_date": entry.date,
                    "reference": entry.piece_ref,
                    "description": entry.label,
                    "ledger_account": {"nominal_code": entry.account_number},
                    "debit": entry.debit if entry.debit > 0 else None,
                    "credit": entry.credit if entry.credit > 0 else None,
                }

                resp = requests.post(
                    f"https://api.accounting.sage.com/v3.1/journal_entries",
                    json=payload,
                    headers=headers,
                    timeout=10,
                )

                if resp.status_code in (200, 201):
                    pushed += 1
                else:
                    errors.append(f"Entrée {entry.piece_ref}: {resp.status_code} — {resp.text[:100]}")

            return PushResult(success=len(errors) == 0, entries_pushed=pushed, errors=errors)

        except Exception as e:
            return PushResult(success=False, entries_pushed=0, errors=[str(e)])
