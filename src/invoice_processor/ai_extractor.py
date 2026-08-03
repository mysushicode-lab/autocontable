"""
AI-powered invoice extraction using OpenAI SDK + Structured Outputs.
Uses Pydantic schemas for guaranteed valid JSON — no regex parsing needed.
Methodology: https://platform.openai.com/docs/guides/structured-outputs
"""
import os
import re
import base64
import tempfile
import logging
from typing import Dict, List, Optional, Literal
from datetime import datetime
from dotenv import load_dotenv
from pydantic import BaseModel
from src.utils.date_parser import parse_date

# Load environment variables
load_dotenv(os.path.join(os.path.dirname(__file__), '../../.env'))

logger = logging.getLogger(__name__)

# Fallback model configuration
AI_PRIMARY_MODEL = os.getenv("AI_PRIMARY_MODEL", "gpt-4o-mini")
AI_FALLBACK_MODEL = os.getenv("AI_FALLBACK_MODEL", "")  # e.g., "gpt-4o" or empty to disable
AI_MAX_RETRIES = int(os.getenv("AI_MAX_RETRIES", "2"))

_SYSTEM_PROMPT = """You are an expert accounting assistant specializing in French business invoices (factures).
Your task: carefully read the document and extract every invoice field with maximum accuracy.
Never invent or guess values — only extract what is explicitly visible in the document."""

_EXTRACTION_RULES = """
Field extraction rules:
- invoice_number: Look for "Facture N°", "N° facture", "Invoice #", "Réf. facture". If absent from document, check email subject. Patterns: FAC123456, FACT-2026-001, FA123456, 2026-001234. Return null if not found.
- date: Invoice issue date formatted as DD/MM/YYYY. Return null if not found.
- amount_ht: Total HT (hors taxes / net amount before VAT). Look for "Total HT", "Montant HT", "Net HT", "Base HT". Return as a decimal number. Return null if not found.
- amount_tax: TVA amount only. Look for "TVA", "Montant TVA", "T.V.A". Return as a decimal number. Return null if not found.
- amount: Total TTC (toutes taxes comprises) — the final amount to pay. Look for "Total TTC", "Net à payer", "Montant TTC". Return as a decimal number. If only HT and TVA found, you may compute TTC = HT + TVA. Return null if not found.
  Note: For accounting — amount_ht is used for journal entries (charge), amount_tax for TVA recovery, amount for bank reconciliation.
- due_date: Payment due date formatted as DD/MM/YYYY. Return null if not found.
- supplier_name: The VENDOR/SELLER company name — the entity issuing this invoice (the one being PAID). It is ALWAYS found at the very TOP of the document in the letterhead/header block, associated with their SIRET/SIREN/TVA number and address. NEVER pick the company in the "Facturer à", "Client", "Adresse de livraison" or recipient address block — that is the BUYER, not the supplier. IGNORE: accounting software names (Sage, Ciel, EBP, QuickBooks, Pennylane, etc.). Return null if not found.
- supplier_email: Professional email of the vendor/seller, found in their header block only. IGNORE: emails in client/buyer address blocks. IGNORE: free email services (Gmail, Yahoo, Outlook, Hotmail). Return null if not found.
- reference_number: Any reference number present on the invoice: license plate, project number, internal reference, order number, dossier number. Return null if not found.
- purchase_order: Bon de commande / PO number. Return null if not found.
- delivery_note: Bon de livraison / BL number. Return null if not found.
- work_order_reference: Internal reference / dossier / numéro de dossier / order reference. Return null if not found.
- payment_method: Only "virement", "cheque", or "carte". Return null if not specified.
- category: Classify this expense into ONE of these universal categories based on invoice content and supplier:
  "Achats de marchandises" — goods, products, merchandise, stock, raw materials, components, parts
  "Fournitures et consommables" — office supplies, workshop consumables, cleaning products, packaging, hardware
  "Sous-traitance" — subcontracting, external services, freelance, consulting missions, technical interventions
  "Équipement et outillage" — tools, machines, equipment, furniture, computers, printers, screens
  "Énergie et locaux" — electricity, gas, water, rent, property charges, security, waste, building insurance
  "Assurances et frais" — insurance, bank fees, legal fees, accountant, loans, leasing, social contributions
  "Déplacements et transports" — fuel, toll, parking, transport, accommodation, meals, travel
  "Informatique et communication" — phone, internet, software, SaaS, hosting, domain names, IT equipment
  "Services et prestations" — consulting, audit, marketing, advertising, maintenance, cleaning, delivery
  "Formation et divers" — training, certifications, memberships, trade shows, miscellaneous
  Return null if unclear.
- is_invoice: true for facture, avoir, note de frais, note de crédit. false for devis, bon de commande, bon de livraison, contrat, etc.
- confidence: "high" if invoice_number + date + amount + supplier_name all found; "medium" if most found; "low" if few found."""


