"""
Reconciliation engine for matching invoices to bank transactions
"""
from datetime import timedelta
from typing import List, Dict, Tuple
from sqlalchemy.orm import Session
from src.storage.models import Invoice, BankTransaction, ReconciliationMatch, InvoiceStatus
from dotenv import load_dotenv
import os

# Load environment variables
load_dotenv(os.path.join(os.path.dirname(__file__), '../../config/.env'))

MATCHING_AMOUNT_TOLERANCE = float(os.getenv('MATCHING_AMOUNT_TOLERANCE', 0.01))
MATCHING_DATE_WINDOW_DAYS = int(os.getenv('MATCHING_DATE_WINDOW_DAYS', 7))


class ReconciliationEngine:
    """Match invoices to bank transactions"""
    
    def __init__(self, session: Session):
        self.session = session
        self.amount_tolerance = MATCHING_AMOUNT_TOLERANCE
        self.date_window = timedelta(days=MATCHING_DATE_WINDOW_DAYS)
    
    def reconcile(self, invoices: List[Invoice] = None, 
                  transactions: List[BankTransaction] = None) -> List[ReconciliationMatch]:
        """
        Reconcile invoices with bank transactions
        
        Args:
            invoices: List of invoices to reconcile (if None, fetch from DB)
            transactions: List of transactions (if None, fetch from DB)
            
        Returns:
            List of reconciliation matches
        """
        # Fetch from DB if not provided
        if invoices is None:
            invoices = self.session.query(Invoice).filter(
                Invoice.status.in_([InvoiceStatus.PROCESSED, InvoiceStatus.UNMATCHED])
            ).all()
        
        if transactions is None:
            transactions = self.session.query(BankTransaction).all()
        
        matches = []
        matched_transaction_ids = {
            transaction_id for (transaction_id,) in self.session.query(ReconciliationMatch.transaction_id).all()
        }
        
        for invoice in invoices:
            # Find matching transaction
            match, score = self._find_match(invoice, transactions, matched_transaction_ids)
            
            if match:
                # Create reconciliation match
                reconciliation = ReconciliationMatch(
                    invoice_id=invoice.id,
                    transaction_id=match.id,
                    match_score=score,
                    match_type='automatic',
                    status='pending'
                )
                
                self.session.add(reconciliation)
                
                # Update invoice status
                invoice.status = InvoiceStatus.MATCHED
                
                matched_transaction_ids.add(match.id)
                matches.append(reconciliation)
            else:
                # Mark as unmatched
                invoice.status = InvoiceStatus.UNMATCHED
        
        self.session.commit()
        return matches
    
    def _find_match(self, invoice: Invoice, transactions: List[BankTransaction], 
                   exclude_ids: set) -> Tuple[BankTransaction, float]:
        """
        Find best matching transaction for invoice
        
        Args:
            invoice: Invoice to match
            transactions: Available transactions
            exclude_ids: Transaction IDs already matched
            
        Returns:
            Tuple of (matched transaction, score)
        """
        best_match = None
        best_score = 0
        
        for transaction in transactions:
            # Skip already matched transactions
            if transaction.id in exclude_ids:
                continue
            
            # Calculate match score
            score = self._calculate_match_score(invoice, transaction)
            
            if score > best_score and score >= 0.5:  # Minimum threshold
                best_score = score
                best_match = transaction
        
        return best_match, best_score
    
    def _calculate_match_score(self, invoice: Invoice, transaction: BankTransaction) -> float:
        """
        Calculate match score between invoice and transaction
        
        Args:
            invoice: Invoice
            transaction: Bank transaction
            
        Returns:
            Score between 0 and 1
        """
        score = 0
        max_score = 3  # Amount, date, description
        
        # Amount match (most important)
        if self._amounts_match(invoice.amount, transaction.amount):
            score += 1.5
        elif self._amounts_approximately_match(invoice.amount, transaction.amount):
            score += 1.0
        
        # Date match
        if self._dates_match(invoice.date, transaction.date):
            score += 1.0
        elif self._dates_within_window(invoice.date, transaction.date):
            score += 0.5
        
        # Description match (supplier name in transaction description)
        if invoice.supplier and self._description_contains_supplier(
            invoice.supplier.name, transaction.description
        ):
            score += 0.5
        
        return score / max_score
    
    def _amounts_match(self, amount1: float, amount2: float) -> bool:
        """Check if amounts exactly match"""
        return abs(amount1 - amount2) < self.amount_tolerance
    
    def _amounts_approximately_match(self, amount1: float, amount2: float) -> bool:
        """Check if amounts approximately match (within 5%)"""
        if amount1 == 0 or amount2 == 0:
            return False
        return abs(amount1 - amount2) / max(abs(amount1), abs(amount2)) < 0.05
    
    def _dates_match(self, date1, date2) -> bool:
        """Check if dates match exactly"""
        if not date1 or not date2:
            return False
        return date1.date() == date2.date()
    
    def _dates_within_window(self, date1, date2) -> bool:
        """Check if dates are within matching window"""
        if not date1 or not date2:
            return False
        return abs(date1 - date2) <= self.date_window
    
    def _description_contains_supplier(self, supplier_name: str, description: str) -> bool:
        """Check if transaction description contains supplier name"""
        if not supplier_name or not description:
            return False
        
        # Simple keyword matching
        supplier_words = supplier_name.lower().split()
        description_lower = description.lower()
        
        for word in supplier_words:
            if len(word) > 3 and word in description_lower:
                return True
        
        return False
    
    def get_unmatched_invoices(self) -> List[Invoice]:
        """Get all unmatched invoices"""
        return self.session.query(Invoice).filter(
            Invoice.status == InvoiceStatus.UNMATCHED
        ).all()
    
    def get_unmatched_transactions(self) -> List[BankTransaction]:
        """Get all unmatched bank transactions"""
        matched_ids = self.session.query(ReconciliationMatch.transaction_id).all()
        matched_ids = [id[0] for id in matched_ids]
        
        return self.session.query(BankTransaction).filter(
            ~BankTransaction.id.in_(matched_ids) if matched_ids else True
        ).all()
