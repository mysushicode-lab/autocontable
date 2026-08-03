"""Base class for accounting software integrations."""
from abc import ABC, abstractmethod
from enum import Enum
from typing import List, Dict, Optional
from dataclasses import dataclass


class IntegrationStatus(Enum):
    CONNECTED = "connected"
    DISCONNECTED = "disconnected"
    ERROR = "error"


@dataclass
class AccountingEntry:
    """Standardized accounting entry to push to any integration."""
    date: str  # YYYY-MM-DD
    journal_code: str  # e.g., "AC" (achats)
    entry_number: str  # e.g., "AC-000001"
    account_number: str  # PCG account (e.g., "601000")
    account_label: str
    auxiliary_account: str  # supplier code
    auxiliary_label: str  # supplier name
    piece_ref: str  # invoice number
    label: str  # entry description
    debit: float
    credit: float


@dataclass
class PushResult:
    """Result of pushing entries to an integration."""
    success: bool
    entries_pushed: int
    errors: List[str]
    external_id: Optional[str] = None  # ID in the target system


class BaseIntegration(ABC):
    """Base class for all accounting software integrations."""

    name: str = ""
    display_name: str = ""
    description: str = ""
    supports_api: bool = False  # True if real-time API push, False if file export
    config_fields: List[Dict] = []  # [{key, label, type, required, placeholder}]

    def __init__(self, config: Dict):
        """Initialize with dossier-specific configuration."""
        self.config = config

    @abstractmethod
    def test_connection(self) -> IntegrationStatus:
        """Test if the integration is properly configured and reachable."""
        pass

    @abstractmethod
    def push_entries(self, entries: List[AccountingEntry]) -> PushResult:
        """Push accounting entries to the target system."""
        pass

    def get_status(self) -> IntegrationStatus:
        """Get current connection status."""
        try:
            return self.test_connection()
        except Exception:
            return IntegrationStatus.ERROR
