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
from src.reporting.excel_exporter import ExcelExporter
from src.reporting.fec_exporter import FECExporter


class Exporter:
    """Export data to various formats"""

    def __init__(self, session: Session, org_id: int = None):
        self.session = session
        self.org_id = org_id
        self._excel_exporter = ExcelExporter(session, org_id)
        self._fec_exporter = FECExporter(session, org_id)
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
                'Référence': invoice.reference_number or '',
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
                'Référence': match.invoice.reference_number or '',
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
        """Export complete monthly report to Excel (delegates to ExcelExporter)"""
        return self._excel_exporter.export_monthly_report(output_path, year, month)

    def export_grand_livre_to_excel(self, output_path: str, year: int, month: int) -> str:
        """Export Grand Livre to Excel (delegates to ExcelExporter)"""
        return self._excel_exporter.export_grand_livre(output_path, year, month)

    def export_balance_to_excel(self, output_path: str, year: int, month: int) -> str:
        """Export Balance to Excel (delegates to ExcelExporter)"""
        return self._excel_exporter.export_balance(output_path, year, month)

    def export_fec(self, year: int, month: int, siren: str = None) -> str:
        """Export FEC file (delegates to FECExporter)"""
        return self._fec_exporter.export_fec(year, month, siren)
