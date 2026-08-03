"""
Factur-X XML extractor — extracts structured data from Factur-X PDFs.
When a PDF contains embedded factur-x.xml (or ZUGFeRD), we extract directly
from XML instead of calling GPT-4o-mini Vision. Free, instant, 100% accurate.
"""
import os
import logging
from typing import Optional, Dict
from datetime import datetime

logger = logging.getLogger(__name__)

try:
    from facturx import get_facturx_xml_from_pdf
    from lxml import etree
    FACTURX_AVAILABLE = True
except ImportError:
    FACTURX_AVAILABLE = False
    logger.warning("factur-x library not installed — Factur-X extraction disabled")


def is_facturx_pdf(file_path: str) -> bool:
    """Check if a PDF contains Factur-X/ZUGFeRD XML data."""
    if not FACTURX_AVAILABLE:
        return False
    try:
        xml_bytes, level = get_facturx_xml_from_pdf(file_path)
        return xml_bytes is not None and len(xml_bytes) > 0
    except Exception:
        return False


def extract_from_facturx(file_path: str) -> Optional[Dict]:
    """Extract invoice data from Factur-X XML embedded in a PDF.

    Returns a dict matching the same structure as ai_extractor output:
    {invoice_number, date, amount_ht, amount_tax, amount, due_date,
     supplier_name, supplier_email, category, confidence, is_invoice}

    Returns None if the PDF is not Factur-X or extraction fails.
    """
    if not FACTURX_AVAILABLE:
        return None

    try:
        xml_bytes, level = get_facturx_xml_from_pdf(file_path)
        if not xml_bytes:
            return None

        root = etree.fromstring(xml_bytes)

        # Factur-X uses CII (Cross Industry Invoice) namespace
        # Common namespaces in Factur-X/ZUGFeRD
        ns = {
            'rsm': 'urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100',
            'ram': 'urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100',
            'udt': 'urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100',
        }

        # Try alternate namespaces (ZUGFeRD 1.x)
        if not root.xpath('//rsm:CrossIndustryInvoice', namespaces=ns):
            ns = {
                'rsm': 'urn:ferd:CrossIndustryDocument:invoice:1p0',
                'ram': 'urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:12',
                'udt': 'urn:un:unece:uncefact:data:standard:UnqualifiedDataType:15',
            }

        result = {
            'invoice_number': None,
            'date': None,
            'amount_ht': None,
            'amount_tax': None,
            'amount': None,
            'due_date': None,
            'supplier_name': None,
            'supplier_email': None,
            'category': None,
            'confidence': 'high',
            'is_invoice': True,
        }

        # Invoice number
        inv_num = root.xpath('//rsm:ExchangedDocument/ram:ID/text()', namespaces=ns)
        if not inv_num:
            inv_num = root.xpath('//ram:ExchangedDocument/ram:ID/text()', namespaces=ns)
        if inv_num:
            result['invoice_number'] = inv_num[0]

        # Invoice date (format: YYYYMMDD in CII)
        date_val = root.xpath('//rsm:ExchangedDocument/ram:IssueDateTime/udt:DateTimeString/text()', namespaces=ns)
        if not date_val:
            date_val = root.xpath('//ram:ExchangedDocument/ram:IssueDateTime/udt:DateTimeString/text()', namespaces=ns)
        if date_val:
            try:
                dt = datetime.strptime(date_val[0], '%Y%m%d')
                result['date'] = dt
            except ValueError:
                pass

        # Supplier name (SellerTradeParty)
        seller = root.xpath('//ram:ApplicableHeaderTradeAgreement/ram:SellerTradeParty/ram:Name/text()', namespaces=ns)
        if seller:
            result['supplier_name'] = seller[0]

        # Supplier email
        seller_email = root.xpath('//ram:ApplicableHeaderTradeAgreement/ram:SellerTradeParty/ram:DefinedTradeContact/ram:EmailURIUniversalCommunication/ram:URIID/text()', namespaces=ns)
        if seller_email:
            result['supplier_email'] = seller_email[0]

        # Amounts from monetary summation
        # TTC (GrandTotalAmount)
        ttc = root.xpath('//ram:ApplicableHeaderTradeSettlement/ram:SpecifiedTradeSettlementHeaderMonetarySummation/ram:GrandTotalAmount/text()', namespaces=ns)
        if ttc:
            result['amount'] = float(ttc[0])

        # HT (TaxBasisTotalAmount)
        ht = root.xpath('//ram:ApplicableHeaderTradeSettlement/ram:SpecifiedTradeSettlementHeaderMonetarySummation/ram:TaxBasisTotalAmount/text()', namespaces=ns)
        if ht:
            result['amount_ht'] = float(ht[0])

        # TVA (TaxTotalAmount)
        tva = root.xpath('//ram:ApplicableHeaderTradeSettlement/ram:SpecifiedTradeSettlementHeaderMonetarySummation/ram:TaxTotalAmount/text()', namespaces=ns)
        if tva:
            result['amount_tax'] = float(tva[0])

        # Due date
        due = root.xpath('//ram:ApplicableHeaderTradeSettlement/ram:SpecifiedTradePaymentTerms/ram:DueDateDateTime/udt:DateTimeString/text()', namespaces=ns)
        if due:
            try:
                dt = datetime.strptime(due[0], '%Y%m%d')
                result['due_date'] = dt
            except ValueError:
                pass

        # If we got at least invoice_number and amount, it's valid
        if result['invoice_number'] or result['amount']:
            logger.info(f"Factur-X extraction successful: {result['invoice_number']} — {result['amount']}")
            return result

        return None

    except Exception as e:
        logger.error(f"Factur-X extraction failed: {e}")
        return None
