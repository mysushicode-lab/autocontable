"""
OFX bank statement parser
"""
from typing import List, Dict
from ofxparse import OfxParser


class OFXParser:
    """Parse OFX bank statements"""
    
    def parse(self, file_path: str) -> List[Dict]:
        """
        Parse OFX bank statement
        
        Args:
            file_path: Path to OFX file
            
        Returns:
            List of transaction dictionaries
        """
        try:
            with open(file_path, 'rb') as f:
                ofx = OfxParser().parse(f)
            
            transactions = []
            
            for account in ofx.accounts:
                for transaction in account.statement.transactions:
                    transactions.append({
                        'date': transaction.date,
                        'amount': float(transaction.amount),
                        'description': transaction.memo or '',
                        'reference': transaction.id or transaction.fitid,
                        'account_number': account.account_id
                    })
            
            return transactions
            
        except Exception as e:
            raise Exception(f"Error parsing OFX file: {e}")
