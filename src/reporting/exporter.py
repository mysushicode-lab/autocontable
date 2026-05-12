"""
Export functionality for accounting data
"""
import os
import pandas as pd
from datetime import datetime
from typing import List, Dict
from sqlalchemy.orm import Session
from src.storage.models import Invoice, BankTransaction, ReconciliationMatch
import calendar


class Exporter:
    """Export data to various formats"""
    
    def __init__(self, session: Session, org_id: int = None):
        self.session = session
        self.org_id = org_id
    
    def export_invoices_to_csv(self, output_path: str, month: int = None, year: int = None) -> str:
        """
        Export invoices to CSV
        
        Args:
            output_path: Path to save CSV file
            month: Optional month filter
            year: Optional year filter
            
        Returns:
            Path to exported file
        """
        query = self.session.query(Invoice)
        if self.org_id:
            query = query.filter(Invoice.organization_id == self.org_id)
        if month and year:
            first_day = datetime(year, month, 1)
            last_day = datetime(year, month, calendar.monthrange(year, month)[1], 23, 59, 59)
            query = query.filter(Invoice.date >= first_day, Invoice.date <= last_day)
        
        invoices = query.all()
        
        _STATUS_FR = {'pending': 'En attente', 'processed': 'Traité', 'matched': 'Rapproché', 'unmatched': 'Non rapproché'}
        data = []
        for invoice in invoices:
            data.append({
                'N° Facture': invoice.invoice_number,
                'Date': invoice.date.strftime('%d/%m/%Y') if invoice.date else '',
                'Échéance': invoice.due_date.strftime('%d/%m/%Y') if invoice.due_date else '',
                'Fournisseur': invoice.supplier.name if invoice.supplier else '',
                'Catégorie': invoice.category or '',
                'Montant HT': round(invoice.amount_ht or 0, 2),
                'TVA': round(invoice.amount_tax or 0, 2),
                'Montant TTC': round(invoice.amount or 0, 2),
                'Mode paiement': invoice.payment_method or '',
                'Statut': _STATUS_FR.get(invoice.status.value, invoice.status.value) if invoice.status else '',
                'N° commande': invoice.purchase_order or '',
                'N° BL': invoice.delivery_note or '',
                'Immatriculation': invoice.vehicle_registration or '',
                'N° OR / Dossier': invoice.work_order_reference or '',
            })
        
        df = pd.DataFrame(data)
        
        # Create directory if needed
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        
        df.to_csv(output_path, index=False, encoding='utf-8-sig', sep=';')
        return output_path
    
    def export_transactions_to_csv(self, output_path: str, month: int = None, year: int = None) -> str:
        """
        Export bank transactions to CSV
        
        Args:
            output_path: Path to save CSV file
            month: Optional month filter
            year: Optional year filter
            
        Returns:
            Path to exported file
        """
        query = self.session.query(BankTransaction)
        if self.org_id:
            query = query.filter(BankTransaction.organization_id == self.org_id)
        if month and year:
            first_day = datetime(year, month, 1)
            last_day = datetime(year, month, calendar.monthrange(year, month)[1], 23, 59, 59)
            query = query.filter(BankTransaction.date >= first_day, BankTransaction.date <= last_day)
        
        transactions = query.all()
        
        data = []
        for transaction in transactions:
            data.append({
                'ID Opération': transaction.transaction_id,
                'Date': transaction.date.strftime('%d/%m/%Y') if transaction.date else '',
                'Montant': round(transaction.amount, 2),
                'Libellé': transaction.description,
                'Référence': transaction.reference or '',
                'Catégorie': transaction.category or ''
            })
        
        df = pd.DataFrame(data)
        
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        
        df.to_csv(output_path, index=False, encoding='utf-8-sig', sep=';')
        return output_path
    
    def export_reconciliation_to_csv(self, output_path: str, month: int = None, year: int = None) -> str:
        """
        Export reconciliation matches to CSV
        
        Args:
            output_path: Path to save CSV file
            month: Optional month filter
            year: Optional year filter
            
        Returns:
            Path to exported file
        """
        query = self.session.query(ReconciliationMatch).join(Invoice)
        if self.org_id:
            query = query.filter(Invoice.organization_id == self.org_id)
        if month and year:
            first_day = datetime(year, month, 1)
            last_day = datetime(year, month, calendar.monthrange(year, month)[1], 23, 59, 59)
            query = query.filter(Invoice.date >= first_day, Invoice.date <= last_day)
        
        matches = query.all()
        
        _MATCH_TYPE_FR = {'automatic': 'Automatique', 'manual': 'Manuel'}
        _MATCH_STATUS_FR = {'confirmed': 'Confirmé', 'rejected': 'Rejeté'}
        data = []
        for match in matches:
            data.append({
                'N° Facture': match.invoice.invoice_number,
                'Montant TTC facture': round(match.invoice.amount, 2),
                'Date facture': match.invoice.date.strftime('%d/%m/%Y') if match.invoice.date else '',
                'Fournisseur': match.invoice.supplier.name if match.invoice.supplier else '',
                'Catégorie': match.invoice.category or '',
                'Immatriculation': match.invoice.vehicle_registration or '',
                'N° OR / Dossier': match.invoice.work_order_reference or '',
                'N° commande': match.invoice.purchase_order or '',
                'ID opération bancaire': match.transaction.transaction_id,
                'Montant opération': round(match.transaction.amount, 2),
                'Date opération': match.transaction.date.strftime('%d/%m/%Y') if match.transaction.date else '',
                'Score rapprochement (%)': round((match.match_score or 0) * 100, 1),
                'Type rapprochement': _MATCH_TYPE_FR.get(match.match_type, match.match_type),
                'Statut': _MATCH_STATUS_FR.get(match.status, match.status),
            })
        
        df = pd.DataFrame(data)
        
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        
        df.to_csv(output_path, index=False, encoding='utf-8-sig', sep=';')
        return output_path
    
    def export_monthly_report_to_excel(self, output_path: str, year: int, month: int) -> str:
        """
        Export complete monthly report to Excel
        
        Args:
            output_path: Path to save Excel file
            year: Year
            month: Month
            
        Returns:
            Path to exported file
        """
        from src.reporting.report_generator import ReportGenerator
        
        report_gen = ReportGenerator(self.session, org_id=self.org_id)
        
        # Get data
        monthly_totals = report_gen.monthly_totals(year, month)
        reconciliation = report_gen.reconciliation_report(year, month)
        
        # PCG account mapping for carrosserie auto
        _COMPTES = {
            'Pièces détachées':              ('607100', 'Achats marchandises — pièces auto'),
            'Peinture et vernis':            ('607200', 'Achats — peinture et vernis'),
            'Fournitures atelier':           ('606400', 'Fournitures atelier et consommables'),
            'Sous-traitance':                ('611000', 'Sous-traitance générale'),
            'Équipement et outillage':       ('606310', 'Petit outillage'),
            'Énergie et locaux':             ('606110', 'Électricité, gaz, loyer'),
            'Assurances et frais':           ('616000', "Primes d'assurances"),
            'Déplacements et véhicules':     ('625100', 'Voyages et déplacements'),
            'Informatique et communication': ('626000', 'Téléphone et internet'),
            'Formation et divers':           ('628000', 'Charges diverses de gestion'),
        }
        _DEFAULT_COMPTE = ('608000', 'Achats divers non stockés')
        _TVA_COMPTE    = ('445660', 'TVA déductible — achats et services')
        _FOURN_COMPTE  = ('401000', 'Fournisseurs')

        # Fetch invoices for the period
        first_day = datetime(year, month, 1)
        last_day  = datetime(year, month, calendar.monthrange(year, month)[1], 23, 59, 59)
        inv_q = self.session.query(Invoice).filter(
            Invoice.date >= first_day, Invoice.date <= last_day
        )
        if self.org_id:
            inv_q = inv_q.filter(Invoice.organization_id == self.org_id)
        invoices = inv_q.all()

        os.makedirs(os.path.dirname(output_path), exist_ok=True)

        with pd.ExcelWriter(output_path, engine='openpyxl') as writer:

            # ── Feuille 1 : Résumé ──────────────────────────────────────────
            total_ht  = sum(i.amount_ht  or 0 for i in invoices)
            total_tva = sum(i.amount_tax or 0 for i in invoices)
            total_ttc = sum(i.amount     or 0 for i in invoices)
            matched   = sum(1 for i in invoices if i.status and i.status.value == 'matched')
            summary_data = {
                'Indicateur': [
                    'Période',
                    'Nombre de factures',
                    'Total HT',
                    'Total TVA',
                    'Total TTC',
                    'Factures rapprochées',
                    'Factures non rapprochées',
                    'Taux de rapprochement (%)'
                ],
                'Valeur': [
                    monthly_totals['period'],
                    monthly_totals['total_invoices'],
                    round(total_ht, 2),
                    round(total_tva, 2),
                    round(total_ttc, 2),
                    matched,
                    monthly_totals['total_invoices'] - matched,
                    round(matched / monthly_totals['total_invoices'] * 100, 1) if monthly_totals['total_invoices'] else 0,
                ]
            }
            pd.DataFrame(summary_data).to_excel(writer, sheet_name='Résumé', index=False)

            # ── Feuille 2 : Journal des Achats (PCG) ────────────────────────
            journal_rows = []
            for inv in invoices:
                compte, libelle_compte = _COMPTES.get(inv.category or '', _DEFAULT_COMPTE)
                supplier  = inv.supplier.name if inv.supplier else 'Fournisseur inconnu'
                piece     = inv.invoice_number
                date_str  = inv.date.strftime('%d/%m/%Y') if inv.date else ''
                tva       = round(inv.amount_tax or 0, 2)
                ttc       = round(inv.amount     or 0, 2)
                ht        = round(inv.amount_ht  or 0, 2) or round(ttc - tva, 2)
                is_avoir  = ttc < 0

                libelle_base = f"{'Avoir' if is_avoir else 'Facture'} {supplier} — {piece}"

                # Ligne 1 : Compte de charge (6xx) — débit HT
                journal_rows.append({
                    'Date': date_str, 'Journal': 'ACH', 'N° Pièce': piece,
                    'N° Compte': compte, 'Libellé compte': libelle_compte,
                    'Libellé écriture': libelle_base,
                    'Débit': abs(ht) if not is_avoir else 0,
                    'Crédit': abs(ht) if is_avoir else 0,
                })
                # Ligne 2 : TVA déductible (445660) — débit TVA
                if tva:
                    journal_rows.append({
                        'Date': date_str, 'Journal': 'ACH', 'N° Pièce': piece,
                        'N° Compte': _TVA_COMPTE[0], 'Libellé compte': _TVA_COMPTE[1],
                        'Libellé écriture': f"TVA — {libelle_base}",
                        'Débit': abs(tva) if not is_avoir else 0,
                        'Crédit': abs(tva) if is_avoir else 0,
                    })
                # Ligne 3 : Fournisseur (401000) — crédit TTC
                journal_rows.append({
                    'Date': date_str, 'Journal': 'ACH', 'N° Pièce': piece,
                    'N° Compte': _FOURN_COMPTE[0], 'Libellé compte': _FOURN_COMPTE[1],
                    'Libellé écriture': f"Fournisseur — {supplier}",
                    'Débit': abs(ttc) if is_avoir else 0,
                    'Crédit': abs(ttc) if not is_avoir else 0,
                })

            pd.DataFrame(journal_rows).to_excel(writer, sheet_name='Journal des Achats', index=False)

            # ── Feuille 3 : Par fournisseur ─────────────────────────────────
            supplier_data = []
            for supplier, data in monthly_totals['by_supplier'].items():
                supplier_data.append({
                    'Fournisseur': supplier,
                    'Nb factures': data['count'],
                    'Total HT': round(data.get('amount_ht', 0), 2),
                    'Total TVA': round(data['tax'], 2),
                    'Total TTC': round(data['amount'], 2),
                })
            pd.DataFrame(supplier_data).to_excel(writer, sheet_name='Par fournisseur', index=False)

            # ── Feuille 4 : Par catégorie ────────────────────────────────────
            category_data = []
            for category, data in monthly_totals['by_category'].items():
                compte, libelle = _COMPTES.get(category, _DEFAULT_COMPTE)
                category_data.append({
                    'N° Compte PCG': compte,
                    'Catégorie': category,
                    'Libellé PCG': libelle,
                    'Nb factures': data['count'],
                    'Total HT': round(data.get('amount_ht', 0), 2),
                    'Total TVA': round(data.get('tax', 0), 2),
                    'Total TTC': round(data['amount'], 2),
                })
            pd.DataFrame(category_data).to_excel(writer, sheet_name='Par catégorie', index=False)

        return output_path