class _InvoiceFields(BaseModel):
    invoice_number: Optional[str] = None
    date: Optional[str] = None
    amount_ht: Optional[float] = None
    amount_tax: Optional[float] = None
    amount: Optional[float] = None
    due_date: Optional[str] = None
    supplier_name: Optional[str] = None
    supplier_email: Optional[str] = None
    reference_number: Optional[str] = None
    purchase_order: Optional[str] = None
    delivery_note: Optional[str] = None
    work_order_reference: Optional[str] = None
    payment_method: Optional[Literal['virement', 'cheque', 'carte']] = None
    category: Optional[Literal[
        'Achats de marchandises',
        'Fournitures et consommables',
        'Sous-traitance',
        'Équipement et outillage',
        'Énergie et locaux',
        'Assurances et frais',
        'Déplacements et transports',
        'Informatique et communication',
        'Services et prestations',
        'Formation et divers'
    ]] = None


class _InvoiceExtraction(BaseModel):
    is_invoice: bool
    document_type: Literal['invoice', 'avoir', 'devis', 'avis_paiement', 'autre']
    confidence: Literal['high', 'medium', 'low']
    reason: str
    fields: _InvoiceFields


class AIInvoiceExtractor:
    """Extract invoice data using OpenAI SDK with Structured Outputs (Pydantic)"""

    def __init__(self):
        self.api_key = os.getenv('OPENAI_API_KEY')
        self.model = AI_PRIMARY_MODEL
        self.enabled = bool(self.api_key)
        self._client = None

    def is_enabled(self) -> bool:
        return self.enabled

    def _get_client(self):
        if self._client is None:
            from openai import OpenAI
            self._client = OpenAI(api_key=self.api_key)
        return self._client

    def _build_context(self, filename: str, email_from: str, email_subject: str, email_body: str) -> str:
        parts = [f"Filename: {filename}"]
        if email_from:
            parts.append(f"Email from: {email_from}")
        if email_subject:
            parts.append(f"Email subject: {email_subject}")
        if email_body:
            parts.append(f"Email body:\n{email_body[:3000]}")
        return "\n".join(parts)

    def _build_system_prompt(self, own_company_name: str = '') -> str:
        extra = ''
        if own_company_name:
            extra = f"\nCRITICAL: The buyer's company (YOUR client) is '{own_company_name}'. NEVER extract this name as supplier_name — it is the buyer, not the vendor."
        return _SYSTEM_PROMPT + extra + _EXTRACTION_RULES

    def _call_structured(self, messages: list, model: str = None) -> Dict:
        """Call OpenAI with Structured Outputs — returns guaranteed valid dict"""
        client = self._get_client()
        model_to_use = model or self.model
        completion = client.beta.chat.completions.parse(
            model=model_to_use,
            messages=messages,
            response_format=_InvoiceExtraction,
            temperature=0,
            max_tokens=2000,
        )
        msg = completion.choices[0].message
        if msg.refusal:
            return {'is_invoice': None, 'document_type': 'error', 'confidence': 'low',
                    'reason': f'Model refusal: {msg.refusal}', 'fields': {}}
        result = msg.parsed
        if result is None:
            return {'is_invoice': None, 'document_type': 'error', 'confidence': 'low',
                    'reason': 'Empty structured response', 'fields': {}}
        raw = result.model_dump()
        return self._post_process(raw)

    def _call_with_retry(self, messages: list) -> Dict:
        """Call OpenAI with retry logic and fallback model support."""
        # Try primary model with retries
        for attempt in range(AI_MAX_RETRIES):
            try:
                result = self._call_structured(messages, model=AI_PRIMARY_MODEL)
                if result and result.get('document_type') != 'error':
                    return result
                logger.warning(f"AI extraction attempt {attempt + 1} returned error result ({AI_PRIMARY_MODEL})")
            except Exception as e:
                logger.warning(f"AI extraction attempt {attempt + 1} failed ({AI_PRIMARY_MODEL}): {e}")
                if attempt < AI_MAX_RETRIES - 1:
                    import time
                    time.sleep(2 ** attempt)  # Exponential backoff

        # Try fallback model if configured
        if AI_FALLBACK_MODEL:
            try:
                logger.info(f"Trying fallback model: {AI_FALLBACK_MODEL}")
                result = self._call_structured(messages, model=AI_FALLBACK_MODEL)
                if result and result.get('document_type') != 'error':
                    return result
                logger.error(f"Fallback model returned error result ({AI_FALLBACK_MODEL})")
            except Exception as e:
                logger.error(f"Fallback model failed ({AI_FALLBACK_MODEL}): {e}")

        # All attempts failed
        return {'is_invoice': None, 'document_type': 'error', 'confidence': 'low',
                'reason': 'All AI extraction attempts failed', 'fields': {}}

    def _post_process(self, raw: Dict) -> Dict:
        """Validate and normalize AI output (dates, plate, supplier fallback, avoir negation)"""
        fields = raw.get('fields') or {}
        print(f"[AI DEBUG] Raw fields from Vision: {fields}")

        fields['date'] = parse_date(fields.get('date'))
        fields['due_date'] = parse_date(fields.get('due_date'))

        if fields.get('reference_number'):
            fields['reference_number'] = self._normalize_reference(fields['reference_number'])

        supplier_name = fields.get('supplier_name')
        supplier_email = fields.get('supplier_email')
        if not supplier_name and supplier_email and '@' in supplier_email:
            domain = supplier_email.split('@')[1].lower()
            _free = {'gmail.com', 'yahoo.com', 'yahoo.fr', 'outlook.com', 'hotmail.com', 'live.com'}
            if domain not in _free:
                fields['supplier_name'] = domain

        # Avoirs: negate all amounts (credit notes reduce charges and TVA)
        if raw.get('document_type') == 'avoir':
            for key in ('amount', 'amount_ht', 'amount_tax'):
                if fields.get(key) is not None and fields[key] > 0:
                    fields[key] = -fields[key]

        raw['fields'] = fields
        print(f"[AI DEBUG] Post-processed fields: amount={fields.get('amount')}, date={fields.get('date')}, supplier={fields.get('supplier_name')}")
        return raw

    def extract_from_image_file(self, image_path: str, filename: str,
                                 email_from: str = '', email_subject: str = '', email_body: str = '',
                                 own_company_name: str = '') -> Dict:
        """
        Extract invoice data from an image using GPT Vision + Structured Outputs.
        GPT reads the original image directly — no OCR intermediate step.
        """
        if not self.enabled:
            return {'is_invoice': None, 'document_type': 'unknown', 'confidence': 'low',
                    'reason': 'AI not enabled', 'fields': {}}
        try:
            from PIL import Image
            img = Image.open(image_path)
            if img.mode not in ('RGB', 'L'):
                img = img.convert('RGB')
            _max_img = int(os.getenv("AI_MAX_IMAGE_SIZE", 2048))
            if max(img.size) > _max_img:
                img.thumbnail((_max_img, _max_img), Image.LANCZOS)

            with tempfile.NamedTemporaryFile(suffix='.png', delete=False) as tmp:
                img.save(tmp.name, 'PNG')
                tmp_path = tmp.name
            try:
                with open(tmp_path, 'rb') as f:
                    b64 = base64.b64encode(f.read()).decode('utf-8')
            finally:
                os.unlink(tmp_path)

            context = self._build_context(filename, email_from, email_subject, email_body)
            return self._call_with_retry([
                {'role': 'system', 'content': self._build_system_prompt(own_company_name)},
                {'role': 'user', 'content': [
                    {'type': 'text', 'text': context},
                    {'type': 'image_url', 'image_url': {'url': f'data:image/png;base64,{b64}', 'detail': 'high'}}
                ]}
            ])
        except Exception as e:
            return {'is_invoice': None, 'document_type': 'error', 'confidence': 'low',
                    'reason': f'Vision error: {str(e)}', 'fields': {}}

    def extract_from_pdf_as_images(self, pdf_path: str, filename: str,
                                    email_from: str = '', email_subject: str = '', email_body: str = '',
                                    own_company_name: str = '') -> Dict:
        """
        Convert PDF pages to images and extract with Vision + Structured Outputs.
        Sends up to 3 pages simultaneously for multi-page invoices.
        Best for scanned PDFs — GPT reads original document layout directly.
        """
        if not self.enabled:
            return {'is_invoice': None, 'document_type': 'unknown', 'confidence': 'low',
                    'reason': 'AI not enabled', 'fields': {}}
        try:
            from pdf2image import convert_from_path
            poppler_path = os.getenv("POPPLER_PATH", "")
            _max_pages = int(os.getenv("AI_MAX_PDF_PAGES", 3))
            images = convert_from_path(pdf_path, first_page=1, last_page=_max_pages, dpi=250,
                                       poppler_path=poppler_path if poppler_path and os.path.exists(poppler_path) else None)
            if not images:
                return {'is_invoice': None, 'document_type': 'error', 'confidence': 'low',
                        'reason': 'Could not convert PDF to image', 'fields': {}}

            image_contents = []
            tmp_paths = []
            for img in images:
                with tempfile.NamedTemporaryFile(suffix='.png', delete=False) as tmp:
                    img.save(tmp.name, 'PNG')
                    tmp_paths.append(tmp.name)
            try:
                for p in tmp_paths:
                    with open(p, 'rb') as f:
                        b64 = base64.b64encode(f.read()).decode('utf-8')
                    image_contents.append({
                        'type': 'image_url',
                        'image_url': {'url': f'data:image/png;base64,{b64}', 'detail': 'high'}
                    })
            finally:
                for p in tmp_paths:
                    os.unlink(p)

            context = self._build_context(filename, email_from, email_subject, email_body)
            return self._call_with_retry([
                {'role': 'system', 'content': self._build_system_prompt(own_company_name)},
                {'role': 'user', 'content': [{'type': 'text', 'text': context}] + image_contents}
            ])
        except Exception as e:
            return {'is_invoice': None, 'document_type': 'error', 'confidence': 'low',
                    'reason': f'PDF Vision error: {str(e)}', 'fields': {}}

    def qualify_document(self, text: str, filename: str,
                          email_from: str = '', email_subject: str = '', email_body: str = '',
                          own_company_name: str = '') -> Dict:
        """
        Extract invoice fields from digital PDF text using Structured Outputs.
        Used when pdfplumber can extract reliable text (no vision needed).
        """
        if not self.enabled:
            return {'is_invoice': None, 'document_type': 'unknown', 'confidence': 'low',
                    'reason': 'AI not enabled', 'fields': {}}
        try:
            context = self._build_context(filename, email_from, email_subject, email_body)
            user_content = f"{context}\n\nDocument text:\n{text[:5000]}"
            return self._call_with_retry([
                {'role': 'system', 'content': self._build_system_prompt(own_company_name)},
                {'role': 'user', 'content': user_content}
            ])
        except Exception as e:
            return {'is_invoice': None, 'document_type': 'error', 'confidence': 'low',
                    'reason': f'AI error: {str(e)}', 'fields': {}}

    def _normalize_reference(self, ref: str) -> Optional[str]:
        """Normalize reference number - uppercase, strip spaces, validate French plates if pattern matches"""
        if not ref:
            return None
        # Basic normalization: uppercase and strip spaces
        normalized = ref.upper().strip()

        # If it looks like a French license plate (XX-NNN-XX or similar), validate it
        cleaned = re.sub(r'[^A-Z0-9]', '', normalized)
        if len(cleaned) == 7:
            # Check if it matches French SIV plate pattern
            valid_plate = (
                cleaned[0].isalpha() and cleaned[1].isalpha() and
                cleaned[2].isdigit() and cleaned[3].isdigit() and cleaned[4].isdigit() and
                cleaned[5].isalpha() and cleaned[6].isalpha() and
                'O' not in cleaned and 'I' not in cleaned
            )
            if valid_plate:
                return cleaned[:2] + '-' + cleaned[2:5] + '-' + cleaned[5:]

        # Otherwise, just return the normalized reference
        return normalized
