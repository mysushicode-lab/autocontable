"""
Script de données factices pour le dashboard factpilot.
Insère: organisation, client files, fournisseurs, factures, transactions, rapprochements.
"""
import os, sys
sys.path.insert(0, '/app')
os.chdir('/app')

from datetime import datetime, timedelta
import random
from src.storage.database import SessionLocal
from src.storage.models import (
    Organization, User, ClientFile, Supplier,
    Invoice, BankTransaction, ReconciliationMatch,
    InvoiceStatus
)
from passlib.context import CryptContext

db = SessionLocal()
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# ── Nettoyage préalable ────────────────────────────────────────────────────────
print("Nettoyage des données existantes…")
db.query(ReconciliationMatch).delete()
db.query(Invoice).delete()
db.query(BankTransaction).delete()
db.query(Supplier).delete()
db.query(ClientFile).delete()
db.commit()

# ── Organisation / User ────────────────────────────────────────────────────────
org = db.query(Organization).first()
if not org:
    org = Organization(name="Cabinet Durand Expertise Comptable", siret="12345678901234")
    db.add(org)
    db.commit()

user = db.query(User).filter_by(organization_id=org.id).first()
if not user:
    user = User(
        email="demo@factpilot.fr",
        hashed_password=pwd_context.hash("demo1234"),
        full_name="Jean Durand",
        organization_id=org.id,
        is_active=True,
    )
    db.add(user)
    db.commit()

print(f"Org: {org.name} | User: {user.email}")

# ── Dossiers clients ───────────────────────────────────────────────────────────
client_data = [
    dict(name="Boulangerie Martin", siret="32145678901234", activity="Boulangerie-pâtisserie",   contact_email="martin@boulangerie.fr"),
    dict(name="Garage Lefebvre",    siret="45678901234567", activity="Réparation automobile",     contact_email="lefebvre@garage.fr"),
    dict(name="Cabinet Médical Dupont", siret="56789012345678", activity="Cabinet médical",      contact_email="dupont@medecin.fr"),
    dict(name="Restaurant Le Provençal", siret="67890123456789", activity="Restauration",        contact_email="contact@leprovencal.fr"),
    dict(name="Menuiserie Petit",   siret="78901234567890", activity="Menuiserie",               contact_email="petit@menuiserie.fr"),
]

client_files = []
for cd in client_data:
    cf = ClientFile(organization_id=org.id, is_active=True, **cd)
    db.add(cf)
    db.flush()
    client_files.append(cf)
db.commit()
print(f"{len(client_files)} dossiers clients créés")

# ── Fournisseurs ───────────────────────────────────────────────────────────────
supplier_data = [
    dict(name="Boulangerie Centrale", category="Alimentation",   email="bc@boulangerie-centrale.fr"),
    dict(name="Peugeot Services",     category="Automobile",     email="srv@peugeot.fr"),
    dict(name="Loxam Location",       category="Location",       email="contact@loxam.fr"),
    dict(name="SFR Business",         category="Télécom",        email="pro@sfr.fr"),
    dict(name="EDF Entreprises",      category="Énergie",        email="pro@edf.fr"),
    dict(name="Orange Pro",           category="Télécom",        email="pro@orange.fr"),
    dict(name="Maison Plassard",      category="Alimentation",   email="commandes@plassard.fr"),
    dict(name="Michelin",             category="Automobile",     email="b2b@michelin.fr"),
    dict(name="3M France",            category="Matériaux",      email="france@3m.com"),
    dict(name="Total Energies",       category="Énergie",        email="pro@totalenergies.fr"),
    dict(name="Metro France",         category="Alimentation",   email="pro@metro.fr"),
    dict(name="AXA Assurances",       category="Assurance",      email="pro@axa.fr"),
]

suppliers = []
for sd in supplier_data:
    s = Supplier(organization_id=org.id, normalized_name=sd["name"].lower(), **sd)
    db.add(s)
    db.flush()
    suppliers.append(s)
db.commit()
print(f"{len(suppliers)} fournisseurs créés")

# ── Helpers ────────────────────────────────────────────────────────────────────
def rdate(year, month, day_min=1, day_max=28):
    return datetime(year, month, random.randint(day_min, day_max))

def rand_amount(low, high):
    return round(random.uniform(low, high), 2)

def make_invoice_number(cf_id, idx, month):
    return f"FAC-{cf_id:02d}-{month:02d}-{idx:03d}"

statuses_mix = [
    InvoiceStatus.MATCHED,   InvoiceStatus.MATCHED,   InvoiceStatus.MATCHED,
    InvoiceStatus.MATCHED,   InvoiceStatus.PENDING,   InvoiceStatus.UNMATCHED,
]

