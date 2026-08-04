# Autocontable – Gestion Comptable pour Cabinets

Système automatisé de traitement des factures fournisseurs et rapprochement bancaire pour cabinets comptables. Centralise, classe et rapproche les factures de vos clients. Élimine la saisie manuelle et prépare des dossiers audités en 48h.

## Objectifs

- **Centraliser** les factures de tous vos clients
- **Automatiser** l'extraction (montant, TVA, date, fournisseur)
- **Matcher** automatiquement les factures avec les relevés bancaires
- **Exporter** des dossiers audités (FEC, Excel, prêts pour l'audit)

## Fonctionnalités Clés

### Gestion des Factures
- **Récupération Email** : Télécharge automatiquement les factures PDF des fournisseurs
- **WhatsApp Business** : Vos clients envoient leurs factures par WhatsApp (photos/PDF) — traitement automatique
- **Extraction Intelligente** : Numéro de facture, date, montant, TVA, N° commande, BL, fournisseur

### Classification Auto (Adaptation par Secteur)
- **Frais généraux** : Loyer, électricité, téléphone, internet
- **Fournitures** : Consommables, fournitures bureau
- **Sous-traitance** : Services externes, expertise
- **Équipement** : Outillage, matériel informatique
- **Assurances & Frais** : RC Pro, assurances, comptable
- Et plus (15+ catégories adaptables)

### Rapprochement Bancaire
- **Import Relevés** : CSV, OFX (toutes banques)
- **Matching Auto** : Correspondance facture ↔ virement bancaire
- **Détection Anomalies** : Factures non payées, paiements sans facture

### Reporting & Export
- **Tableau de Bord Mensuel** : Totaux par catégorie, par fournisseur
- **Export Comptable** : CSV, Excel, FEC pour transmission audit
- **Audit Trail** : Traçabilité complète de chaque opération

## Architecture

```
src/
├── email_ingestion/     # Email client & attachment download
├── invoice_processor/   # PDF parsing & OCR
├── classifier/          # Supplier detection & categorization
├── bank_importer/       # Bank statement parsers
├── reconciliation/      # Invoice ↔ transaction matching
├── storage/             # Database models & CRUD
├── reporting/           # Aggregation & export
├── api/                 # REST API endpoints
└── scheduler/           # Automated periodic tasks
```

## Database Support

Autocontable supports both **SQLite** (default, for development) and **PostgreSQL** (recommended for production with concurrent users).

### SQLite (Default)
- No setup required
- Single file database at `data/accounting.db`
- Perfect for development and single-user deployments

### PostgreSQL (Production)
- Better performance with multiple concurrent users
- Connection pooling and optimized queries
- Easy migration from SQLite

To use PostgreSQL, set the `DATABASE_URL` environment variable:
```bash
DATABASE_URL=postgresql://user:password@host:5432/dbname
```

See `scripts/README.md` for migration instructions from SQLite to PostgreSQL.

## Setup

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Install Tesseract OCR:
- Windows: Download from https://github.com/UB-Mannheim/tesseract/wiki
- macOS: `brew install tesseract`
- Linux: `sudo apt-get install tesseract-ocr`

3. Configure environment:
```bash
cp config/.env.example config/.env
# Edit config/.env with your credentials
```

4. Initialize database:
```bash
python -m src.storage.init_db
```

5. Run scheduler:
```bash
python -m src.scheduler.main
```

6. Run API server:
```bash
uvicorn src.api.main:app --reload
```

## Usage – Cabinet Comptable

### Traitement Automatique des Factures Clients
```python
from src.email_ingestion import IMAPClient
from src.invoice_processor import InvoiceProcessor

# Récupère les factures de tous vos clients
email = IMAPClient(server='imap.gmail.com', port=993, email='user@example.com', password='pass', folder='INBOX')
emails = email.fetch_emails(search_subject='facture', mark_as_read=True)

# Extrait automatiquement : numéro, date, montant, TVA, fournisseur
processor = InvoiceProcessor()
for email_data in emails:
    invoice_data = processor.process_invoice(email_data)
    # Données extraites : montant HT/TTC, TVA, date, fournisseur, etc.
```

### Rapprochement Bancaire Clients
```python
from src.bank_importer import BankImporter
from src.reconciliation import ReconciliationEngine

# Importe les relevés bancaires de vos clients
bank = BankImporter()
transactions = bank.import_csv('releve_client_mars_2024.csv')

# Rapproche automatique
engine = ReconciliationEngine()
matches = engine.reconcile(invoices, transactions)
# Détecte : factures payées, impayées, anomalies
```

### Export Dossier Client Complet
```python
from src.reporting.exporter import Exporter

exporter = Exporter(session)

# Export audit-ready : FEC, grand livre, journal
exporter.export_invoices_to_csv('dossier_client_mars_2024.csv', month=3, year=2024)
# Prêt pour transmission audit/expert
```

## API Endpoints

- `GET /api/invoices` - List all invoices
- `POST /api/invoices/process` - Process new invoices
- `GET /api/reconciliation` - Get reconciliation status
- `GET /api/reports/monthly` - Monthly totals
- `GET /api/export/csv` - Export to CSV

## Configuration

Edit `config/.env`:
- Email credentials (IMAP/Gmail)
- WhatsApp Business API (optional - see below)
- Database path
- OCR settings
- Bank statement format preferences

### WhatsApp Business Setup (Optional)

To enable WhatsApp invoice ingestion:

1. Create a WhatsApp Business account via Meta for Developers
2. Get your credentials from the Meta Business Suite:
   - Phone Number ID
   - Access Token
   - Verify Token (choose your own secret)

3. Add to `.env`:
```bash
WHATSAPP_VERIFY_TOKEN=your-verify-token
WHATSAPP_API_TOKEN=your-meta-api-token
WHATSAPP_PHONE_NUMBER_ID=your-phone-number-id
```

4. Configure webhook in Meta dashboard:
   - Webhook URL: `https://your-domain.com/api/whatsapp/webhook`
   - Verify token: same as `WHATSAPP_VERIFY_TOKEN`
   - Subscribe to: `messages`

5. Map client phone numbers to dossiers via Settings UI or API:
```bash
POST /api/whatsapp/mappings
{"phone": "33612345678", "client_file_id": 42}
```

Clients send invoices → WhatsApp webhook → automatic processing → appears in their dossier.

## License

MIT
