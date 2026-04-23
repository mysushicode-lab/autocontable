"""
Email client for fetching invoices from mailbox
"""
import os
import email
from email.header import decode_header
from datetime import datetime
from typing import List, Dict, Optional
from dotenv import load_dotenv
from .imap_client import IMAPClient

# Load environment variables
load_dotenv(os.path.join(os.path.dirname(__file__), '../../config/.env'))


class EmailClient:
    """Main email client for invoice ingestion"""
    
    def __init__(self, email_type: str = None):
        self.email_type = email_type or os.getenv('EMAIL_TYPE', 'imap')
        self.client = None
        
        if self.email_type == 'imap':
            self.client = IMAPClient()
    
    def fetch_invoices(
        self,
        folder: str = None,
        search_subject: str = None,
        since_date: datetime = None,
        mark_as_read: bool = False
    ) -> List[Dict]:
        """
        Fetch invoice emails from mailbox
        
        Args:
            folder: Email folder to search (default: from config)
            search_subject: Subject filter (default: from config)
            since_date: Only fetch emails after this date
            mark_as_read: Mark fetched emails as read
            
        Returns:
            List of email dictionaries with attachments
        """
        if not self.client:
            raise NotImplementedError(f"Email type {self.email_type} not implemented")
        
        folder = folder or os.getenv('EMAIL_FOLDER', 'INVOICE')
        search_subject = search_subject or os.getenv('EMAIL_SEARCH_SUBJECT', 'facture')
        
        emails = self.client.fetch_emails(
            folder=folder,
            search_subject=search_subject,
            since_date=since_date,
            mark_as_read=mark_as_read
        )
        
        return emails
    
    def download_attachments(self, email_data: Dict, save_dir: str) -> List[str]:
        """
        Download attachments from an email
        
        Args:
            email_data: Email dictionary
            save_dir: Directory to save attachments
            
        Returns:
            List of saved file paths
        """
        if not self.client:
            raise NotImplementedError(f"Email type {self.email_type} not implemented")
        
        return self.client.download_attachments(email_data, save_dir)
    
    def connect(self):
        """Connect to email server"""
        if self.client:
            self.client.connect()
    
    def disconnect(self):
        """Disconnect from email server"""
        if self.client:
            self.client.disconnect()