vehicles = ["AB-123-CD","EF-456-GH","IJ-789-KL","MN-012-OP","QR-345-ST", None, None, None]

# ── Factures + Transactions (6 mois de données) ────────────────────────────────
all_invoices = []
all_transactions = []

YEAR = 2026
MONTHS = [1, 2, 3, 4, 5, 6]

inv_idx = 1
txn_idx = 1

for month in MONTHS:
    for cf in client_files:
        # 4-8 factures par dossier par mois
        n_invoices = random.randint(4, 8)
        month_invoices = []
        for i in range(n_invoices):
            amount_ht = rand_amount(120, 4500)
            tva = round(amount_ht * 0.20, 2)
            amount_ttc = round(amount_ht + tva, 2)
            sup = random.choice(suppliers)
            date = rdate(YEAR, month)
            status = random.choice(statuses_mix)

            inv = Invoice(
                invoice_number=make_invoice_number(cf.id, inv_idx, month),
                supplier_id=sup.id,
                organization_id=org.id,
                client_file_id=cf.id,
                amount=amount_ttc,
                amount_ht=amount_ht,
                amount_tax=tva,
                date=date,
                due_date=date + timedelta(days=30),
                category=sup.category,
                status=status,
                reference_number=random.choice(vehicles),
                payment_method=random.choice(["Virement", "Prélèvement", "Chèque", None]),
            )
            db.add(inv)
            db.flush()
            month_invoices.append(inv)
            inv_idx += 1

        all_invoices.extend(month_invoices)

        # 1 transaction regroupée par dossier (somme des factures matched)
        matched_invs = [inv for inv in month_invoices if inv.status == InvoiceStatus.MATCHED]
        if matched_invs:
            total = round(sum(i.amount for i in matched_invs), 2)
            txn = BankTransaction(
                transaction_id=f"TXN-{cf.id:02d}-{month:02d}-{txn_idx:04d}",
                organization_id=org.id,
                client_file_id=cf.id,
                date=rdate(YEAR, month, 10, 28),
                amount=-total,
                description=f"VIR SEPA {cf.name.upper()[:20]} PAIEMENT {month:02d}/{YEAR}",
                reference=f"REF{txn_idx:06d}",
                category=random.choice(["Charges", "Frais généraux", "Exploitation"]),
            )
            db.add(txn)
            db.flush()
            all_transactions.append(txn)
            txn_idx += 1

            # Rapprochements pour les factures matched
            for inv in matched_invs:
                match = ReconciliationMatch(
                    invoice_id=inv.id,
                    transaction_id=txn.id,
                    match_score=round(random.uniform(0.75, 1.0), 2),
                    match_type=random.choice(["auto", "auto", "manual"]),
                    status="confirmed",
                    matched_by=random.choice(["system", "user"]),
                    organization_id=org.id,
                )
                db.add(match)

        # Quelques transactions sans correspondance (bank-only)
        if random.random() > 0.6:
            txn2 = BankTransaction(
                transaction_id=f"TXN-MISC-{month:02d}-{txn_idx:04d}",
                organization_id=org.id,
                client_file_id=cf.id,
                date=rdate(YEAR, month),
                amount=-rand_amount(50, 800),
                description=f"CARTE CB {random.choice(['AMAZON', 'FNAC', 'LEROY MERLIN', 'BRICOMARCHE'])} {month:02d}/{YEAR}",
                reference=f"CB{txn_idx:06d}",
                category="Divers",
            )
            db.add(txn2)
            db.flush()
            all_transactions.append(txn2)
            txn_idx += 1

db.commit()

# ── Résumé ─────────────────────────────────────────────────────────────────────
total_inv = db.query(Invoice).count()
total_txn = db.query(BankTransaction).count()
total_match = db.query(ReconciliationMatch).count()
matched = db.query(Invoice).filter(Invoice.status == InvoiceStatus.MATCHED).count()
pending = db.query(Invoice).filter(Invoice.status == InvoiceStatus.PENDING).count()
unmatched = db.query(Invoice).filter(Invoice.status == InvoiceStatus.UNMATCHED).count()

print("\n✅ Données factices insérées avec succès !")
print(f"   Factures      : {total_inv} ({matched} matched, {pending} pending, {unmatched} unmatched)")
print(f"   Transactions  : {total_txn}")
print(f"   Rapprochements: {total_match}")
print(f"   Dossiers      : {len(client_files)}")
print(f"   Fournisseurs  : {len(suppliers)}")
print(f"\n   Login: {user.email} / demo1234")

db.close()
