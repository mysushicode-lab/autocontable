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
    
    def __init__(self, session: Session):
        self.session = session
    
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
        
        if month and year:
            first_day = datetime(year, month, 1)
            last_day = datetime(year, month, calendar.monthrange(year, month)[1], 23, 59, 59)
            query = query.filter(Invoice.date >= first_day, Invoice.date <= last_day)
        
        invoices = query.all()
        
        data = []
        for invoice in invoices:
            data.append({
                'Invoice Number': invoice.invoice_number,
                'Date': invoice.date.strftime('%Y-%m-%d') if invoice.date else '',
                'Supplier': invoice.supplier.name if invoice.supplier else '',
                'Amount': invoice.amount,
                'Tax': invoice.amount_tax or 0,
                'Category': invoice.category or '',
                'Status': invoice.status.value if invoice.status else '',
                # Carrosserie specific fields
                'Purchase Order': invoice.purchase_order or '',
                'Delivery Note (BL)': invoice.delivery_note or '',
                'Vehicle Registration': invoice.vehicle_registration or '',
                'Work Order (OT)': invoice.work_order_reference or '',
                'Payment Method': invoice.payment_method or '',
                'File Path': invoice.file_path or ''
            })
        
        df = pd.DataFrame(data)
        
        # Create directory if needed
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        
        df.to_csv(output_path, index=False, encoding='utf-8')
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
        
        if month and year:
            first_day = datetime(year, month, 1)
            last_day = datetime(year, month, calendar.monthrange(year, month)[1], 23, 59, 59)
            query = query.filter(BankTransaction.date >= first_day, BankTransaction.date <= last_day)
        
        transactions = query.all()
        
        data = []
        for transaction in transactions:
            data.append({
                'Transaction ID': transaction.transaction_id,
                'Date': transaction.date.strftime('%Y-%m-%d') if transaction.date else '',
                'Amount': transaction.amount,
                'Description': transaction.description,
                'Reference': transaction.reference or '',
                'Category': transaction.category or ''
            })
        
        df = pd.DataFrame(data)
        
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        
        df.to_csv(output_path, index=False, encoding='utf-8')
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
        
        if month and year:
            first_day = datetime(year, month, 1)
            last_day = datetime(year, month, calendar.monthrange(year, month)[1], 23, 59, 59)
            query = query.filter(Invoice.date >= first_day, Invoice.date <= last_day)
        
        matches = query.all()
        
        data = []
        for match in matches:
            data.append({
                'Invoice Number': match.invoice.invoice_number,
                'Invoice Amount': match.invoice.amount,
                'Invoice Date': match.invoice.date.strftime('%Y-%m-%d') if match.invoice.date else '',
                'Supplier': match.invoice.supplier.name if match.invoice.supplier else '',
                'Category': match.invoice.category or '',
                # Carrosserie specific fields
                'Vehicle Registration': match.invoice.vehicle_registration or '',
                'Work Order (OT)': match.invoice.work_order_reference or '',
                'Purchase Order': match.invoice.purchase_order or '',
                'Transaction ID': match.transaction.transaction_id,
                'Transaction Amount': match.transaction.amount,
                'Transaction Date': match.transaction.date.strftime('%Y-%m-%d') if match.transaction.date else '',
                'Match Score': match.match_score or 0,
                'Match Type': match.match_type,
                'Status': match.status
            })
        
        df = pd.DataFrame(data)
        
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        
        df.to_csv(output_path, index=False, encoding='utf-8')
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
        
        report_gen = ReportGenerator(self.session)
        
        # Get data
        monthly_totals = report_gen.monthly_totals(year, month)
        reconciliation = report_gen.reconciliation_report(year, month)
        
        # Create Excel file with multiple sheets
        with pd.ExcelWriter(output_path, engine='openpyxl') as writer:
            # Summary sheet
            summary_data = {
                'Metric': [
                    'Period',
                    'Total Invoices',
                    'Total Amount',
                    'Total Tax',
                    'Matched Invoices',
                    'Unmatched Invoices',
                    'Match Rate (%)'
                ],
                'Value': [
                    monthly_totals['period'],
                    monthly_totals['total_invoices'],
                    monthly_totals['total_amount'],
                    monthly_totals['total_tax'],
                    monthly_totals['matched_invoices'],
                    monthly_totals['unmatched_invoices'],
                    monthly_totals['match_rate']
                ]
            }
            pd.DataFrame(summary_data).to_excel(writer, sheet_name='Summary', index=False)
            
            # By supplier sheet
            supplier_data = []
            for supplier, data in monthly_totals['by_supplier'].items():
                supplier_data.append({
                    'Supplier': supplier,
                    'Count': data['count'],
                    'Amount': data['amount'],
                    'Tax': data['tax']
                })
            pd.DataFrame(supplier_data).to_excel(writer, sheet_name='By Supplier', index=False)
            
            # By category sheet
            category_data = []
            for category, data in monthly_totals['by_category'].items():
                category_data.append({
                    'Category': category,
                    'Count': data['count'],
                    'Amount': data['amount']
                })
            pd.DataFrame(category_data).to_excel(writer, sheet_name='By Category', index=False)
        
        return output_path
