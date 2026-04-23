"""
IMAP client implementation for email fetching
"""
import os
import re
import email
import imaplib
import hashlib
from email.header import decode_header
from datetime import datetime
from typing import List, Dict, Optional
from dotenv import load_dotenv

# Load environment variables
load_dotenv(os.path.join(os.path.dirname(__file__), '../../config/.env'))

SUPPORTED_ATTACHMENT_EXTENSIONS = ('.pdf', '.png', '.jpg', '.jpeg', '.tiff', '.bmp')


class IMAPClient:
    """IMAP email client for fetching invoices"""
    
    def __init__(self):
        self.server = os.getenv('IMAP_SERVER', 'imap.gmail.com')
        self.port = int(os.getenv('IMAP_PORT', 993))
        self.email_address = os.getenv('EMAIL_ADDRESS')
        self.password = os.getenv('EMAIL_PASSWORD')
        self.connection = None
    
    def connect(self):
        """Connect to IMAP server with timeout"""
        try:
            self.connection = imaplib.IMAP4_SSL(self.server, self.port, timeout=30)
            self.connection.login(self.email_address, self.password)
            print(f"Connected to {self.server}")
        except Exception as e:
            raise ConnectionError(f"Failed to connect to IMAP server: {e}")
    
    def disconnect(self):
        """Disconnect from IMAP server"""
        if self.connection:
            try:
                self.connection.close()
                self.connection.logout()
                print("Disconnected from IMAP server")
            except:
                pass
    
    def fetch_emails(
        self,
        folder: str = 'INVOICE',
        search_subject: str = 'facture',
        since_date: datetime = None,
        mark_as_read: bool = False
    ) -> List[Dict]:
        """
        Fetch emails matching criteria
        
        Args:
            folder: IMAP folder to search
            search_subject: Subject string to search for (or comma-separated keywords)
            since_date: Only fetch emails after this date
            mark_as_read: Mark as read after fetching
            
        Returns:
            List of email dictionaries with metadata
        """
        if not self.connection:
            self.connect()
        
        try:
            # Select folder
            self.connection.select(folder)
            
            # Simple filtering: fetch recent emails, we'll check attachments after
            # No more keyword filtering - we process all emails with supported attachments
            search_query = 'ALL'
            if since_date:
                date_str = since_date.strftime('%d-%b-%Y')
                search_query = f'SINCE {date_str}'
            
            # Search emails
            status, messages = self.connection.search(None, search_query)
            
            if status != 'OK':
                return []
            
            email_ids = messages[0].split()
            emails = []
            
            # Limit to last 20 emails to avoid long processing times
            email_ids = email_ids[-20:]
            
            for email_id in email_ids:
                # Fetch email
                status, msg_data = self.connection.fetch(email_id, '(RFC822)')
                
                if status != 'OK':
                    continue
                
                # Parse email
                raw_email = msg_data[0][1]
                email_message = email.message_from_bytes(raw_email)
                
                # Extract metadata
                email_data = self._parse_email(email_message, email_id)
                
                # Keep only emails with supported attachments (PDF, images)
                has_supported_attachment = any(
                    self._is_supported_attachment(attachment['filename'])
                    for attachment in email_data['attachments']
                )

                if not has_supported_attachment:
                    continue
                
                if mark_as_read:
                    self.connection.store(email_id, '+FLAGS', '\\Seen')
                
                emails.append(email_data)
            
            return emails
            
        except Exception as e:
            raise Exception(f"Error fetching emails: {e}")
    
    def _parse_email(self, email_message, email_id) -> Dict:
        """Parse email message and extract metadata"""
        # Decode subject
        subject = self._decode_header_value(email_message['Subject'] or '')
        
        # Decode from address
        from_addr = self._decode_header_value(email_message['From'] or '')
        
        # Parse date
        date_str = email_message['Date']
        try:
            email_date = email.utils.parsedate_to_datetime(date_str)
        except:
            email_date = datetime.utcnow()
        
        # Extract Message-ID for deduplication
        message_id = email_message.get('Message-ID', '') or email_message.get('Message-Id', '')
        
        # Extract attachments
        attachments = []
        for part in email_message.walk():
            if part.get_content_disposition() == 'attachment':
                filename = part.get_filename()
                if filename:
                    payload = part.get_payload(decode=True) or b''
                    # Compute MD5 hash for deduplication
                    content_hash = hashlib.md5(payload).hexdigest()
                    attachments.append({
                        'filename': filename,
                        'content_type': part.get_content_type(),
                        'size': len(payload),
                        'content': payload,
                        'content_hash': content_hash
                    })
        
        return {
            'id': email_id.decode() if isinstance(email_id, bytes) else str(email_id),
            'message_id': message_id,
            'subject': subject,
            'from': from_addr,
            'date': email_date,
            'body': self._get_email_body(email_message),
            'attachments': attachments
        }
    
    def _get_email_body(self, email_message) -> str:
        """Extract email body text"""
        body = ''
        
        if email_message.is_multipart():
            for part in email_message.walk():
                content_type = part.get_content_type()
                if content_type == 'text/plain':
                    payload = part.get_payload(decode=True)
                    if payload:
                        body += payload.decode('utf-8', errors='ignore')
        else:
            payload = email_message.get_payload(decode=True)
            if payload:
                body = payload.decode('utf-8', errors='ignore')
        
        return body
    
    def _decode_header_value(self, value: str) -> str:
        decoded_value = ''
        for part, encoding in decode_header(value):
            if isinstance(part, bytes):
                normalized_encoding = encoding.lower() if isinstance(encoding, str) else None
                if normalized_encoding and normalized_encoding != 'unknown-8bit':
                    try:
                        decoded_value += part.decode(encoding, errors='ignore')
                        continue
                    except (LookupError, UnicodeDecodeError):
                        pass
                decoded_value += part.decode('utf-8', errors='ignore')
            else:
                decoded_value += part
        return decoded_value

    def _is_supported_attachment(self, filename: str) -> bool:
        return filename.lower().endswith(SUPPORTED_ATTACHMENT_EXTENSIONS)
    
    def download_attachments(self, email_data: Dict, save_dir: str) -> List[str]:
        """
        Download email attachments to directory
        
        Args:
            email_data: Email dictionary from fetch_emails
            save_dir: Directory to save attachments
            
        Returns:
            List of saved file paths
        """
        os.makedirs(save_dir, exist_ok=True)
        saved_files = []
        
        for attachment in email_data.get('attachments', []):
            filename = attachment['filename']
            content = attachment.get('content')
            if not self._is_supported_attachment(filename):
                continue
            
            if not content:
                continue
            
            # Decode filename if needed
            filename = self._decode_header_value(filename)
            
            # Sanitize filename
            filename = filename.replace('/', '_').replace('\\', '_')
            
            # Save file
            filepath = os.path.join(save_dir, filename)
            with open(filepath, 'wb') as f:
                f.write(content)
            
            saved_files.append(filepath)
        
        return saved_files
