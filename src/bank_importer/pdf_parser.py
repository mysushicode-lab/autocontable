"""
PDF bank statement parser using pdfplumber + AI extraction (with regex fallback)
"""
import os
import re
from typing import List, Dict, Optional
from datetime import datetime
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(__file__), '../../.env'))


class BankPDFParser:
    """Parse PDF bank statements — AI-first, regex fallback"""

    def parse(self, file_path: str) -> List[Dict]:
        """
        Parse a PDF bank statement.

        Args:
            file_path: Path to the PDF file

        Returns:
            List of transaction dicts with keys: date, amount, description, reference
        """
        text = self._extract_text(file_path)
        if not text.strip():
            raise ValueError("Impossible d'extraire le texte du relevé PDF. Le fichier est peut-être scanné sans OCR.")

        ai_result = self._ai_extract(text, os.path.basename(file_path))
        if ai_result:
            return ai_result

        fallback = self._regex_extract(text)
        if not fallback:
            raise ValueError(
                "Aucune transaction trouvée dans le relevé PDF. "
                "Vérifiez que le fichier est un relevé bancaire lisible (pas un scan)."
            )
        return fallback

    def _extract_text(self, file_path: str) -> str:
        """Extract raw text from PDF using pdfplumber"""
        import pdfplumber
        text = ""
        with pdfplumber.open(file_path) as pdf:
            for page in pdf.pages:
                page_text = page.extract_text()
                if page_text:
                    text += page_text + "\n"
        return text

    def _ai_extract(self, text: str, filename: str) -> Optional[List[Dict]]:
        """Use OpenAI structured outputs to extract transactions"""
        api_key = os.getenv('OPENAI_API_KEY')
        if not api_key:
            return None

        try:
            from pydantic import BaseModel

            class _Transaction(BaseModel):
                date: str
                amount: float
                description: str
                reference: Optional[str] = None

            class _BankStatementExtraction(BaseModel):
                transactions: List[_Transaction]

            from openai import OpenAI
            client = OpenAI(api_key=api_key)
            model = os.getenv('OPENAI_MODEL', 'gpt-4o-mini')

            prompt = (
                f"File: {filename}\n\n"
                "Extract ALL transactions from this French bank statement.\n"
                "Rules:\n"
                "- date: DD/MM/YYYY format\n"
                "- amount: negative for debits/payments, positive for credits/receipts\n"
                "- description: transaction label (libellé)\n"
                "- reference: transaction reference if present, else null\n\n"
                f"Bank statement text:\n{text[:8000]}"
            )

            completion = client.beta.chat.completions.parse(
                model=model,
                messages=[
                    {'role': 'system', 'content': 'You are a French bank statement parser. Extract structured transaction data.'},
                    {'role': 'user', 'content': prompt},
                ],
                response_format=_BankStatementExtraction,
                temperature=0,
                max_tokens=4000,
            )
            msg = completion.choices[0].message
            if msg.refusal or msg.parsed is None:
                return None

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
            return result if result else None

        except Exception:
            return None

    def _regex_extract(self, text: str) -> List[Dict]:
        """Fallback: regex extraction for common French bank statement formats"""
        transactions = []
        pattern = re.compile(
            r'(\d{2}/\d{2}/(?:\d{4}|\d{2}))'
            r'\s+'
            r'(.+?)'
            r'\s+'
            r'(-?\d[\d\s]*[,\.]\d{2})'
            r'\s*$',
            re.MULTILINE,
        )
        for match in pattern.finditer(text):
            date = self._parse_date(match.group(1))
            if date is None:
                continue
            description = match.group(2).strip()
            amount_str = match.group(3).replace(' ', '').replace(',', '.')
            try:
                amount = float(amount_str)
            except ValueError:
                continue
            transactions.append({
                'date': date,
                'amount': amount,
                'description': description,
                'reference': None,
            })
        return transactions

    def _parse_date(self, value: str) -> Optional[datetime]:
        if not value:
            return None
        for fmt in ('%d/%m/%Y', '%d/%m/%y', '%d-%m-%Y', '%Y-%m-%d'):
            try:
                return datetime.strptime(value.strip(), fmt)
            except ValueError:
                continue
        return None
