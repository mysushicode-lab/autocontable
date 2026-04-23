"""
Report generation for accounting
"""
from datetime import datetime
from typing import List, Dict
from sqlalchemy.orm import Session
from sqlalchemy import func
from src.storage.models import Invoice, BankTransaction, ReconciliationMatch, Supplier, InvoiceStatus
from dateutil.relativedelta import relativedelta
from dateutil import parser as date_parser
import calendar


class ReportGenerator:
    """Generate accounting reports"""
    
    def __init__(self, session: Session):
        self.session = session
    
    def monthly_totals(self, year: int, month: int) -> Dict:
        """
        Generate monthly totals report
        
        Args:
            year: Year
            month: Month (1-12)
            
        Returns:
            Dictionary with monthly totals
        """
        # Get first and last day of month
        first_day = datetime(year, month, 1)
        last_day = datetime(year, month, calendar.monthrange(year, month)[1], 23, 59, 59)
        
        # Get invoices for the month
        invoices = self.session.query(Invoice).filter(
            Invoice.date >= first_day,
            Invoice.date <= last_day
        ).all()
        
        # Calculate totals
        total_amount = sum(i.amount for i in invoices)
        total_tax = sum(i.amount_tax or 0 for i in invoices)
        
        # Group by supplier (using email_domain for better consolidation)
        supplier_totals = {}
        for invoice in invoices:
            # Use email_domain if available, otherwise fallback to name
            if invoice.supplier and invoice.supplier.email_domain:
                supplier_key = invoice.supplier.email_domain
            elif invoice.supplier:
                supplier_key = invoice.supplier.name
            else:
                supplier_key = "Unknown"
            
            if supplier_key not in supplier_totals:
                supplier_totals[supplier_key] = {
                    'count': 0,
                    'amount': 0,
                    'tax': 0
                }
            supplier_totals[supplier_key]['count'] += 1
            supplier_totals[supplier_key]['amount'] += invoice.amount
            supplier_totals[supplier_key]['tax'] += invoice.amount_tax or 0
        
        # Group by category
        category_totals = {}
        for invoice in invoices:
            category = invoice.category or "Uncategorized"
            if category not in category_totals:
                category_totals[category] = {
                    'count': 0,
                    'amount': 0
                }
            category_totals[category]['count'] += 1
            category_totals[category]['amount'] += invoice.amount
        
        # Reconciliation status
        matched_count = sum(1 for i in invoices if i.status == InvoiceStatus.MATCHED)
        unmatched_count = sum(1 for i in invoices if i.status == InvoiceStatus.UNMATCHED)
        pending_count = sum(1 for i in invoices if i.status == InvoiceStatus.PENDING)
        
        return {
            'period': f"{year}-{month:02d}",
            'total_invoices': len(invoices),
            'total_amount': total_amount,
            'total_tax': total_tax,
            'matched_invoices': matched_count,
            'unmatched_invoices': unmatched_count,
            'pending_invoices': pending_count,
            'match_rate': (matched_count / len(invoices) * 100) if invoices else 0,
            'by_supplier': supplier_totals,
            'by_category': category_totals
        }
    
    def monthly_trends(self, months: int = 12) -> Dict:
        """
        Generate trends for last N months
        
        Args:
            months: Number of months to analyze (1, 2, 3, 6, 12, 24, etc.)
            
        Returns:
            Dictionary with monthly data for the requested period
        """
        today = datetime.now()
        months_data = []
        
        # Generate data for requested number of months (from oldest to newest)
        for i in range(months - 1, -1, -1):
            # Calculate target month/year using relativedelta for accuracy
            target_date = today - relativedelta(months=i)
            year = target_date.year
            month = target_date.month
            
            # Get month data
            month_data = self.monthly_totals(year, month)
            months_data.append({
                'period': month_data['period'],
                'year': year,
                'month': month,
                'label': target_date.strftime('%b %Y'),
                'amount': month_data['total_amount'],
                'invoices': month_data['total_invoices'],
                'match_rate': month_data['match_rate']
            })
        
        # Calculate month-over-month change (only if we have at least 2 months)
        if len(months_data) >= 2:
            current = months_data[-1]['amount']
            previous = months_data[-2]['amount']
            change_pct = ((current - previous) / previous * 100) if previous else 0
        else:
            change_pct = 0
        
        # Calculate period-over-period change (first vs last month)
        if len(months_data) >= 2:
            first = months_data[0]['amount']
            last = months_data[-1]['amount']
            period_change_pct = ((last - first) / first * 100) if first else 0
        else:
            period_change_pct = 0
        
        return {
            'months': months_data,
            'period_months': months,
            'current_month': months_data[-1] if months_data else None,
            'first_month': months_data[0] if months_data else None,
            'month_over_month_change': round(change_pct, 1),
            'period_change': round(period_change_pct, 1),
            'trend_direction': 'up' if change_pct > 0 else 'down' if change_pct < 0 else 'stable',
            'total_period_amount': sum(m['amount'] for m in months_data),
            'total_period_invoices': sum(m['invoices'] for m in months_data),
        }
    
    def reconciliation_report(self, year: int, month: int) -> Dict:
        """
        Generate reconciliation report
        
        Args:
            year: Year
            month: Month (1-12)
            
        Returns:
            Dictionary with reconciliation status
        """
        first_day = datetime(year, month, 1)
        last_day = datetime(year, month, calendar.monthrange(year, month)[1], 23, 59, 59)
        
        # Get matches for the period
        matches = self.session.query(ReconciliationMatch).join(Invoice).filter(
            Invoice.date >= first_day,
            Invoice.date <= last_day
        ).all()
        
        # Calculate statistics
        confirmed = sum(1 for m in matches if m.status == 'confirmed')
        pending = sum(1 for m in matches if m.status == 'pending')
        rejected = sum(1 for m in matches if m.status == 'rejected')
        
        # Average match score
        avg_score = sum(m.match_score or 0 for m in matches) / len(matches) if matches else 0
        
        return {
            'period': f"{year}-{month:02d}",
            'total_matches': len(matches),
            'confirmed': confirmed,
            'pending': pending,
            'rejected': rejected,
            'average_match_score': avg_score
        }
    
    def supplier_summary(self, supplier_id: int = None) -> Dict:
        """
        Generate supplier summary
        
        Args:
            supplier_id: Supplier ID (if None, summary for all)
            
        Returns:
            Dictionary with supplier summary
        """
        query = self.session.query(Invoice)
        
        if supplier_id:
            query = query.filter(Invoice.supplier_id == supplier_id)
        
        invoices = query.all()
        
        total_amount = sum(i.amount for i in invoices)
        
        # Get oldest and newest invoices
        dates = [i.date for i in invoices if i.date]
        oldest = min(dates) if dates else None
        newest = max(dates) if dates else None
        
        return {
            'supplier_id': supplier_id,
            'total_invoices': len(invoices),
            'total_amount': total_amount,
            'oldest_invoice': oldest,
            'newest_invoice': newest,
            'average_amount': total_amount / len(invoices) if invoices else 0
        }
