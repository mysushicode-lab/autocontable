"""
Supplier detection and normalization
"""
import re
from difflib import SequenceMatcher
from typing import Optional, Dict, List
from sqlalchemy.orm import Session
from src.storage.models import Supplier


class SupplierClassifier:
    """Classify and normalize supplier names"""
    
    def __init__(self, session: Session):
        self.session = session
        self.supplier_cache = {}
    
    def normalize_name(self, name: str) -> str:
        """
        Normalize supplier name for matching
        
        Args:
            name: Raw supplier name
            
        Returns:
            Normalized name
        """
        if not name:
            return ""
        
        # Convert to lowercase
        normalized = name.lower().strip()
        
        # Remove legal suffixes
        suffixes = [
            r'\bs\.a\.r\.l\b', r'\bs\.a\.s\b', r'\bs\.a\b',
            r'\be\.u\.r\.l\b', r'\bs\.n\.c\b',
            r'\binc\b', r'\bltd\b', r'\bgmbh\b',
            r'\bsarl\b', r'\bsas\b', r'\bsa\b',
            r'\beurl\b', r'\bsnc\b'
        ]
        
        for suffix in suffixes:
            normalized = re.sub(suffix, '', normalized, flags=re.IGNORECASE)
        
        # Remove special characters
        normalized = re.sub(r'[^\w\s]', '', normalized)
        
        # Remove extra whitespace
        normalized = ' '.join(normalized.split())
        
        return normalized
    
    def detect_supplier(self, invoice_data: Dict) -> Optional[Supplier]:
        """
        Detect supplier from invoice data
        Prioritizes supplier_email (extracted from document by AI) as most reliable
        
        Args:
            invoice_data: Dictionary with extracted invoice data
            
        Returns:
            Supplier object or None
        """
        supplier_name = invoice_data.get('supplier_name')
        supplier_email = invoice_data.get('supplier_email')  # From AI extraction
        email_from = invoice_data.get('email_from')  # From email metadata
        
        if not supplier_name and not supplier_email and not email_from:
            return None
        
        # PRIORITY 1: supplier_email from AI (most reliable - extracted from document)
        # But only use domain as name if no supplier_name from PDF
        if supplier_email and not self._is_generic_email(supplier_email):
            email_domain = self._extract_email_domain(supplier_email)
            if email_domain:
                supplier = self._find_by_email_domain(email_domain, supplier_email)
                if supplier:
                    return supplier
                # Create new supplier - prefer supplier_name if available, else use domain
                display_name = supplier_name if supplier_name else email_domain
                return self._create_supplier(display_name, supplier_email, email_domain)
        
        # PRIORITY 2: email_from from email metadata (fallback) - skip generic emails
        if email_from and not self._is_generic_email(email_from):
            email_domain = self._extract_email_domain(email_from)
            if email_domain:
                supplier = self._find_by_email_domain(email_domain, email_from)
                if supplier:
                    return supplier
        
        # PRIORITY 3: Try to find by normalized name from PDF
        if supplier_name:
            normalized = self.normalize_name(supplier_name)
            supplier = self._find_by_normalized_name(normalized)
            if supplier:
                return supplier
            
            # PRIORITY 4: Fuzzy match on similar names (catch "AUTOPARTS PRO" vs "Autoparts Pro SARL")
            similar_supplier = self._find_similar_supplier(supplier_name)
            if similar_supplier:
                # Update with email if we found one
                if supplier_email and not similar_supplier.email:
                    similar_supplier.email = supplier_email
                    if not similar_supplier.email_domain:
                        similar_supplier.email_domain = self._extract_email_domain(supplier_email)
                    self.session.commit()
                return similar_supplier
        
        # Create new supplier - prefer supplier_name, fallback to email domain if not generic
        if supplier_name:
            # Always use supplier_name from document if available
            email_domain = self._extract_email_domain(supplier_email) if supplier_email else None
            return self._create_supplier(supplier_name, supplier_email, email_domain)
        elif supplier_email and not self._is_generic_email(supplier_email):
            # Only use email domain as name if it's a professional domain
            email_domain = self._extract_email_domain(supplier_email)
            display_name = email_domain or supplier_email
            return self._create_supplier(display_name, supplier_email, email_domain)
        elif email_from and not self._is_generic_email(email_from):
            # Only use email_from if it's a professional domain
            email_domain = self._extract_email_domain(email_from)
            display_name = email_domain or email_from
            return self._create_supplier(display_name, email_from, email_domain)
        elif supplier_email:
            # Fallback: use full email as name for generic emails when no supplier_name
            return self._create_supplier(supplier_email, supplier_email, None)
        elif email_from:
            # Fallback: use full email as name for generic emails when no supplier_name
            return self._create_supplier(email_from, email_from, None)
        
        return None
    
    def _is_generic_email(self, email: str) -> bool:
        """Check if email is from generic provider (Gmail, Yahoo, etc.) or email service"""
        # Personal/generic email providers
        generic_domains = ['gmail.com', 'yahoo.com', 'yahoo.fr', 'outlook.com', 
                          'hotmail.com', 'live.com', 'icloud.com', 'me.com', 'aol.com']
        
        # Third-party email services (businessmail, sendinblue, mailjet, etc.)
        email_service_domains = [
            'businessmail.net', 'sendinblue.com', 'mailjet.com', 'sendgrid.net',
            'mailchimp.com', 'brevo.com', 'mailgun.com', 'postmarkapp.com',
            'mailgun.net', 'sparkpostmail.com', 'elasticemail.com', 'pepipost.com',
            'sendpulse.com', 'moosend.com', 'campaignmonitor.com', 'aweber.com',
            'constantcontact.com', 'getresponse.com', 'activehosted.com',
            'emlfiles.com', 'emailservice.io', 'email-srv.com', 'mailersend.net'
        ]
        
        domain = self._extract_email_domain(email)
        if not domain:
            return False
            
        domain_lower = domain.lower()
        return domain_lower in generic_domains or domain_lower in email_service_domains
    
    def _find_by_normalized_name(self, normalized_name: str) -> Optional[Supplier]:
        """Find supplier by normalized name"""
        supplier = self.session.query(Supplier).filter(
            Supplier.normalized_name == normalized_name
        ).first()
        return supplier
    
    def _find_similar_supplier(self, name: str, threshold: float = 0.75) -> Optional[Supplier]:
        """
        Find supplier with similar name using fuzzy matching
        Catches variations like "AUTOPARTS PRO" vs "Autoparts Pro SARL"
        """
        if not name or len(name) < 3:
            return None
        
        # Get all existing suppliers
        all_suppliers = self.session.query(Supplier).all()
        
        best_match = None
        best_ratio = 0.0
        
        normalized_input = self.normalize_name(name)
        
        for supplier in all_suppliers:
            if not supplier.name:
                continue
            
            # Compare normalized names
            normalized_existing = supplier.normalized_name or self.normalize_name(supplier.name)
            
            # Calculate similarity ratio
            ratio = SequenceMatcher(None, normalized_input, normalized_existing).ratio()
            
            # Also check with email domain if available
            if ratio < threshold and supplier.email_domain:
                # Check if input contains domain keywords
                if supplier.email_domain.replace('.', '').replace('-', '') in normalized_input.replace(' ', ''):
                    ratio = max(ratio, 0.8)  # Boost if domain matches
            
            if ratio > best_ratio and ratio >= threshold:
                best_ratio = ratio
                best_match = supplier
        
        return best_match
    
    def _find_by_email_domain(self, email_domain: str, email_from: str = None) -> Optional[Supplier]:
        """Find supplier by email domain and update name to domain if needed"""
        supplier = self.session.query(Supplier).filter(
            Supplier.email_domain == email_domain
        ).first()
        # Update supplier name to domain for consistency
        if supplier and supplier.name != email_domain:
            supplier.name = email_domain
            supplier.normalized_name = self.normalize_name(email_domain)
            self.session.commit()
        return supplier
    
    def _extract_email_domain(self, email: str) -> Optional[str]:
        """Extract domain from email address"""
        match = re.search(r'@([\w.-]+)', email)
        return match.group(1) if match else None
    
    def _create_supplier(self, name: str, email: str = None, email_domain: str = None) -> Supplier:
        """Create new supplier with get_or_create pattern to handle duplicates"""
        normalized = self.normalize_name(name)
        # Extract domain if not provided
        if not email_domain and email:
            email_domain = self._extract_email_domain(email)
        
        # Check if supplier already exists (by normalized_name or email_domain)
        existing = self.session.query(Supplier).filter(
            (Supplier.normalized_name == normalized) | (Supplier.email_domain == email_domain)
        ).first()
        
        if existing:
            return existing
        
        # Create new supplier
        supplier = Supplier(
            name=name,
            normalized_name=normalized,
            email=email,  # Store complete email for reference
            email_domain=email_domain
        )
        
        try:
            self.session.add(supplier)
            self.session.commit()
        except Exception:
            self.session.rollback()
            # Try to fetch again in case of race condition
            existing = self.session.query(Supplier).filter(
                Supplier.normalized_name == normalized
            ).first()
            if existing:
                return existing
            raise
        
        return supplier
