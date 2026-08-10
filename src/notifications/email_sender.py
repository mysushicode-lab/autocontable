"""Email notification sender using SendGrid."""
import os
import logging
from sendgrid import SendGridAPIClient
from sendgrid.helpers.mail import Mail, To
from typing import Optional

import src.config  # noqa: F401
logger = logging.getLogger(__name__)

SENDGRID_API_KEY = os.getenv("SENDGRID_API_KEY")
SENDGRID_FROM_EMAIL = os.getenv("SENDGRID_FROM_EMAIL", "contact@factpilot.fr")


def send_email(to: str, subject: str, body_html: str, from_name: str = "FactPilot") -> bool:
    """Send an email notification via SendGrid.

    Returns True on success, False on failure.
    """
    if not SENDGRID_API_KEY:
        logger.warning("SendGrid API key not configured — email skipped")
        return False

    try:
        message = Mail(
            from_email=SENDGRID_FROM_EMAIL,
            to_emails=To(email=to),
            subject=subject,
            html_content=body_html
        )

        sg = SendGridAPIClient(SENDGRID_API_KEY)
        response = sg.send(message)

        if response.status_code in [200, 201, 202]:
            logger.info(f"Email sent to {to}: {subject}")
            return True
        else:
            logger.error(f"SendGrid error {response.status_code}: {response.body}")
            return False
    except Exception as e:
        logger.error(f"Failed to send email to {to}: {e}")
        return False


def send_digest(to: str, dossier_name: str, stats: dict) -> bool:
    """Send a weekly digest email for a dossier.

    stats: {invoices_processed, matches_pending, unmatched_count, last_bank_update}
    """
    subject = f"[FactPilot] Résumé hebdomadaire — {dossier_name}"

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
            FactPilot — Comptabilité automatisée
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

    subject = f"[FactPilot] {titles.get(alert_type, 'Alerte')}"

    body = f"""
    <html>
    <body style="font-family: -apple-system, sans-serif; color: #181818; max-width: 600px; margin: 0 auto;">
        <h2 style="font-size: 18px; margin-bottom: 16px;">{titles.get(alert_type, 'Alerte')}</h2>
        <p style="color: #374151;">{details.get('message', '')}</p>
        <p style="font-size: 13px; color: #6b7280; margin-top: 16px;">
            Dossier: <strong>{details.get('dossier_name', '')}</strong>
        </p>
        <hr style="border: none; border-top: 1px solid #e5e7eb; margin: 20px 0;">
        <p style="font-size: 11px; color: #9ca3af;">FactPilot — Comptabilité automatisée</p>
    </body>
    </html>
    """

    return send_email(to, subject, body)
