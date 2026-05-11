"""
OFX bank statement parser using AI
"""
from typing import List, Dict
from datetime import datetime
from dotenv import load_dotenv
import os

load_dotenv(os.path.join(os.path.dirname(__file__), '../../.env'))


class OFXParser:
    """Parse OFX bank statements using AI"""
    
    def parse(self, file_path: str) -> List[Dict]:
        """
        Parse OFX bank statement using AI
        
        Args:
            file_path: Path to OFX file
            
        Returns:
            List of transaction dictionaries
        """
        # Read OFX as text
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            text = f.read()
        
        return self._ai_extract(text, os.path.basename(file_path))
    
    def _ai_extract(self, text: str, filename: str) -> List[Dict]:
        """Use OpenAI to extract transactions from OFX text"""
        api_key = os.getenv('OPENAI_API_KEY')
        if not api_key:
            raise ValueError("OPENAI_API_KEY not configured. Please set it in your .env file.")
        
        try:
            from pydantic import BaseModel
            from openai import OpenAI

            class _Transaction(BaseModel):
                date: str
                amount: float
                description: str
                reference: str = None

            class _BankStatementExtraction(BaseModel):
                transactions: List[_Transaction]

            client = OpenAI(api_key=api_key)
            model = os.getenv('OPENAI_MODEL', 'gpt-4o')

            prompt = (
                f"File: {filename}\n\n"
                "Extract ALL transactions from this French bank statement OFX.\n"
                "Rules:\n"
                "- date: DD/MM/YYYY format\n"
                "- amount: negative for debits/payments, positive for credits/receipts\n"
                "- description: transaction label (libellé)\n"
                "- reference: transaction reference if present, else null\n\n"
                f"OFX content:\n{text}"
            )

            completion = client.beta.chat.completions.parse(
                model=model,
                messages=[
                    {'role': 'system', 'content': 'You are a French bank statement OFX parser. Extract structured transaction data.'},
                    {'role': 'user', 'content': prompt},
                ],
                response_format=_BankStatementExtraction,
                temperature=0,
                max_tokens=16000,
            )
            msg = completion.choices[0].message
            if msg.refusal or msg.parsed is None:
                raise ValueError("AI failed to extract transactions from OFX")

            result = []
            for tx in msg.parsed.transactions:
                date = self._parse_date(tx.date)
                if date is not None and tx.amount is not None:
                    result.append({
                        'date': date,
                        'amount': tx.amount,
                        'description': tx.description or '',
                        'reference': tx.reference,
                    })
            return result if result else []

        except Exception as e:
            raise Exception(f"AI extraction failed: {e}")
    
    def _parse_date(self, value: str) -> datetime:
        if not value:
            return None
        for fmt in ('%d/%m/%Y', '%d/%m/%y', '%d-%m-%Y', '%Y-%m-%d'):
            try:
                return datetime.strptime(value.strip(), fmt)
            except ValueError:
                continue
        return None
