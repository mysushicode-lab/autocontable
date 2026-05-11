"""
PDF bank statement parser using OpenAI AI
"""
import os
import base64
from typing import List, Dict, Optional
from datetime import datetime
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(__file__), '../../.env'))


class BankPDFParser:
    """Parse PDF bank statement using OpenAI AI"""

    def parse(self, file_path: str) -> List[Dict]:
        """
        Parse a PDF bank statement using AI.

        Args:
            file_path: Path to the PDF file

        Returns:
            List of transaction dicts with keys: date, amount, description, reference
        """
        # Try Vision first for scanned documents
        vision_result = self._vision_extract(file_path)
        if vision_result:
            return vision_result

        # Fallback to text extraction with AI
        text = self._extract_text(file_path)
        if not text.strip():
            raise ValueError("Impossible d'extraire le texte du relevé PDF. Le fichier est peut-être corrompu.")

        ai_result = self._ai_extract(text, os.path.basename(file_path))
        if ai_result:
            return ai_result

        raise ValueError(
            "Aucune transaction trouvée dans le relevé PDF. "
            "Vérifiez que le fichier est un relevé bancaire lisible."
        )

    def _vision_extract(self, file_path: str) -> Optional[List[Dict]]:
        """Use OpenAI Vision to extract transactions from PDF images"""
        api_key = os.getenv('OPENAI_API_KEY')
        if not api_key:
            return None

        try:
            from pydantic import BaseModel
            from openai import OpenAI
            import pdf2image

            class _Transaction(BaseModel):
                date: str
                amount: float
                description: str
                reference: Optional[str] = None

            class _BankStatementExtraction(BaseModel):
                transactions: List[_Transaction]

            client = OpenAI(api_key=api_key)
            model = os.getenv('OPENAI_MODEL', 'gpt-4o')

            # Convert PDF to images
            images = pdf2image.convert_from_path(file_path, dpi=200)
            
            # Limit to first 10 pages to avoid timeout
            images = images[:10]

            # Prepare images for API
            image_content = []
            for img in images:
                import io
                buffered = io.BytesIO()
                img.save(buffered, format="PNG")
                img_str = base64.b64encode(buffered.getvalue()).decode()
                image_content.append({
                    "type": "image_url",
                    "image_url": {
                        "url": f"data:image/png;base64,{img_str}",
                        "detail": "high"
                    }
                })

            prompt = (
                "Extract ALL transactions from this French bank statement.\n"
                "Rules:\n"
                "- date: DD/MM/YYYY format\n"
                "- amount: negative for debits/payments, positive for credits/receipts\n"
                "- description: transaction label (libellé)\n"
                "- reference: transaction reference if present, else null\n"
                "Extract ALL transactions visible in these images."
            )

            response = client.chat.completions.create(
                model=model,
                messages=[
                    {
                        'role': 'system',
                        'content': 'You are a French bank statement parser. Extract structured transaction data from bank statement images.'
                    },
                    {
                        'role': 'user',
                        'content': [
                            {"type": "text", "text": prompt},
                            *image_content
                        ]
                    }
                ],
                response_format={"type": "json_object"},
                temperature=0,
                max_tokens=16000,
            )

            import json
            result = json.loads(response.choices[0].message.content)
            
            transactions = []
            for tx in result.get('transactions', []):
                date = self._parse_date(tx.get('date'))
                if date is not None and tx.get('amount') is not None:
                    transactions.append({
                        'date': date,
                        'amount': tx.get('amount'),
                        'description': tx.get('description', ''),
                        'reference': tx.get('reference'),
                    })
            
            return transactions if transactions else None

        except Exception as e:
            print(f"Vision extraction failed: {e}")
            return None

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
        """Use OpenAI to extract transactions from PDF text"""
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
                reference: Optional[str] = None

            class _BankStatementExtraction(BaseModel):
                transactions: List[_Transaction]

            client = OpenAI(api_key=api_key)
            model = os.getenv('OPENAI_MODEL', 'gpt-4o')

            prompt = (
                f"File: {filename}\n\n"
                "Extract ALL transactions from this French bank statement.\n"
                "Rules:\n"
                "- date: DD/MM/YYYY format\n"
                "- amount: negative for debits/payments, positive for credits/receipts\n"
                "- description: transaction label (libellé)\n"
                "- reference: transaction reference if present, else null\n\n"
                f"Bank statement text:\n{text}"
            )

            completion = client.beta.chat.completions.parse(
                model=model,
                messages=[
                    {'role': 'system', 'content': 'You are a French bank statement parser. Extract structured transaction data.'},
                    {'role': 'user', 'content': prompt},
                ],
                response_format=_BankStatementExtraction,
                temperature=0,
                max_tokens=16000,
            )
            msg = completion.choices[0].message
            if msg.refusal or msg.parsed is None:
                raise ValueError("AI failed to extract transactions from PDF")

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

        except Exception as e:
            raise Exception(f"AI extraction failed: {e}")

    def _parse_date(self, value: str) -> Optional[datetime]:
        if not value:
            return None
        for fmt in ('%d/%m/%Y', '%d/%m/%y', '%d-%m-%Y', '%Y-%m-%d'):
            try:
                return datetime.strptime(value.strip(), fmt)
            except ValueError:
                continue
        return None
