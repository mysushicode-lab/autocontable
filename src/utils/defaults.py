"""Default settings for new organizations."""
from src.storage.models import Settings


DEFAULT_ORG_SETTINGS = [
    ('imap_server', 'imap.gmail.com', 'email', 'Serveur IMAP'),
    ('imap_port', '993', 'email', 'Port IMAP'),
    ('email_folder', 'INBOX', 'email', 'Dossier IMAP'),
    ('scheduler_interval', '1', 'scheduler', 'Intervalle en minutes'),
    ('auto_reconciliation', 'true', 'scheduler', 'Rapprochement automatique'),
]


def create_default_settings(session, org_id: int, company_name: str = ''):
    """Insert default settings for a newly created organization."""
    settings = DEFAULT_ORG_SETTINGS + [
        ('company_name', company_name, 'general', 'Nom de votre entreprise'),
    ]
    for key, value, category, description in settings:
        session.add(Settings(
            key=key,
            value=value,
            category=category,
            description=description,
            organization_id=org_id,
        ))
