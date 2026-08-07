"""Email notification sender using SMTP."""
import os
import logging
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from typing import Optional

import src.config  # noqa: F401
logger = logging.getLogger(__name__)


def send_email(to: str, subject: str, body_html: str, from_name: str = "Autocontable") -> bool:
    """Send an email notification.

    Uses the SMTP settings from environment variables.
    Returns True on success, False on failure.
    """
    smtp_host = os.getenv('SMTP_HOST', os.getenv('SMTP_SERVER', os.getenv('IMAP_SERVER', '')))
    smtp_port = int(os.getenv('SMTP_PORT', '587'))
    smtp_user = os.getenv('SMTP_USER', os.getenv('SMTP_EMAIL', os.getenv('EMAIL_ADDRESS', '')))
    smtp_pass = os.getenv('SMTP_PASS', os.getenv('SMTP_PASSWORD', os.getenv('EMAIL_PASSWORD', '')))
    from_email = os.getenv('SMTP_FROM', smtp_user)

    if not smtp_host or not smtp_user or not smtp_pass:
        logger.warning("SMTP not configured — notification email skipped")
        return False

    try:
        msg = MIMEMultipart('alternative')
        msg['From'] = f"{from_name} <{from_email}>"
        msg['To'] = to
        msg['Subject'] = subject
        msg.attach(MIMEText(body_html, 'html', 'utf-8'))

        with smtplib.SMTP(smtp_host, smtp_port, timeout=10) as server:
            server.starttls()
            server.login(smtp_user, smtp_pass)
            server.send_message(msg)

        logger.info(f"Email sent to {to}: {subject}")
        return True
    except Exception as e:
        logger.error(f"Failed to send email to {to}: {e}")
        return False


def send_digest(to: str, dossier_name: str, stats: dict) -> bool:
    """Send a weekly digest email for a dossier.

    stats: {invoices_processed, matches_pending, unmatched_count, last_bank_update}
    """
    subject = f"[Autocontable] Résumé hebdomadaire — {dossier_name}"

    body = f"""
    <html>
    <body style="font-family: -apple-system, sans-serif; color: #181818; max-width: 600px; margin: 0 auto;">
        <h2 style="font-size: 18px; margin-bottom: 16px;">📊 Résumé — {dossier_name}</h2>
        <table style="width: 100%; border-collapse: collapse; margin-bottom: 20px;">
            <tr style="border-bottom: 1px solid #e5e7eb;">
                <td style="padding: 8px 0; color: #6b7280;">Factures traitées</td>
                <td style="padding: 8px 0; font-weight: 600; text-align: right;">{stats.get('invoices_processed', 0)}</td>
            </tr>
            <tr style="border-bottom: 1px solid #e5e7eb;">
                <td style="padding: 8px 0; color: #6b7280;">Rapprochements en attente</td>
                <td style="padding: 8px 0; font-weight: 600; text-align: right;">{stats.get('matches_pending', 0)}</td>
            </tr>
            <tr style="border-bottom: 1px solid #e5e7eb;">
                <td style="padding: 8px 0; color: #6b7280;">Factures non rapprochées</td>
                <td style="padding: 8px 0; font-weight: 600; text-align: right;">{stats.get('unmatched_count', 0)}</td>
            </tr>
            <tr>
                <td style="padding: 8px 0; color: #6b7280;">Dernier relevé importé</td>
                <td style="padding: 8px 0; font-weight: 600; text-align: right;">{stats.get('last_bank_update', 'N/A')}</td>
            </tr>
        </table>
        <p style="font-size: 13px; color: #6b7280;">
            Connectez-vous pour valider les rapprochements en attente.
        </p>
        <hr style="border: none; border-top: 1px solid #e5e7eb; margin: 20px 0;">
        <p style="font-size: 11px; color: #9ca3af;">
            Autocontable — Comptabilité automatisée
        </p>
    </body>
    </html>
    """

    return send_email(to, subject, body)


def send_alert(to: str, alert_type: str, details: dict) -> bool:
    """Send an alert email (duplicate detected, overdue invoice, etc.)."""
    titles = {
        'duplicate': '⚠️ Facture en doublon détectée',
        'overdue': '⏰ Échéance proche',
        'no_bank_statement': '📄 Relevé bancaire manquant',
    }

    subject = f"[Autocontable] {titles.get(alert_type, 'Alerte')}"

    body = f"""
    <html>
    <body style="font-family: -apple-system, sans-serif; color: #181818; max-width: 600px; margin: 0 auto;">
        <h2 style="font-size: 18px; margin-bottom: 16px;">{titles.get(alert_type, 'Alerte')}</h2>
        <p style="color: #374151;">{details.get('message', '')}</p>
        <p style="font-size: 13px; color: #6b7280; margin-top: 16px;">
            Dossier: <strong>{details.get('dossier_name', '')}</strong>
        </p>
        <hr style="border: none; border-top: 1px solid #e5e7eb; margin: 20px 0;">
        <p style="font-size: 11px; color: #9ca3af;">Autocontable — Comptabilité automatisée</p>
    </body>
    </html>
    """

    return send_email(to, subject, body)
