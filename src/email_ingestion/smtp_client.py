"""SMTP client for sending emails"""
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import os
from typing import Optional
from src.scheduler.lifecycle_templates import layout, BRAND_URL


class SMTPClient:
    """SMTP client for sending emails"""
    
    def __init__(self, server: str = None, port: int = None, email: str = None, password: str = None):
        self.server = server or os.getenv('SMTP_SERVER', 'smtp.gmail.com')
        self.port = int(port or os.getenv('SMTP_PORT', '587'))
        self.email = email or os.getenv('SMTP_EMAIL', '')
        self.password = password or os.getenv('SMTP_PASSWORD', '')
    
    def send_email(self, to_email: str, subject: str, html_body: str, text_body: str = None) -> bool:
        """Send email via SMTP"""
        if not self.email or not self.password:
            print("[SMTP] Missing email credentials - skipping email send")
            return False
        
        try:
            msg = MIMEMultipart('alternative')
            msg['From'] = self.email
            msg['To'] = to_email
            msg['Subject'] = subject
            
            if text_body:
                msg.attach(MIMEText(text_body, 'plain'))
            if html_body:
                msg.attach(MIMEText(html_body, 'html'))
            
            with smtplib.SMTP(self.server, self.port) as server:
                server.starttls()
                server.login(self.email, self.password)
                server.send_message(msg)
            
            print(f"[SMTP] Email sent to {to_email}")
            return True
        except Exception as e:
            print(f"[SMTP] Failed to send email: {e}")
            return False
    
    def send_password_reset(self, to_email: str, reset_token: str, base_url: str = None) -> bool:
        """Send password reset email"""
        base_url = base_url or os.getenv('FRONTEND_URL', 'http://localhost:3000')
        reset_link = f"{base_url}/reset-password?token={reset_token}"
        
        subject = "Réinitialisation de votre mot de passe — FactPilot"

        text_body = f"""Bonjour,

Vous avez demandé la réinitialisation de votre mot de passe FactPilot.

Cliquez sur le lien suivant pour choisir un nouveau mot de passe :
{reset_link}

Ce lien expire dans 1 heure.

Si vous n'avez pas demandé cette réinitialisation, ignorez cet email.

— L'équipe FactPilot
"""
        
        html_body = layout(f"""
  <p>Bonjour,</p>
  <p>Vous avez demandé la réinitialisation de votre mot de passe.</p>
  <p>Cliquez sur le bouton ci-dessous pour choisir un nouveau mot de passe. Ce lien expire dans 1 heure.</p>
  <p style="text-align:center;margin:24px 0;">
    <a href="{reset_link}" style="background-color:#2563eb;color:white;padding:12px 28px;text-decoration:none;border-radius:8px;font-weight:bold;display:inline-block;">Réinitialiser mon mot de passe</a>
  </p>
  <p style="font-size:13px;color:#64748b;">Ou copiez ce lien : {reset_link}</p>
  <p style="font-size:13px;color:#64748b;">Si vous n'avez pas demandé cette réinitialisation, ignorez cet email.</p>
""")
        
        return self.send_email(to_email, subject, html_body, text_body)
