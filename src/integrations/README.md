# Integrations Framework

This directory contains the integrations framework for pushing accounting entries to external accounting software.

## Architecture

### Core Components

1. **`base.py`** - Abstract base class defining the integration interface:
   - `BaseIntegration` - Base class all integrations inherit from
   - `AccountingEntry` - Standardized entry format
   - `PushResult` - Result structure from push operations
   - `IntegrationStatus` - Connection status enum

2. **`registry.py`** - Integration registry system:
   - `@register` decorator - Auto-registers integrations
   - `get_integration(name, config)` - Gets integration instance
   - `list_integrations()` - Lists all available integrations

3. **`__init__.py`** - Package initialization that imports all integrations to register them

### Integrations

#### API-based (Real-time push)
- **`sage.py`** - Sage Business Cloud (OAuth2 API)
- **`cegid.py`** - Cegid Loop / YourCegid (REST API)

#### File-based (Export for manual import)
- **`acd.py`** - ACD/Coala (CSV format)
- **`quadratus.py`** - Quadratus (fixed-width text format)
- **`fec_export.py`** - Generic FEC export (TSV format)

## API Endpoints

All endpoints are under `/api/integrations`:

- `GET /available` - List all available integrations with config requirements
- `GET /status/{client_file_id}` - Get integration status for a dossier
- `POST /configure/{client_file_id}` - Configure integration for a dossier
- `POST /test/{client_file_id}` - Test connection
- `POST /push/{client_file_id}` - Push entries to configured integration
- `GET /download/{client_file_id}` - Download generated export file (file-based only)

## Usage Example

### Python API

```python
from src.integrations import get_integration, list_integrations
from src.integrations.base import AccountingEntry

# List available integrations
integrations = list_integrations()

# Create integration instance
sage = get_integration("sage", {
    "client_id": "your-client-id",
    "client_secret": "your-secret",
    "company_id": "123"
})

# Test connection
status = sage.test_connection()
print(f"Status: {status.value}")

# Push entries
entries = [
    AccountingEntry(
        date="2026-07-31",
        journal_code="AC",
        entry_number="AC-000001",
        account_number="607000",
        account_label="Achats de marchandises",
        auxiliary_account="FOURNISSEUR123",
        auxiliary_label="Fournisseur Test",
        piece_ref="FAC-2026-001",
        label="Facture Test",
        debit=1000.0,
        credit=0.0
    )
]

result = sage.push_entries(entries)
print(f"Success: {result.success}, Pushed: {result.entries_pushed}")
```

### REST API

```bash
# List available integrations
curl http://localhost:8000/api/integrations/available

# Configure Sage for dossier 1
curl -X POST http://localhost:8000/api/integrations/configure/1 \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "integration_name": "sage",
    "config": {
      "client_id": "your-client-id",
      "client_secret": "your-secret",
      "company_id": "123"
    }
  }'

# Push entries for current month
curl -X POST http://localhost:8000/api/integrations/push/1 \
  -H "Authorization: Bearer YOUR_TOKEN"

# Push entries for specific period
curl -X POST http://localhost:8000/api/integrations/push/1 \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"year": 2026, "month": 7}'
```

## Adding a New Integration

1. Create a new file (e.g., `mysoft.py`)
2. Import base classes and register decorator:
   ```python
   from .base import BaseIntegration, IntegrationStatus, AccountingEntry, PushResult
   from .registry import register
   ```
3. Define your integration class with the `@register` decorator:
   ```python
   @register
   class MySoftIntegration(BaseIntegration):
       name = "mysoft"
       display_name = "My Accounting Software"
       description = "Integration description"
       supports_api = True  # or False for file-based
       config_fields = [
           {"key": "api_key", "label": "API Key", "type": "password", "required": True, "placeholder": ""},
       ]
       
       def test_connection(self) -> IntegrationStatus:
           # Test connection logic
           pass
       
       def push_entries(self, entries: List[AccountingEntry]) -> PushResult:
           # Push logic
           pass
   ```
4. Import it in `__init__.py`:
   ```python
   from . import mysoft
   ```

## Data Flow

1. User configures integration via `/api/integrations/configure/{client_file_id}`
2. Configuration stored in `settings` table with key `integration_config_{client_file_id}`
3. When pushing entries:
   - System fetches all MATCHED/PROCESSED invoices for the period
   - Converts them to standardized `AccountingEntry` format
   - Calls integration's `push_entries()` method
   - For API integrations: pushes directly to external system
   - For file integrations: generates export file in `data/exports/{integration}/`
4. Audit log created with push results

## Configuration Storage

Integration configs are stored in the `settings` table:
- **key**: `integration_config_{client_file_id}`
- **category**: `integration`
- **value**: JSON with `{"integration_name": "...", ...config fields}`

## Export Directories

File-based integrations generate files in:
- `data/exports/acd/` - ACD CSV files
- `data/exports/quadratus/` - Quadratus text files
- `data/exports/fec/` - FEC files
