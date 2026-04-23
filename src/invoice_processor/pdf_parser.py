"""
PDF parsing - Simplified: AI handles all extraction
Only extracts raw text from PDF, no regex pattern matching
"""
import os
from typing import Dict, Optional, List
import pdfplumber
from dotenv import load_dotenv

# Load environment variables
load_dotenv(os.path.join(os.path.dirname(__file__), '../../config/.env'))


class PDFParser:
    """Parse PDF invoices - extract text only, AI handles data extraction"""
    
    def extract_text(self, pdf_path: str) -> str:
        """
        Extract all text from PDF
        
        Args:
            pdf_path: Path to PDF file
            
        Returns:
            Extracted text as string
        """
        text = ""
        try:
            with pdfplumber.open(pdf_path) as pdf:
                for page in pdf.pages:
                    page_text = page.extract_text()
                    if page_text:
                        text += page_text + "\n"
        except Exception as e:
            raise Exception(f"Error extracting text from PDF: {e}")
        
        return text
    
    def extract_invoice_data(self, pdf_path: str) -> Dict:
        """
        Extract structured invoice data from PDF
        
        Args:
            pdf_path: Path to PDF file
            
        Returns:
            Dictionary with invoice fields
        """
        text = self.extract_text(pdf_path)
        return self.extract_invoice_data_from_text(text)
    
    def extract_invoice_data_from_text(self, text: str) -> Dict:
        """Return raw text only - AI handles all structured extraction"""
        return {
            'invoice_number': None,
            'date': None,
            'amount': None,
            'amount_tax': None,
            'due_date': None,
            'supplier_name': None,
            'purchase_order': None,
            'delivery_note': None,
            'vehicle_registration': None,
            'work_order_reference': None,
            'payment_method': None,
            'extraction_warnings': ['ai_extraction_required'],
            'extraction_confidence': 'low',
            'raw_text': text
        }
