"""
CSV bank statement parser
"""
import pandas as pd
from datetime import datetime
from typing import List, Dict
from dotenv import load_dotenv
import os

# Load environment variables
load_dotenv(os.path.join(os.path.dirname(__file__), '../../config/.env'))

BANK_DATE_FORMAT = os.getenv('BANK_DATE_FORMAT', '%d/%m/%Y')


class CSVParser:
    """Parse CSV bank statements"""
    
    def __init__(self, date_format: str = None):
        self.date_format = date_format or BANK_DATE_FORMAT
    
    def parse(self, file_path: str, column_mapping: Dict = None) -> List[Dict]:
        """
        Parse CSV bank statement
        
        Args:
            file_path: Path to CSV file
            column_mapping: Dictionary mapping expected columns to CSV columns
                Expected columns: 'date', 'amount', 'description', 'reference'
                
        Returns:
            List of transaction dictionaries
        """
        # Default column mapping (common French bank formats)
        if column_mapping is None:
            column_mapping = {
                'date': ['Date', 'date', 'DATE', 'Opération', 'Date opération'],
                'amount': ['Montant', 'montant', 'Amount', 'amount', 'Montant (€)', 'Valeur'],
                'description': ['Description', 'description', 'Libellé', 'Libelle', 'Détail'],
                'reference': ['Référence', 'reference', 'Ref', 'REF']
            }
        
        try:
            df = pd.read_csv(file_path, encoding='utf-8', sep=';', decimal=',')
        except:
            try:
                df = pd.read_csv(file_path, encoding='latin-1', sep=';', decimal=',')
            except:
                df = pd.read_csv(file_path, encoding='utf-8', sep=',', decimal='.')
        
        transactions = []
        
        for _, row in df.iterrows():
            transaction = self._parse_row(row, column_mapping)
            if transaction:
                transactions.append(transaction)
        
        return transactions
    
    def _parse_row(self, row: pd.Series, column_mapping: Dict) -> Dict:
        """Parse a single CSV row"""
        transaction = {
            'date': None,
            'amount': None,
            'description': '',
            'reference': None
        }
        
        # Map columns
        for field, possible_names in column_mapping.items():
            for name in possible_names:
                if name in row.index:
                    value = row[name]
                    
                    if field == 'date':
                        transaction[field] = self._parse_date(value)
                    elif field == 'amount':
                        transaction[field] = self._parse_amount(value)
                    elif field == 'description':
                        transaction[field] = str(value) if pd.notna(value) else ''
                    elif field == 'reference':
                        transaction[field] = str(value) if pd.notna(value) else None
                    
                    if transaction[field] is not None:
                        break
        
        # Generate transaction ID if not present
        if not transaction['reference']:
            transaction['reference'] = self._generate_transaction_id(transaction)
        
        # Validate required fields
        if transaction['date'] and transaction['amount'] is not None:
            return transaction
        
        return None
    
    def _parse_date(self, value) -> datetime:
        """Parse date from various formats"""
        if pd.isna(value):
            return None
        
        if isinstance(value, datetime):
            return value
        
        # Try string parsing
        value_str = str(value).strip()
        
        for fmt in [self.date_format, '%Y-%m-%d', '%d/%m/%Y', '%d-%m-%Y', '%m/%d/%Y']:
            try:
                return datetime.strptime(value_str, fmt)
            except:
                continue
        
        return None
    
    def _parse_amount(self, value) -> float:
        """Parse amount from various formats"""
        if pd.isna(value):
            return None
        
        if isinstance(value, (int, float)):
            return float(value)
        
        # Clean string
        value_str = str(value).strip()
        value_str = value_str.replace(' ', '').replace('€', '').replace('$', '').replace('£', '')
        value_str = value_str.replace(',', '.')
        
        try:
            return float(value_str)
        except:
            return None
    
    def _generate_transaction_id(self, transaction: Dict) -> str:
        """Generate unique transaction ID"""
        date_str = transaction['date'].strftime('%Y%m%d') if transaction['date'] else ''
        amount_str = str(abs(transaction['amount'])) if transaction['amount'] else '0'
        desc_str = transaction['description'][:20] if transaction['description'] else ''
        
        return f"{date_str}_{amount_str}_{desc_str}"
