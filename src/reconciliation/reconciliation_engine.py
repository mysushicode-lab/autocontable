"""
Reconciliation engine for matching invoices to bank transactions
"""
from datetime import timedelta
from typing import List, Dict, Tuple
from sqlalchemy.orm import Session
from src.storage.models import Invoice, BankTransaction, ReconciliationMatch, InvoiceStatus
from dotenv import load_dotenv
import os
import openai

# Load environment variables
load_dotenv(os.path.join(os.path.dirname(__file__), '../../.env'))

MATCHING_AMOUNT_TOLERANCE = float(os.getenv('MATCHING_AMOUNT_TOLERANCE', 0.001))
MATCHING_DATE_WINDOW_DAYS = int(os.getenv('MATCHING_DATE_WINDOW_DAYS', 90))


class ReconciliationEngine:
    """Match invoices to bank transactions using AI-assisted matching"""
    
    def __init__(self, session: Session):
        self.session = session
        self.amount_tolerance = MATCHING_AMOUNT_TOLERANCE
        self.date_window = timedelta(days=MATCHING_DATE_WINDOW_DAYS)
        openai.api_key = os.getenv('OPENAI_API_KEY')
    
    def reconcile(self, invoices: List[Invoice] = None, 
                  transactions: List[BankTransaction] = None,
                  organization_id: int = None) -> List[ReconciliationMatch]:
        """
        Reconcile invoices with bank transactions
        
        Args:
            invoices: List of invoices to reconcile (if None, fetch from DB)
            transactions: List of transactions (if None, fetch from DB)
            organization_id: Organization ID for multi-tenancy
            
        Returns:
            List of reconciliation matches
        """
        # Fetch from DB if not provided
        if invoices is None:
            query = self.session.query(Invoice).filter(
                Invoice.status.in_([InvoiceStatus.PROCESSED, InvoiceStatus.UNMATCHED])
            )
            if organization_id:
                query = query.filter(Invoice.organization_id == organization_id)
            invoices = query.all()
        
        if transactions is None:
            query = self.session.query(BankTransaction)
            if organization_id:
                query = query.filter(BankTransaction.organization_id == organization_id)
            transactions = query.all()
        
        query = self.session.query(ReconciliationMatch)
        if organization_id:
            query = query.filter(ReconciliationMatch.organization_id == organization_id)
        already_matched_tx_ids = {
            transaction_id for (transaction_id,) in query.with_entities(ReconciliationMatch.transaction_id).all()
        }

        # Build all candidate pairs sorted by score descending (best-first greedy)
        candidates = []
        for invoice in invoices:
            for transaction in transactions:
                if transaction.id in already_matched_tx_ids:
                    continue
                score = self._calculate_match_score(invoice, transaction)
                if score >= 1.0:  # Allow AI-assisted matches
                    candidates.append((score, invoice, transaction))
        candidates.sort(key=lambda x: x[0], reverse=True)

        matched_invoice_ids = set()
        matched_transaction_ids = set(already_matched_tx_ids)
        matches = []

        for score, invoice, transaction in candidates:
            if invoice.id in matched_invoice_ids or transaction.id in matched_transaction_ids:
                continue
            reconciliation = ReconciliationMatch(
                invoice_id=invoice.id,
                transaction_id=transaction.id,
                match_score=score,
                match_type='automatic',
                status='pending',
                organization_id=organization_id if organization_id else invoice.organization_id
            )
            self.session.add(reconciliation)
            invoice.status = InvoiceStatus.MATCHED
            matched_invoice_ids.add(invoice.id)
            matched_transaction_ids.add(transaction.id)
            matches.append(reconciliation)

        # Mark remaining unmatched
        for invoice in invoices:
            if invoice.id not in matched_invoice_ids:
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
            
            if score > best_score and score >= 1.0:  # Allow AI-assisted matches
                best_score = score
                best_match = transaction
        
        return best_match, best_score
    
    def _ai_should_match(self, invoice: Invoice, transaction: BankTransaction) -> Tuple[bool, float]:
        """
        Use AI to determine if invoice and transaction should match.
        
        Args:
            invoice: Invoice to match
            transaction: Bank transaction to match
            
        Returns:
            Tuple of (should_match, confidence_score)
        """
        try:
            prompt = f"""You are a financial reconciliation expert. Determine if this invoice matches this bank transaction.

INVOICE:
- Number: {invoice.invoice_number}
- Amount: {invoice.amount}€
- Date: {invoice.date}
- Supplier: {invoice.supplier.name if invoice.supplier else 'Unknown'}
- Category: {invoice.category or 'Unknown'}

BANK TRANSACTION:
- ID: {transaction.transaction_id}
- Amount: {transaction.amount}€
- Date: {transaction.date}
- Description: {transaction.description}

Consider:
1. Amount: Are the amounts similar (allowing for fees, partial payments, rounding)?
2. Supplier: Does the transaction description relate to the supplier name?
3. Date: Is the transaction date reasonable for payment (within 90 days)?
4. Context: Does the overall pattern suggest these are related?

Respond with ONLY a JSON object: {{"should_match": true/false, "confidence": 0.0-1.0, "reasoning": "brief explanation"}}"""

            response = openai.chat.completions.create(
                model="gpt-4o-mini",
                messages=[
                    {"role": "system", "content": "You are a financial reconciliation assistant. Respond only with valid JSON."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.1,
                max_tokens=200
            )
            
            result_text = response.choices[0].message.content.strip()
            result = eval(result_text)
            
            return result.get("should_match", False), result.get("confidence", 0.0)
            
        except Exception as e:
            # Fallback to rule-based matching if AI fails
            print(f"AI matching failed: {e}")
            return False, 0.0

    def _calculate_match_score(self, invoice: Invoice, transaction: BankTransaction) -> float:
        """
        Calculate match score between invoice and transaction
        
        Priority: AI validation always required > Exact amount > Supplier name > Date
        
        Args:
            invoice: Invoice
            transaction: Bank transaction
            
        Returns:
            Score between 0 and 3
        """
        score = 0
        
        # AI validation (always required to ensure correctness)
        should_match, confidence = self._ai_should_match(invoice, transaction)
        if not should_match or confidence < 0.7:
            return 0
        score += 1.5 * confidence  # AI-based score with confidence weighting
        
        # Exact amount match (bonus for precision)
        if self._amounts_match(invoice.amount, transaction.amount):
            score += 1.0  # Bonus for exact amount match
        
        # Supplier name match (secondary priority - gives confidence)
        if invoice.supplier and self._description_contains_supplier(
            invoice.supplier.name, transaction.description
        ):
            score += 0.5  # Confidence boost
        
        # Date match (tertiary priority - gives additional confidence)
        if self._dates_match(invoice.date, transaction.date):
            score += 0.3  # Additional confidence
        elif self._dates_within_window(invoice.date, transaction.date):
            score += 0.1  # Small confidence for nearby dates
        
        return score
    
    def _amounts_match(self, amount1: float, amount2: float) -> bool:
        """Check if amounts exactly match (allowing opposite signs for payments)"""
        # For payments: invoice (positive) should match transaction (negative)
        # Check if absolute values match within tolerance
        return abs(abs(amount1) - abs(amount2)) < self.amount_tolerance
    
    def _amounts_approximately_match(self, amount1: float, amount2: float) -> bool:
        """Check if amounts approximately match (within 1%) and opposite sign (invoice positive, transaction negative)"""
        if amount1 == 0 or amount2 == 0:
            return False
        # Check opposite sign (invoice positive, transaction negative for payment)
        if (amount1 > 0 and amount2 > 0) or (amount1 < 0 and amount2 < 0):
            return False
        # Check within 1% tolerance (stricter for exact TTC matching)
        return abs(amount1 - amount2) / max(abs(amount1), abs(amount2)) < 0.01
    
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
        
        # Normalize strings (remove accents, lowercase)
        import unicodedata
        def normalize(s):
            return ''.join(c for c in unicodedata.normalize('NFKD', s.lower()) if not unicodedata.combining(c))
        
        supplier_normalized = normalize(supplier_name)
        description_normalized = normalize(description)
        
        # Split supplier name into meaningful words (ignore common words)
        common_words = {'sarl', 'sa', 'sas', 'eurl', 'auto', 'sl', 's', 'l', 'et', 'de', 'la', 'le', 'les', 'du', 'des'}
        supplier_words = [w for w in supplier_normalized.split() if w not in common_words and len(w) > 2]
        
        # Check if any supplier word is in description
        for word in supplier_words:
            if word in description_normalized:
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
