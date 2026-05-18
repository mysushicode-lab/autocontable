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
from src.constants import PCG_COMPTES, DEFAULT_COMPTE, TVA_COMPTE, FOURN_COMPTE


class Exporter:
    """Export data to various formats"""
    
    def __init__(self, session: Session, org_id: int = None):
        self.session = session
        self.org_id = org_id
    
    def _generate_accounting_entries(self, invoices, comptes_mapping, default_compte, tva_compte, fourn_compte):
        """
        Generate accounting entries (débit/crédit) for invoices
        
        Args:
            invoices: List of Invoice objects
            comptes_mapping: Dict mapping category to (compte, libelle)
            default_compte: Default compte tuple (compte, libelle)
            tva_compte: TVA compte tuple (compte, libelle)
            fourn_compte: Fournisseur compte tuple (compte, libelle)
            
        Returns:
            List of dicts with accounting entries
        """
        entries = []
        for inv in invoices:
            compte, libelle_compte = comptes_mapping.get(inv.category or '', default_compte)
            supplier = inv.supplier.name if inv.supplier else 'Fournisseur inconnu'
            piece = inv.invoice_number
            date_str = inv.date.strftime('%d/%m/%Y') if inv.date else ''
            tva = round(inv.amount_tax or 0, 2)
            ttc = round(inv.amount or 0, 2)
            ht = round(inv.amount_ht or 0, 2) or round(ttc - tva, 2)
            is_avoir = ttc < 0

            libelle_base = f"{'Avoir' if is_avoir else 'Facture'} {supplier} — {piece}"

            # Ligne 1 : Compte de charge (6xx) — débit HT
            entries.append({
                'Date': date_str,
                'N° Pièce': piece,
                'N° Compte': compte,
                'Libellé compte': libelle_compte,
                'Libellé écriture': libelle_base,
                'Débit': abs(ht) if not is_avoir else 0,
                'Crédit': abs(ht) if is_avoir else 0,
            })
            # Ligne 2 : TVA déductible (445660) — débit TVA
            if tva:
                entries.append({
                    'Date': date_str,
                    'N° Pièce': piece,
                    'N° Compte': tva_compte[0],
                    'Libellé compte': tva_compte[1],
                    'Libellé écriture': f"TVA — {libelle_base}",
                    'Débit': abs(tva) if not is_avoir else 0,
                    'Crédit': abs(tva) if is_avoir else 0,
                })
            # Ligne 3 : Fournisseur (401000) — crédit TTC
            entries.append({
                'Date': date_str,
                'N° Pièce': piece,
                'N° Compte': fourn_compte[0],
                'Libellé compte': fourn_compte[1],
                'Libellé écriture': f"Fournisseur — {supplier}",
                'Débit': abs(ttc) if is_avoir else 0,
                'Crédit': abs(ttc) if not is_avoir else 0,
            })
        
        return entries
    
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

        # Fetch invoices for the period
        first_day = datetime(year, month, 1)
        last_day  = datetime(year, month, calendar.monthrange(year, month)[1], 23, 59, 59)
        
        # Get invoices from the selected month (by invoice date)
        inv_q = self.session.query(Invoice).filter(
            Invoice.date >= first_day, Invoice.date <= last_day
        )
        if self.org_id:
            inv_q = inv_q.filter(Invoice.organization_id == self.org_id)
        invoices = inv_q.all()

        # Also include invoices matched to transactions in the selected month (like Dashboard metrics)
        # This captures invoices from previous months that were reconciled with current month bank transactions
        from src.storage.models import ReconciliationMatch, BankTransaction
        matches = self.session.query(ReconciliationMatch).join(Invoice).join(
            BankTransaction, ReconciliationMatch.transaction_id == BankTransaction.id
        ).filter(
            BankTransaction.date >= first_day,
            BankTransaction.date <= last_day
        )
        if self.org_id:
            matches = matches.filter(Invoice.organization_id == self.org_id)
        
        matched_invoice_ids = {match.invoice_id for match in matches if match.status != 'rejected'}
        
        # Get matched invoices that are not already in the monthly invoices (from previous months)
        matched_invoices_prev_month = []
        for match in matches:
            if match.status != 'rejected' and match.invoice_id not in {inv.id for inv in invoices}:
                matched_invoices_prev_month.append(match.invoice)
        
        # Combine: monthly invoices + matched invoices from previous months
        all_invoices = invoices + matched_invoices_prev_month

        os.makedirs(os.path.dirname(output_path), exist_ok=True)

        with pd.ExcelWriter(output_path, engine='openpyxl') as writer:

            # ── Feuille 1 : Résumé ──────────────────────────────────────────
            total_ht  = sum(i.amount_ht  or 0 for i in all_invoices)
            total_tva = sum(i.amount_tax or 0 for i in all_invoices)
            total_ttc = sum(i.amount     or 0 for i in all_invoices)
            
            # Calculate matched invoices based on actual reconciliation matches (filtered by transaction date)
            matched_count = len(matched_invoice_ids)
            
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
                    len(all_invoices),
                    round(total_ht, 2),
                    round(total_tva, 2),
                    round(total_ttc, 2),
                    matched_count,
                    len(all_invoices) - matched_count,
                    round(matched_count / len(all_invoices) * 100, 1) if all_invoices else 0,
                ]
            }
            pd.DataFrame(summary_data).to_excel(writer, sheet_name='Résumé', index=False)

            # ── Feuille 2 : Journal des Achats (PCG) ────────────────────────
            journal_rows = []
            for entry in self._generate_accounting_entries(all_invoices, PCG_COMPTES, DEFAULT_COMPTE, TVA_COMPTE, FOURN_COMPTE):
                journal_rows.append({
                    'Date': entry['Date'],
                    'Journal': 'ACH',
                    'N° Pièce': entry['N° Pièce'],
                    'N° Compte': entry['N° Compte'],
                    'Libellé compte': entry['Libellé compte'],
                    'Libellé écriture': entry['Libellé écriture'],
                    'Débit': entry['Débit'],
                    'Crédit': entry['Crédit'],
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
                compte, libelle = PCG_COMPTES.get(category, DEFAULT_COMPTE)
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

            # ── Feuille 5 : Grand Livre ───────────────────────────────────────
            grand_livre_rows = []
            for entry in self._generate_accounting_entries(all_invoices, PCG_COMPTES, DEFAULT_COMPTE, TVA_COMPTE, FOURN_COMPTE):
                grand_livre_rows.append({
                    'Date': entry['Date'],
                    'N° Compte': entry['N° Compte'],
                    'Libellé compte': entry['Libellé compte'],
                    'Libellé écriture': entry['Libellé écriture'],
                    'Débit': entry['Débit'],
                    'Crédit': entry['Crédit'],
                })

            pd.DataFrame(grand_livre_rows).to_excel(writer, sheet_name='Grand Livre', index=False)

        return output_path
    
    def export_grand_livre_to_excel(self, output_path: str, year: int, month: int) -> str:
        """
        Export Grand Livre (all accounting entries) to Excel
        
        Args:
            output_path: Path to save Excel file
            year: Year
            month: Month
            
        Returns:
            Path to exported file
        """
        # Fetch invoices for the period (same logic as export_monthly_report_to_excel)
        first_day = datetime(year, month, 1)
        last_day  = datetime(year, month, calendar.monthrange(year, month)[1], 23, 59, 59)
        
        # Get invoices from the selected month (by invoice date)
        inv_q = self.session.query(Invoice).filter(
            Invoice.date >= first_day, Invoice.date <= last_day
        )
        if self.org_id:
            inv_q = inv_q.filter(Invoice.organization_id == self.org_id)
        invoices = inv_q.all()

        # Also include invoices matched to transactions in the selected month
        from src.storage.models import ReconciliationMatch, BankTransaction
        matches = self.session.query(ReconciliationMatch).join(Invoice).join(
            BankTransaction, ReconciliationMatch.transaction_id == BankTransaction.id
        ).filter(
            BankTransaction.date >= first_day,
            BankTransaction.date <= last_day
        )
        if self.org_id:
            matches = matches.filter(Invoice.organization_id == self.org_id)
        
        # Get matched invoices that are not already in the monthly invoices
        matched_invoices_prev_month = []
        for match in matches:
            if match.status != 'rejected' and match.invoice_id not in {inv.id for inv in invoices}:
                matched_invoices_prev_month.append(match.invoice)
        
        # Combine: monthly invoices + matched invoices from previous months
        all_invoices = invoices + matched_invoices_prev_month

        os.makedirs(os.path.dirname(output_path), exist_ok=True)

        with pd.ExcelWriter(output_path, engine='openpyxl') as writer:
            # Generate Grand Livre entries
            grand_livre_rows = []
            for entry in self._generate_accounting_entries(all_invoices, PCG_COMPTES, DEFAULT_COMPTE, TVA_COMPTE, FOURN_COMPTE):
                grand_livre_rows.append({
                    'Date': entry['Date'],
                    'N° Compte': entry['N° Compte'],
                    'Libellé compte': entry['Libellé compte'],
                    'Libellé écriture': entry['Libellé écriture'],
                    'Débit': entry['Débit'],
                    'Crédit': entry['Crédit'],
                })

            pd.DataFrame(grand_livre_rows).to_excel(writer, sheet_name='Grand Livre', index=False)

        return output_path
    
    def export_balance_to_excel(self, output_path: str, year: int, month: int) -> str:
        """
        Export Balance (summary by account) to Excel
        
        Args:
            output_path: Path to save Excel file
            year: Year
            month: Month
            
        Returns:
            Path to exported file
        """
        # Fetch invoices for the period (same logic as export_monthly_report_to_excel)
        first_day = datetime(year, month, 1)
        last_day  = datetime(year, month, calendar.monthrange(year, month)[1], 23, 59, 59)
        
        # Get invoices from the selected month (by invoice date)
        inv_q = self.session.query(Invoice).filter(
            Invoice.date >= first_day, Invoice.date <= last_day
        )
        if self.org_id:
            inv_q = inv_q.filter(Invoice.organization_id == self.org_id)
        invoices = inv_q.all()

        # Also include invoices matched to transactions in the selected month
        from src.storage.models import ReconciliationMatch, BankTransaction
        matches = self.session.query(ReconciliationMatch).join(Invoice).join(
            BankTransaction, ReconciliationMatch.transaction_id == BankTransaction.id
        ).filter(
            BankTransaction.date >= first_day,
            BankTransaction.date <= last_day
        )
        if self.org_id:
            matches = matches.filter(Invoice.organization_id == self.org_id)
        
        # Get matched invoices that are not already in the monthly invoices
        matched_invoices_prev_month = []
        for match in matches:
            if match.status != 'rejected' and match.invoice_id not in {inv.id for inv in invoices}:
                matched_invoices_prev_month.append(match.invoice)
        
        # Combine: monthly invoices + matched invoices from previous months
        all_invoices = invoices + matched_invoices_prev_month

        # Calculate balance by account
        chargeMap = {}
        totalHT = 0
        totalTVA = 0
        totalTTC = 0
        
        for inv in all_invoices:
            compte, libelle = PCG_COMPTES.get(inv.category or '', DEFAULT_COMPTE)
            tva = inv.amount_tax or 0
            ttc = inv.amount or 0
            ht = inv.amount_ht or 0 or (ttc - tva)
            
            if compte not in chargeMap:
                chargeMap[compte] = {'label': libelle, 'debit': 0}
            chargeMap[compte]['debit'] += ht
            totalHT += ht
            totalTVA += tva
            totalTTC += ttc

        os.makedirs(os.path.dirname(output_path), exist_ok=True)

        balance_rows = []
        
        # Ligne par compte de charge (6xx)
        for compte in sorted(chargeMap.keys()):
            data = chargeMap[compte]
            balance_rows.append({
                'N° Compte': compte,
                'Libellé compte': data['label'],
                'Total Débit': round(data['debit'], 2),
                'Total Crédit': 0.00,
                'Solde': round(data['debit'], 2),
            })
        
        # Ligne TVA déductible (445660)
        if totalTVA:
            balance_rows.append({
                'N° Compte': TVA_COMPTE[0],
                'Libellé compte': TVA_COMPTE[1],
                'Total Débit': round(totalTVA, 2),
                'Total Crédit': 0.00,
                'Solde': round(totalTVA, 2),
            })
        
        # Ligne Fournisseurs (401000)
        balance_rows.append({
            'N° Compte': FOURN_COMPTE[0],
            'Libellé compte': FOURN_COMPTE[1],
            'Total Débit': 0.00,
            'Total Crédit': round(totalTTC, 2),
            'Solde': -round(totalTTC, 2),
        })
        
        # Total de contrôle (doit être 0 — partie double)
        controle = totalHT + totalTVA - totalTTC
        balance_rows.append({
            'N° Compte': '',
            'Libellé compte': 'TOTAL DE CONTRÔLE (doit être 0)',
            'Total Débit': round(totalHT + totalTVA, 2),
            'Total Crédit': round(totalTTC, 2),
            'Solde': round(controle, 2),
        })

        df = pd.DataFrame(balance_rows)
        df.to_excel(output_path, index=False)

        return output_path
