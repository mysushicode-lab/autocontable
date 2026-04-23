# Système de Gestion Comptable pour Carrosserie Automobile

Système automatisé de traitement des factures fournisseurs et rapprochement bancaire, spécialement conçu pour les carrosseries automobiles. Centralise les factures, simplifie la comptabilité et élimine les tâches chronophages.

## Objectifs pour Carrosserie

- **Centraliser** toutes les factures fournisseurs (pièces, peinture, sous-traitance)
- **Matcher** automatiquement les factures avec les dépenses bancaires
- **Tracer** les commandes par véhicule (immatriculation, N° dossier)
- **Simplifier** la gestion comptable quotidienne

## Fonctionnalités Clés

### Gestion des Factures
- **Récupération Email** : Télécharge automatiquement les factures PDF des fournisseurs
- **Extraction Intelligente** : Numéro de facture, date, montant, TVA, N° commande, BL
- **Données Carrosserie** : Immatriculation véhicule, N° dossier/OT, mode de paiement

### Classification Auto (Spécifique Carrosserie)
- **Pièces détachées** : Carrosserie, mécanique, électricité
- **Peinture & Vernis** : Axalta, Cromax, Glasurit, Sikkens, etc.
- **Fournitures Atelier** : Consommables, abrasifs, protection
- **Sous-traitance** : Dépannage, expertise, contrôle technique
- **Équipement** : Outillage, machines, pont élévateur
- **Énergie & Locaux** : Électricité, loyer, charges
- **Assurances & Frais** : RC Pro, décennale, comptable

### Rapprochement Bancaire
- **Import Relevés** : CSV, OFX (toutes banques)
- **Matching Auto** : Correspondance facture ↔ virement bancaire
- **Détection Anomalies** : Factures non payées, paiements sans facture

### Reporting & Export
- **Tableau de Bord Mensuel** : Totaux par catégorie, par fournisseur
- **Export Comptable** : CSV, Excel pour votre expert-comptable
- **Suivi Immatriculations** : Historique des réparations par véhicule

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

## Usage Carrosserie

### Traitement Automatique des Factures
```python
from src.email_ingestion import EmailClient
from src.invoice_processor import InvoiceProcessor

# Récupère les factures des fournisseurs auto
email = EmailClient()
emails = email.fetch_invoices()  # Cherche : facture, BL, commande, avoir

# Extrait les données (y compris immatriculation, N° OT)
processor = InvoiceProcessor()
for email_data in emails:
    invoice_data = processor.process_invoice(email_data)
    # Données extraites : montant, TVA, N° commande, immatriculation, etc.
```

### Rapprochement Bancaire
```python
from src.bank_importer import BankImporter
from src.reconciliation import ReconciliationEngine

# Importe le relevé bancaire
csv_file = 'releve_bancaire_03-2024.csv'
bank = BankImporter()
transactions = bank.import_csv(csv_file)

# Rapproche automatique
engine = ReconciliationEngine()
matches = engine.reconcile(invoices, transactions)
# Détecte : factures payées, impayées, paiements sans facture
```

### Export pour Expert-Comptable
```python
from src.reporting.exporter import Exporter

exporter = Exporter(session)

# Export mensuel avec toutes les données
exporter.export_invoices_to_csv('export_mars_2024.csv', month=3, year=2024)
# Colonnes : Facture, Date, Fournisseur, Montant, TVA, Immatriculation, N° OT, etc.
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
- Database path
- OCR settings
- Bank statement format preferences

## License

MIT
