"""
AI-powered invoice extraction using OpenAI
"""
import os
import json
import re
from typing import Dict, Optional
from datetime import datetime
from dotenv import load_dotenv

# Load environment variables
load_dotenv(os.path.join(os.path.dirname(__file__), '../../config/.env'))


class AIInvoiceExtractor:
    """Extract invoice data using OpenAI GPT"""
    
    def __init__(self):
        self.api_key = os.getenv('OPENAI_API_KEY')
        self.model = os.getenv('OPENAI_MODEL', 'gpt-4o-mini')
        self.enabled = bool(self.api_key)
    
    def is_enabled(self) -> bool:
        return self.enabled
    
    def qualify_document(self, text: str, filename: str, email_from: str = '', email_subject: str = '', email_body: str = '') -> Dict:
        """
        Determine if document is an invoice and extract fields
        
        Returns:
            Dict with is_invoice, document_type, confidence, and extracted fields
        """
        if not self.enabled:
            return {
                'is_invoice': None,
                'document_type': 'unknown',
                'confidence': 'low',
                'reason': 'AI not enabled - no API key',
                'fields': {}
            }
        
        try:
            import requests
            
            prompt = self._build_qualification_prompt(text, filename, email_from, email_subject, email_body)
            
            response = requests.post(
                'https://api.openai.com/v1/chat/completions',
                headers={
                    'Authorization': f'Bearer {self.api_key}',
                    'Content-Type': 'application/json'
                },
                json={
                    'model': self.model,
                    'messages': [
                        {'role': 'system', 'content': 'You are an expert invoice analyzer. Extract structured data from French invoices.'},
                        {'role': 'user', 'content': prompt}
                    ],
                    'temperature': 0.1,
                    'max_tokens': 1000
                },
                timeout=30
            )
            
            response.raise_for_status()
            result = response.json()
            ai_text = result['choices'][0]['message']['content']
            
            # Parse JSON from AI response
            return self._parse_ai_response(ai_text)
            
        except Exception as e:
            return {
                'is_invoice': None,
                'document_type': 'error',
                'confidence': 'low',
                'reason': f'AI error: {str(e)}',
                'fields': {}
            }
    
    def _build_qualification_prompt(self, text: str, filename: str, email_from: str, email_subject: str, email_body: str = '') -> str:
        email_body_section = f"\nEmail body content:\n{email_body[:1500]}\n" if email_body else ""
        email_subject_section = f"\nEmail subject line: {email_subject}\n" if email_subject else ""
        
        return f"""Analyze this document and determine if it's an invoice.

Document text (from PDF/image):
{text[:2500]}
{email_subject_section}{email_body_section}
Respond with ONLY a JSON object in this exact format:
{{
    "is_invoice": true/false,
    "document_type": "invoice/avoir/devis/avis_paiement/autre",
    "confidence": "high/medium/low",
    "reason": "brief explanation",
    "fields": {{
        "invoice_number": "... or null",
        "date": "DD/MM/YYYY or null",
        "amount": "1234.56 or null",
        "amount_tax": "123.45 or null",
        "due_date": "DD/MM/YYYY or null",
        "supplier_name": "... or null",
        "supplier_email": "... or null",
        "vehicle_registration": "AB-123-CD or null",
        "purchase_order": "... or null",
        "delivery_note": "... or null",
        "work_order_reference": "... or null",
        "payment_method": "virement/cheque/carte or null"
    }}
}}

Rules for invoice_number:
- PRIORITY 1: Extract from PDF document header (look for "Facture N°", "No facture", "Invoice #")
- PRIORITY 2: If not found in PDF, check email subject line (e.g., "Facture N° FA123456 du 15/04/2026")
- PRIORITY 3: If still not found, return null
- Common patterns: FAC123456, FACT-2026-001, 2026-001234, FA123456

Rules for supplier_name (factures reçues uniquement):
- Extract the VENDOR/SELLER name from the document (who is billing you, NOT the customer)
- PRIORITY 1: Company name clearly stated in header/logo (e.g., "AUTOPARTS PRO", "CARROSSERIE SERVICES SARL")
- PRIORITY 2: Name with SIRET/SIREN, TVA number, or professional address
- Look in: en-tête fournisseur, logo, bloc coordonnées en haut à gauche/droite
- IGNORE: names of accounting software (Sage, Ciel, EBP, QuickBooks, etc.)
- IGNORE: your own company name (you are the customer/buyer)
- If name unclear but email found, use domain as fallback

Rules for supplier_email:
- Look in PRIORITY ORDER:
  1. PDF header/vendor block (en-tête fournisseur, coordonnées)
  2. Email body text (phrases mentioning supplier contact)
- IGNORE emails in: client block, adresse de facturation/livraison, "à l'attention de"
- IGNORE: Gmail, Yahoo, Outlook, third-party services (businessmail, sendinblue, etc.)
- Return: the professional domain of the actual seller

Other rules:
- is_invoice: true for facture, avoir, note de frais
- amount: total TTC (à payer)
- vehicle_registration: French format XX-XXX-XX (no O/I)
- Return null for fields not found
- confidence: high/medium/low based on completeness"""
    
    def _parse_ai_response(self, text: str) -> Dict:
        """Parse JSON from AI response"""
        try:
            # Extract JSON from response
            json_match = re.search(r'\{.*\}', text, re.DOTALL)
            if not json_match:
                return {
                    'is_invoice': None,
                    'document_type': 'error',
                    'confidence': 'low',
                    'reason': 'No JSON found in AI response',
                    'fields': {}
                }
            
            data = json.loads(json_match.group())
            
            # Validate and normalize
            is_invoice = data.get('is_invoice', False)
            document_type = data.get('document_type', 'unknown')
            confidence = data.get('confidence', 'low')
            reason = data.get('reason', '')
            fields = data.get('fields', {})
            
            # Parse amount
            amount = None
            if fields.get('amount'):
                try:
                    amount = float(str(fields['amount']).replace(',', '.').replace(' ', ''))
                except:
                    pass
            
            # Parse amount_tax
            amount_tax = None
            if fields.get('amount_tax'):
                try:
                    amount_tax = float(str(fields['amount_tax']).replace(',', '.').replace(' ', ''))
                except:
                    pass
            
            # Parse dates
            date = self._parse_date(fields.get('date'))
            due_date = self._parse_date(fields.get('due_date'))
            
            # Validate vehicle registration
            vehicle_reg = fields.get('vehicle_registration')
            if vehicle_reg:
                vehicle_reg = self._validate_plate(vehicle_reg)
            
            # Extract supplier_email and clean domain
            supplier_email = fields.get('supplier_email')
            supplier_name = fields.get('supplier_name')
            
            # If no supplier_name but has email domain, use domain as name
            if not supplier_name and supplier_email:
                if '@' in supplier_email:
                    domain = supplier_email.split('@')[1]
                    # Ignore Gmail, Yahoo, Outlook
                    if domain.lower() not in ['gmail.com', 'yahoo.com', 'yahoo.fr', 'outlook.com', 'hotmail.com', 'live.com']:
                        supplier_name = domain
            
            return {
                'is_invoice': is_invoice,
                'document_type': document_type,
                'confidence': confidence,
                'reason': reason,
                'fields': {
                    'invoice_number': fields.get('invoice_number'),
                    'date': date,
                    'amount': amount,
                    'amount_tax': amount_tax,
                    'due_date': due_date,
                    'supplier_name': supplier_name,
                    'supplier_email': supplier_email,
                    'vehicle_registration': vehicle_reg,
                    'purchase_order': fields.get('purchase_order'),
                    'delivery_note': fields.get('delivery_note'),
                    'work_order_reference': fields.get('work_order_reference'),
                    'payment_method': fields.get('payment_method')
                }
            }
            
        except Exception as e:
            return {
                'is_invoice': None,
                'document_type': 'error',
                'confidence': 'low',
                'reason': f'Failed to parse AI response: {str(e)}',
                'fields': {}
            }
    
    def _parse_date(self, date_str: Optional[str]) -> Optional[datetime]:
        if not date_str:
            return None
        
        formats = ['%d/%m/%Y', '%d-%m-%Y', '%Y-%m-%d', '%d/%m/%y']
        for fmt in formats:
            try:
                return datetime.strptime(date_str.strip(), fmt)
            except:
                continue
        return None
    
    def _validate_plate(self, plate: str) -> Optional[str]:
        """Validate French license plate format"""
        if not plate:
            return None
        
        cleaned = re.sub(r'[^A-Z0-9]', '', plate.upper())
        
        # SIV format: AB123CD (7 chars, XX000XX)
        if len(cleaned) != 7:
            return None
        
        # Check format: LLDDDLL (L=letter, D=digit)
        format_check = (
            cleaned[0].isalpha() and
            cleaned[1].isalpha() and
            cleaned[2].isdigit() and
            cleaned[3].isdigit() and
            cleaned[4].isdigit() and
            cleaned[5].isalpha() and
            cleaned[6].isalpha()
        )
        
        if not format_check:
            return None
        
        # Check for invalid letters (O and I not used in French plates)
        if 'O' in cleaned or 'I' in cleaned:
            return None
        
        return cleaned[:2] + '-' + cleaned[2:5] + '-' + cleaned[5:]
