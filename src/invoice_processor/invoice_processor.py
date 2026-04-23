"""
Main invoice processor orchestrating AI extraction, PDF parsing and OCR
"""
import os
from typing import Dict, Optional
from .pdf_parser import PDFParser
from .ocr_engine import OCREngine
from .ai_extractor import AIInvoiceExtractor
from dotenv import load_dotenv

# Load environment variables
load_dotenv(os.path.join(os.path.dirname(__file__), '../../config/.env'))


class InvoiceProcessor:
    """Main invoice processing pipeline with AI priority and regex fallback"""
    
    def __init__(self, use_ocr: bool = True, use_ai: bool = True):
        self.pdf_parser = PDFParser()
        self.ocr_engine = OCREngine() if use_ocr else None
        self.ai_extractor = AIInvoiceExtractor() if use_ai else None
        self.use_ocr = use_ocr
        self.use_ai = use_ai
    
    def process_invoice(self, file_path: str, email_metadata: dict = None) -> Dict:
        """
        Process invoice file and extract structured data
        
        Args:
            file_path: Path to invoice file (PDF or image)
            email_metadata: Optional email metadata (from, subject, body) for AI context
            
        Returns:
            Dictionary with extracted invoice data
        """
        email_metadata = email_metadata or {}
        file_ext = os.path.splitext(file_path)[1].lower()
        
        if file_ext == '.pdf':
            return self._process_pdf(file_path, email_metadata)
        elif file_ext in ['.png', '.jpg', '.jpeg', '.tiff', '.bmp']:
            return self._process_image(file_path, email_metadata)
        else:
            raise ValueError(f"Unsupported file format: {file_ext}")
    
    def _process_pdf(self, pdf_path: str, email_metadata: dict = None) -> Dict:
        """Process PDF invoice - AI first, then fallback to regex/OCR"""
        email_metadata = email_metadata or {}
        
        # Extract text from PDF
        text = self.pdf_parser.extract_text(pdf_path)
        
        # Try AI extraction first if enabled
        if self.use_ai and self.ai_extractor and self.ai_extractor.is_enabled():
            ai_result = self.ai_extractor.qualify_document(
                text=text,
                filename=os.path.basename(pdf_path),
                email_from=email_metadata.get('email_from', ''),
                email_subject=email_metadata.get('email_subject', ''),
                email_body=email_metadata.get('email_body', '')
            )
                        # If AI successfully identified as invoice, use its fields
            if ai_result.get('is_invoice') and ai_result.get('fields'):
                fields = ai_result['fields']
                return {
                    'invoice_number': fields.get('invoice_number'),
                    'date': fields.get('date'),
                    'amount': fields.get('amount'),
                    'amount_tax': fields.get('amount_tax'),
                    'due_date': fields.get('due_date'),
                    'supplier_name': fields.get('supplier_name'),
                    'supplier_email': fields.get('supplier_email'),
                    'vehicle_registration': fields.get('vehicle_registration'),
                    'purchase_order': fields.get('purchase_order'),
                    'delivery_note': fields.get('delivery_note'),
                    'work_order_reference': fields.get('work_order_reference'),
                    'payment_method': fields.get('payment_method'),
                    'extraction_warnings': [],
                    'extraction_confidence': ai_result.get('confidence', 'medium'),
                    'ai_used': True,
                    'ai_document_type': ai_result.get('document_type'),
                    'raw_text': text
                }
            
            # If AI says not an invoice, return empty but mark as processed
            if ai_result.get('is_invoice') is False:
                return {
                    'invoice_number': None,
                    'date': None,
                    'amount': None,
                    'not_an_invoice': True,
                    'ai_document_type': ai_result.get('document_type', 'unknown'),
                    'extraction_confidence': 'low',
                    'ai_used': True,
                    'raw_text': text
                }
        
        # Fallback: use regex-based PDF parser
        data = self.pdf_parser.extract_invoice_data_from_text(text)
        data['ai_used'] = False
        
        # Check if OCR is needed (for scanned PDFs)
        if self.use_ocr and self.ocr_engine:
            if not data.get('invoice_number') or self.ocr_engine.is_scanned_pdf(pdf_path):
                ocr_text = self.ocr_engine.extract_text_from_pdf_page(pdf_path)
                if ocr_text.strip():
                    data = self.pdf_parser.extract_invoice_data_from_text(ocr_text)
                data['ocr_used'] = True
            else:
                data['ocr_used'] = False
        else:
            data['ocr_used'] = False
        
        return data
    
    def _process_image(self, image_path: str, email_metadata: dict = None) -> Dict:
        """Process image invoice - AI first, then OCR fallback"""
        email_metadata = email_metadata or {}
        
        if not self.ocr_engine:
            raise ValueError("OCR engine not enabled")
        
        # Always need OCR for images to get text
        text = self.ocr_engine.extract_text_from_image(image_path)
        
        # Try AI extraction first if enabled
        if self.use_ai and self.ai_extractor and self.ai_extractor.is_enabled():
            ai_result = self.ai_extractor.qualify_document(
                text=text,
                filename=os.path.basename(image_path),
                email_from=email_metadata.get('email_from', ''),
                email_subject=email_metadata.get('email_subject', ''),
                email_body=email_metadata.get('email_body', '')
            )
            
            if ai_result.get('is_invoice') and ai_result.get('fields'):
                fields = ai_result['fields']
                return {
                    'invoice_number': fields.get('invoice_number'),
                    'date': fields.get('date'),
                    'amount': fields.get('amount'),
                    'amount_tax': fields.get('amount_tax'),
                    'due_date': fields.get('due_date'),
                    'supplier_name': fields.get('supplier_name'),
                    'supplier_email': fields.get('supplier_email'),
                    'vehicle_registration': fields.get('vehicle_registration'),
                    'purchase_order': fields.get('purchase_order'),
                    'delivery_note': fields.get('delivery_note'),
                    'work_order_reference': fields.get('work_order_reference'),
                    'payment_method': fields.get('payment_method'),
                    'extraction_warnings': [],
                    'extraction_confidence': ai_result.get('confidence', 'medium'),
                    'ocr_used': True,
                    'ai_used': True,
                    'ai_document_type': ai_result.get('document_type'),
                    'raw_text': text
                }
            
            if ai_result.get('is_invoice') is False:
                return {
                    'invoice_number': None,
                    'date': None,
                    'amount': None,
                    'not_an_invoice': True,
                    'ai_document_type': ai_result.get('document_type', 'unknown'),
                    'extraction_confidence': 'low',
                    'ocr_used': True,
                    'ai_used': True,
                    'raw_text': text
                }
        
        # Fallback to regex on OCR text
        data = self.pdf_parser.extract_invoice_data_from_text(text)
        data['ocr_used'] = True
        data['ai_used'] = False
        return data
