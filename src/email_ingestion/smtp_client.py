"""SMTP client for sending emails"""
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import os
from typing import Optional


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
        base_url = base_url or os.getenv('FRONTEND_URL', 'https://carrosserie-erik.fr')
        reset_link = f"{base_url}/reset-password?token={reset_token}"
        
        subject = "Réinitialisation de votre mot de passe - MAILFACT"
        
        text_body = f"""Bonjour,

Vous avez demandé la réinitialisation de votre mot de passe.

Cliquez sur le lien suivant pour réinitialiser votre mot de passe :
{reset_link}

Ce lien expire dans 1 heure.

Si vous n'avez pas demandé cette réinitialisation, ignorez cet email.

Cordialement,
L'équipe MAILFACT
"""
        
        html_body = f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
        .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
        .header {{ background: #2563eb; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }}
        .content {{ background: #f9fafb; padding: 30px; border-radius: 0 0 8px 8px; }}
        .button {{ display: inline-block; background: #2563eb; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; margin: 20px 0; }}
        .button:hover {{ background: #1d4ed8; }}
        .footer {{ text-align: center; color: #6b7280; font-size: 12px; margin-top: 20px; }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>MAILFACT</h1>
            <p>Gestion Comptable</p>
        </div>
        <div class="content">
            <p>Bonjour,</p>
            <p>Vous avez demandé la réinitialisation de votre mot de passe.</p>
            <p>Cliquez sur le bouton ci-dessous pour réinitialiser votre mot de passe :</p>
            <center>
                <a href="{reset_link}" class="button">Réinitialiser mon mot de passe</a>
            </center>
            <p>Ou copiez ce lien dans votre navigateur :</p>
            <p style="word-break: break-all; color: #2563eb;">{reset_link}</p>
            <p><strong>Ce lien expire dans 1 heure.</strong></p>
            <p>Si vous n'avez pas demandé cette réinitialisation, ignorez cet email.</p>
        </div>
        <div class="footer">
            <p>L'équipe MAILFACT</p>
        </div>
    </div>
</body>
</html>"""
        
        return self.send_email(to_email, subject, html_body, text_body)
