"""
CSV bank statement parser using AI
"""
import pandas as pd
from datetime import datetime
from typing import List, Dict
import os
from src.utils.date_parser import parse_date

import src.config  # noqa: F401


class CSVParser:
    """Parse CSV bank statements using AI"""
    
    def parse(self, file_path: str) -> List[Dict]:
        """
        Parse CSV bank statement using AI
        
        Args:
            file_path: Path to CSV file
            
        Returns:
            List of transaction dictionaries
        """
        # Read CSV as text
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                text = f.read()
        except:
            with open(file_path, 'r', encoding='latin-1') as f:
                text = f.read()
        
        return self._ai_extract(text, os.path.basename(file_path))
    
    def _ai_extract(self, text: str, filename: str) -> List[Dict]:
        """Use OpenAI to extract transactions from CSV text"""
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
                "Extract ALL transactions from this French bank statement CSV.\n"
                "Rules:\n"
                "- date: DD/MM/YYYY format\n"
                "- amount: negative for debits/payments, positive for credits/receipts\n"
                "- description: transaction label (libellé)\n"
                "- reference: transaction reference if present, else null\n"
                "Handle both single 'amount' column and separate 'debit'/'credit' columns.\n\n"
                f"CSV content:\n{text}"
            )

            completion = client.beta.chat.completions.parse(
                model=model,
                messages=[
                    {'role': 'system', 'content': 'You are a French bank statement CSV parser. Extract structured transaction data.'},
                    {'role': 'user', 'content': prompt},
                ],
                response_format=_BankStatementExtraction,
                temperature=0,
                max_tokens=16000,
            )
            msg = completion.choices[0].message
            if msg.refusal or msg.parsed is None:
                raise ValueError("AI failed to extract transactions from CSV")

            result = []
            for tx in msg.parsed.transactions:
                date = parse_date(tx.date)
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
