"""
Main invoice processor orchestrating AI extraction, PDF parsing and OCR
"""
import os
from typing import Dict, Optional
from .pdf_parser import PDFParser
from .ocr_engine import OCREngine
from .ai_extractor import AIInvoiceExtractor
from .facturx_extractor import extract_from_facturx
from dotenv import load_dotenv

# Load environment variables
load_dotenv(os.path.join(os.path.dirname(__file__), '../../.env'))


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
        """Process PDF invoice - Vision API for scanned, text API for digital PDFs. OCR only if AI disabled."""
        email_metadata = email_metadata or {}
        filename = os.path.basename(pdf_path)
        email_from = email_metadata.get('email_from', '')
        email_subject = email_metadata.get('email_subject', '')
        email_body = email_metadata.get('email_body', '')

        # Extract text from PDF with pdfplumber
        text = self.pdf_parser.extract_text(pdf_path)
        # Scanned = less than 80 chars of real text extracted (no OCR layer)
        is_scanned = len(text.strip()) < 80

        # Try Factur-X extraction first (free, instant, 100% accurate)
        facturx_data = extract_from_facturx(pdf_path)
        if facturx_data:
            print(f"[Factur-X] Extracted from XML: {facturx_data.get('invoice_number')} — {facturx_data.get('amount')}")
            return {
                'invoice_number': facturx_data.get('invoice_number'),
                'date': facturx_data.get('date'),
                'amount': facturx_data.get('amount'),
                'amount_ht': facturx_data.get('amount_ht'),
                'amount_tax': facturx_data.get('amount_tax'),
                'due_date': facturx_data.get('due_date'),
                'supplier_name': facturx_data.get('supplier_name'),
                'supplier_email': facturx_data.get('supplier_email'),
                'reference_number': None,
                'purchase_order': None,
                'delivery_note': None,
                'work_order_reference': None,
                'payment_method': None,
                'category': facturx_data.get('category'),
                'extraction_warnings': [],
                'extraction_confidence': 'high',
                'is_invoice': True,
                'ai_used': False,
                'vision_used': False,
                'facturx_used': True,
                'raw_text': text
            }

        if self.use_ai and self.ai_extractor and self.ai_extractor.is_enabled():
            # Always use Vision API for better accuracy
            print(f"[AI] Using Vision API for PDF: {filename}")
            ai_result = self.ai_extractor.extract_from_pdf_as_images(
                pdf_path, filename, email_from, email_subject, email_body
            )
            print(f"[AI] Vision result: is_invoice={ai_result.get('is_invoice')}, confidence={ai_result.get('confidence')}, reason={ai_result.get('reason', '')}")

            # Accept document if it has valid fields, even if is_invoice=False (classification may be wrong)
            fields = ai_result.get('fields') or {}
            has_valid_data = fields.get('amount') and fields.get('date')

            if (ai_result.get('is_invoice') and ai_result.get('fields')) or has_valid_data:
                fields = ai_result['fields'] if ai_result.get('fields') else fields
                return {
                    'invoice_number': fields.get('invoice_number'),
                    'date': fields.get('date'),
                    'amount': fields.get('amount'),
                    'amount_ht': fields.get('amount_ht'),
                    'amount_tax': fields.get('amount_tax'),
                    'due_date': fields.get('due_date'),
                    'supplier_name': fields.get('supplier_name'),
                    'supplier_email': fields.get('supplier_email'),
                    'reference_number': fields.get('reference_number'),
                    'purchase_order': fields.get('purchase_order'),
                    'delivery_note': fields.get('delivery_note'),
                    'work_order_reference': fields.get('work_order_reference'),
                    'payment_method': fields.get('payment_method'),
                    'category': fields.get('category'),
                    'extraction_warnings': [],
                    'extraction_confidence': ai_result.get('confidence', 'medium'),
                    'is_invoice': ai_result.get('is_invoice'),
                    'ai_used': True,
                    'vision_used': True,
                    'ai_document_type': ai_result.get('document_type'),
                    'raw_text': text
                }

            if ai_result.get('is_invoice') is False and not has_valid_data:
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

        # LAST RESORT: OCR only when AI is completely disabled
        if self.use_ocr and self.ocr_engine and is_scanned:
            ocr_text = self.ocr_engine.extract_text_from_pdf_page(pdf_path)
            if ocr_text.strip():
                text = ocr_text
        data = self.pdf_parser.extract_invoice_data_from_text(text)
        data['ocr_used'] = is_scanned and not self.use_ai
        data['ai_used'] = False
        return data
    
    def _process_image(self, image_path: str, email_metadata: dict = None) -> Dict:
        """Process image invoice - Vision API only (GPT reads original image). OCR only if AI disabled."""
        email_metadata = email_metadata or {}
        filename = os.path.basename(image_path)
        email_from = email_metadata.get('email_from', '')
        email_subject = email_metadata.get('email_subject', '')
        email_body = email_metadata.get('email_body', '')

        # GPT Vision API reads the original image directly — no OCR needed
        if self.use_ai and self.ai_extractor and self.ai_extractor.is_enabled():
            print(f"[AI] Using Vision API for image: {filename}")
            ai_result = self.ai_extractor.extract_from_image_file(
                image_path, filename, email_from, email_subject, email_body
            )

            if ai_result.get('is_invoice') and ai_result.get('fields'):
                fields = ai_result['fields']
                return {
                    'invoice_number': fields.get('invoice_number'),
                    'date': fields.get('date'),
                    'amount': fields.get('amount'),
                    'amount_ht': fields.get('amount_ht'),
                    'amount_tax': fields.get('amount_tax'),
                    'due_date': fields.get('due_date'),
                    'supplier_name': fields.get('supplier_name'),
                    'supplier_email': fields.get('supplier_email'),
                    'reference_number': fields.get('reference_number'),
                    'purchase_order': fields.get('purchase_order'),
                    'delivery_note': fields.get('delivery_note'),
                    'work_order_reference': fields.get('work_order_reference'),
                    'payment_method': fields.get('payment_method'),
                    'category': fields.get('category'),
                    'extraction_warnings': [],
                    'extraction_confidence': ai_result.get('confidence', 'medium'),
                    'is_invoice': ai_result.get('is_invoice'),
                    'ocr_used': False,
                    'vision_used': True,
                    'ai_used': True,
                    'ai_document_type': ai_result.get('document_type'),
                    'raw_text': ''
                }

            if ai_result.get('is_invoice') is False:
                return {
                    'invoice_number': None,
                    'date': None,
                    'amount': None,
                    'not_an_invoice': True,
                    'ai_document_type': ai_result.get('document_type', 'unknown'),
                    'extraction_confidence': 'low',
                    'ocr_used': False,
                    'vision_used': True,
                    'ai_used': True,
                    'raw_text': ''
                }

        # LAST RESORT: OCR only when AI is completely disabled
        if not self.ocr_engine:
            raise ValueError("OCR engine not enabled and AI is unavailable")
        print(f"[AI] Vision unavailable — using OCR for {filename}")
        text = self.ocr_engine.extract_text_from_image(image_path)
        data = self.pdf_parser.extract_invoice_data_from_text(text)
        data['ocr_used'] = True
        data['vision_used'] = False
        data['ai_used'] = False
        return data
