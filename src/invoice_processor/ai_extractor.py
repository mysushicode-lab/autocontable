"""
AI-powered invoice extraction using OpenAI SDK + Structured Outputs.
Uses Pydantic schemas for guaranteed valid JSON — no regex parsing needed.
Methodology: https://platform.openai.com/docs/guides/structured-outputs
"""
import os
import re
import base64
import tempfile
from typing import Dict, List, Optional, Literal
from datetime import datetime
from dotenv import load_dotenv
from pydantic import BaseModel

# Load environment variables
load_dotenv(os.path.join(os.path.dirname(__file__), '../../.env'))

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
- vehicle_registration: French SIV format XX-XXX-XX (e.g. AB-123-CD). No letters O or I allowed. If multiple vehicles on same invoice, return primary one (first mentioned or associated with the work). Return null if not found.
- purchase_order: Bon de commande / PO number. Return null if not found.
- delivery_note: Bon de livraison / BL number. Return null if not found.
- work_order_reference: Ordre de réparation / OR / dossier / numéro de dossier. Return null if not found.
- payment_method: Only "virement", "cheque", or "carte". Return null if not specified.
- category: Classify this expense into ONE of these categories based on the invoice content and supplier:
  "Pièces détachées" — spare parts, auto parts, pneus, batteries, filtres, optiques, parechocs
  "Peinture et vernis" — paint, vernis, apprêt, diluant, abrasifs, produits de peinture (Axalta, PPG, Sikkens, Glasurit)
  "Fournitures atelier" — consommables, colles, mastics, chiffons, ruban, produits nettoyage, protections
  "Sous-traitance" — prestation externe, expertise, contrôle technique, remorquage, géométrie, climatisation
  "Équipement et outillage" — machines, outils, élévateurs, valises diagnostic, ponts, éclairage atelier
  "Énergie et locaux" — électricité, gaz, eau, loyer, charges locatives, sécurité, déchets
  "Assurances et frais" — assurance, RC pro, mutuelle, frais bancaires, expert-comptable, avocat
  "Déplacements et véhicules" — carburant, péages, location véhicule, transport, restaurant, hôtel
  "Informatique et communication" — téléphone, internet, logiciels, logiciel gestion garage, informatique
  "Formation et divers" — formation, cotisations, carte grise, papeterie, divers
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
    vehicle_registration: Optional[str] = None
    purchase_order: Optional[str] = None
    delivery_note: Optional[str] = None
    work_order_reference: Optional[str] = None
    payment_method: Optional[Literal['virement', 'cheque', 'carte']] = None
    category: Optional[Literal[
        'Pièces détachées',
        'Peinture et vernis',
        'Fournitures atelier',
        'Sous-traitance',
        'Équipement et outillage',
        'Énergie et locaux',
        'Assurances et frais',
        'Déplacements et véhicules',
        'Informatique et communication',
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
        self.model = os.getenv('OPENAI_MODEL', 'gpt-4o-mini')
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

    def _call_structured(self, messages: list) -> Dict:
        """Call OpenAI with Structured Outputs — returns guaranteed valid dict"""
        client = self._get_client()
        completion = client.beta.chat.completions.parse(
            model=self.model,
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

    def _post_process(self, raw: Dict) -> Dict:
        """Validate and normalize AI output (dates, plate, supplier fallback, avoir negation)"""
        fields = raw.get('fields') or {}
        print(f"[AI DEBUG] Raw fields from Vision: {fields}")

        fields['date'] = self._parse_date(fields.get('date'))
        fields['due_date'] = self._parse_date(fields.get('due_date'))

        if fields.get('vehicle_registration'):
            fields['vehicle_registration'] = self._validate_plate(fields['vehicle_registration'])

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
            if max(img.size) > 2048:
                img.thumbnail((2048, 2048), Image.LANCZOS)

            with tempfile.NamedTemporaryFile(suffix='.png', delete=False) as tmp:
                img.save(tmp.name, 'PNG')
                tmp_path = tmp.name
            try:
                with open(tmp_path, 'rb') as f:
                    b64 = base64.b64encode(f.read()).decode('utf-8')
            finally:
                os.unlink(tmp_path)

            context = self._build_context(filename, email_from, email_subject, email_body)
            return self._call_structured([
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
            poppler_path = r"C:\poppler\poppler-26.02.0\Library\bin"
            images = convert_from_path(pdf_path, first_page=1, last_page=3, dpi=250,
                                       poppler_path=poppler_path if os.path.exists(poppler_path) else None)
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
            return self._call_structured([
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
            return self._call_structured([
                {'role': 'system', 'content': self._build_system_prompt(own_company_name)},
                {'role': 'user', 'content': user_content}
            ])
        except Exception as e:
            return {'is_invoice': None, 'document_type': 'error', 'confidence': 'low',
                    'reason': f'AI error: {str(e)}', 'fields': {}}

    def _parse_date(self, date_str: Optional[str]) -> Optional[datetime]:
        if not date_str:
            return None
        for fmt in ('%d/%m/%Y', '%d-%m-%Y', '%Y-%m-%d', '%d/%m/%y'):
            try:
                return datetime.strptime(date_str.strip(), fmt)
            except ValueError:
                continue
        return None

    def _validate_plate(self, plate: str) -> Optional[str]:
        """Validate and normalize French SIV license plate (XX-000-XX)"""
        if not plate:
            return None
        cleaned = re.sub(r'[^A-Z0-9]', '', plate.upper())
        if len(cleaned) != 7:
            return None
        valid = (
            cleaned[0].isalpha() and cleaned[1].isalpha() and
            cleaned[2].isdigit() and cleaned[3].isdigit() and cleaned[4].isdigit() and
            cleaned[5].isalpha() and cleaned[6].isalpha() and
            'O' not in cleaned and 'I' not in cleaned
        )
        return (cleaned[:2] + '-' + cleaned[2:5] + '-' + cleaned[5:]) if valid else None
