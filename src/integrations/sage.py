"""Sage Business Cloud Accounting API integration.
https://developer.sage.com/accounting/reference/
OAuth2 authorization_code flow — user must authenticate via browser.
"""
import logging
from typing import List
from .base import BaseIntegration, IntegrationStatus, AccountingEntry, PushResult
from .registry import register

logger = logging.getLogger(__name__)

AUTHORIZE_URL = "https://www.sageone.com/oauth2/auth/central?filter=apiv3.1"
TOKEN_URL = "https://oauth.accounting.sage.com/token"
API_BASE = "https://api.accounting.sage.com/v3.1"


@register
class SageIntegration(BaseIntegration):
    name = "sage"
    display_name = "Sage Business Cloud"
    description = "Envoi direct des écritures via l'API Sage Business Cloud Comptabilité."
    supports_api = True
    config_fields = [
        {"key": "client_id", "label": "Client ID (app Sage)", "type": "text", "required": True, "placeholder": ""},
        {"key": "client_secret", "label": "Client Secret", "type": "password", "required": True, "placeholder": ""},
        {"key": "access_token", "label": "Access Token", "type": "password", "required": False, "placeholder": "(auto via OAuth)"},
        {"key": "refresh_token", "label": "Refresh Token", "type": "password", "required": False, "placeholder": "(auto via OAuth)"},
    ]

    def _get_token(self) -> str | None:
        """Get valid access token, refreshing if needed."""
        access_token = self.config.get("access_token")
        refresh_token = self.config.get("refresh_token")

        if not access_token and not refresh_token:
            return None

        if access_token:
            return access_token

        if refresh_token:
            return self._refresh_access_token()

        return None

    def _refresh_access_token(self) -> str | None:
        """Refresh expired access token."""
        import requests

        client_id = self.config.get("client_id")
        client_secret = self.config.get("client_secret")
        refresh_token = self.config.get("refresh_token")

        if not all([client_id, client_secret, refresh_token]):
            return None

        resp = requests.post(TOKEN_URL, data={
            "grant_type": "refresh_token",
            "client_id": client_id,
            "client_secret": client_secret,
            "refresh_token": refresh_token,
        }, timeout=10)

        if resp.status_code == 200:
            data = resp.json()
            self.config["access_token"] = data["access_token"]
            if "refresh_token" in data:
                self.config["refresh_token"] = data["refresh_token"]
            return data["access_token"]

        logger.error(f"Sage token refresh failed: {resp.status_code}")
        return None

    def _headers(self, token: str) -> dict:
        return {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        }

    @staticmethod
    def get_authorize_url(client_id: str, redirect_uri: str, state: str = "") -> str:
        """Build OAuth2 authorize URL for user redirect."""
        params = f"response_type=code&client_id={client_id}&redirect_uri={redirect_uri}&scope=full_access"
        if state:
            params += f"&state={state}"
        return f"{AUTHORIZE_URL}&{params}"

    @staticmethod
    def exchange_code(client_id: str, client_secret: str, code: str, redirect_uri: str) -> dict | None:
        """Exchange authorization code for tokens."""
        import requests
        resp = requests.post(TOKEN_URL, data={
            "grant_type": "authorization_code",
            "client_id": client_id,
            "client_secret": client_secret,
            "code": code,
            "redirect_uri": redirect_uri,
        }, timeout=10)

        if resp.status_code == 200:
            return resp.json()
        return None

    def test_connection(self) -> IntegrationStatus:
        """Test Sage API connection."""
        token = self._get_token()
        if not token:
            return IntegrationStatus.DISCONNECTED

        try:
            import requests
            resp = requests.get(
                f"{API_BASE}/user",
                headers=self._headers(token),
                timeout=10,
            )
            if resp.status_code == 200:
                return IntegrationStatus.CONNECTED
            if resp.status_code == 401:
                new_token = self._refresh_access_token()
                if new_token:
                    resp2 = requests.get(f"{API_BASE}/user", headers=self._headers(new_token), timeout=10)
                    if resp2.status_code == 200:
                        return IntegrationStatus.CONNECTED
                return IntegrationStatus.DISCONNECTED
            return IntegrationStatus.ERROR
        except Exception as e:
            logger.error(f"Sage connection test failed: {e}")
            return IntegrationStatus.ERROR

    def push_entries(self, entries: List[AccountingEntry]) -> PushResult:
        """Push entries to Sage as journal entries.
        POST /journal_entries with transaction lines.
        """
        token = self._get_token()
        if not token:
            return PushResult(success=False, entries_pushed=0, errors=["Non connecté — token manquant"])

        try:
            import requests

            # Group by piece_ref
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

                payload = {
                    "journal_entry": {
                        "date": first.date,
                        "reference": piece_ref,
                        "description": first.label,
                        "journal_code_type": {"$key": first.journal_code or "AC"},
                        "transaction_lines": [
                            {
                                "ledger_account": {"nominal_code": line.account_number},
                                "description": line.label,
                                "debit": str(round(line.debit, 2)) if line.debit > 0 else None,
                                "credit": str(round(line.credit, 2)) if line.credit > 0 else None,
                            }
                            for line in lines
                        ],
                    }
                }

                resp = requests.post(
                    f"{API_BASE}/journal_entries",
                    json=payload,
                    headers=self._headers(token),
                    timeout=15,
                )

                if resp.status_code in (200, 201):
                    pushed += len(lines)
                elif resp.status_code == 401:
                    new_token = self._refresh_access_token()
                    if new_token:
                        resp2 = requests.post(
                            f"{API_BASE}/journal_entries",
                            json=payload,
                            headers=self._headers(new_token),
                            timeout=15,
                        )
                        if resp2.status_code in (200, 201):
                            pushed += len(lines)
                            token = new_token
                        else:
                            errors.append(f"{piece_ref}: {resp2.status_code}")
                    else:
                        errors.append(f"{piece_ref}: token expiré, refresh échoué")
                else:
                    error_msg = resp.text[:100] if resp.text else str(resp.status_code)
                    errors.append(f"{piece_ref}: {error_msg}")

            return PushResult(success=len(errors) == 0, entries_pushed=pushed, errors=errors)

        except Exception as e:
            return PushResult(success=False, entries_pushed=0, errors=[str(e)])
