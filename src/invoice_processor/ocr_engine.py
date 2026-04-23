"""
OCR engine for processing scanned invoices
"""
import os
from PIL import Image
import pytesseract
from typing import Optional
from dotenv import load_dotenv

# Load environment variables
load_dotenv(os.path.join(os.path.dirname(__file__), '../../config/.env'))

TESSERACT_PATH = os.getenv('TESSERACT_PATH')
OCR_LANGUAGE = os.getenv('OCR_LANGUAGE', 'fra+eng')

# Configure Tesseract path if provided
if TESSERACT_PATH:
    pytesseract.pytesseract.tesseract_cmd = TESSERACT_PATH


class OCREngine:
    """OCR engine for extracting text from images/scanned PDFs"""
    
    def __init__(self, language: str = None):
        self.language = language or OCR_LANGUAGE
    
    def extract_text_from_image(self, image_path: str) -> str:
        """
        Extract text from image file
        
        Args:
            image_path: Path to image file
            
        Returns:
            Extracted text
        """
        try:
            image = Image.open(image_path)
            text = pytesseract.image_to_string(image, lang=self.language)
            return text
        except Exception as e:
            raise Exception(f"OCR error: {e}")
    
    def extract_text_from_pdf_page(self, pdf_path: str, page_num: int = 0) -> str:
        """
        Extract text from PDF page using OCR
        
        Args:
            pdf_path: Path to PDF file
            page_num: Page number (0-indexed)
            
        Returns:
            Extracted text
        """
        try:
            from pdf2image import convert_from_path
            
            # Convert PDF page to image
            images = convert_from_path(pdf_path, first_page=page_num+1, last_page=page_num+1, dpi=200)
            
            if images:
                text = pytesseract.image_to_string(images[0], lang=self.language)
                return text
            
            return ""
        except Exception as e:
            # If OCR fails, return empty text - the invoice parser will use pdfplumber as fallback
            print(f"OCR warning for {pdf_path}: {e}")
            return ""
    
    def is_scanned_pdf(self, pdf_path: str) -> bool:
        """
        Check if PDF is scanned (no extractable text)
        
        Args:
            pdf_path: Path to PDF file
            
        Returns:
            True if PDF appears to be scanned
        """
        try:
            import pdfplumber
            
            with pdfplumber.open(pdf_path) as pdf:
                text = ""
                for page in pdf.pages:
                    page_text = page.extract_text()
                    if page_text:
                        text += page_text
                
                # If very little text, likely scanned
                return len(text.strip()) < 50
        except:
            return True
