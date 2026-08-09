"""OAuth shared helpers: provider registration and user creation logic."""
import os
import secrets
from authlib.integrations.starlette_client import OAuth
from src.storage.database import db
from src.storage.models import User, Organization, UserRole
from src.utils.defaults import create_default_settings
from datetime import datetime, timedelta
import logging

logger = logging.getLogger(__name__)

oauth = OAuth()

_oauth_registered = False


def _ensure_oauth_registered():
    """Register OAuth providers lazily — env vars are read at first request, not at import."""
    global _oauth_registered
    if _oauth_registered:
        return
    _oauth_registered = True

    google_id = os.getenv('GOOGLE_CLIENT_ID')
    google_secret = os.getenv('GOOGLE_CLIENT_SECRET')
    google_redirect = os.getenv('GOOGLE_REDIRECT_URI')
    if google_id and google_secret:
        oauth.register(
            name='google',
            client_id=google_id,
            client_secret=google_secret,
            server_metadata_url='https://accounts.google.com/.well-known/openid-configuration',
            client_kwargs={'scope': 'openid email profile'},
            redirect_uri=google_redirect,
        )
        logger.info(f"Google OAuth registered (client_id: {google_id[:20]}..., redirect: {google_redirect})")
    else:
        logger.warning("Google OAuth NOT configured: GOOGLE_CLIENT_ID or GOOGLE_CLIENT_SECRET missing")

    linkedin_id = os.getenv('LINKEDIN_CLIENT_ID')
    linkedin_secret = os.getenv('LINKEDIN_CLIENT_SECRET')
    linkedin_redirect = os.getenv('LINKEDIN_REDIRECT_URI')
    if linkedin_id and linkedin_secret:
        oauth.register(
            name='linkedin',
            client_id=linkedin_id,
            client_secret=linkedin_secret,
            authorize_url='https://www.linkedin.com/oauth/v2/authorization',
            authorize_params=None,
            access_token_url='https://www.linkedin.com/oauth/v2/accessToken',
            access_token_params=None,
            client_kwargs={'scope': 'openid email profile'},
            server_metadata_url='https://www.linkedin.com/oauth/.well-known/openid-configuration',
            redirect_uri=linkedin_redirect,
        )
        logger.info(f"LinkedIn OAuth registered (redirect: {linkedin_redirect})")
    else:
        logger.warning("LinkedIn OAuth NOT configured: LINKEDIN_CLIENT_ID or LINKEDIN_CLIENT_SECRET missing")


def _get_or_create_user_from_oauth(email: str, name: str, provider: str, profile_photo: str = None, organization_id: int = None):
    """Get existing user or create new one from OAuth data.

    If organization_id provided (invitation flow), add to that org as CLIENT.
    Otherwise creates new org as ADMIN (standard signup flow).
    Returns tuple (user_dict, org_id) where user_dict contains serializable user data.
    """
    session = db.get_session()
    try:
        user = session.query(User).filter(User.email == email).first()

        if user:
            if profile_photo and not user.profile_photo:
                user.profile_photo = profile_photo
                session.commit()
            return {
                'id': user.id,
                'email': user.email,
                'name': user.name,
                'username': user.username,
                'organization_id': user.organization_id,
                'role': user.role
            }, user.organization_id

        # If joining via invitation, use provided org_id. Otherwise create new org.
        if organization_id:
            role = UserRole.CLIENT
            org_id = organization_id
        else:
            trial_start = datetime.utcnow()
            trial_end = trial_start + timedelta(days=int(os.getenv("TRIAL_PERIOD_DAYS", 7)))
            org = Organization(
                name=name or email.split('@')[0],
                plan_type='starter',
                trial_start_date=trial_start,
                trial_end_date=trial_end,
                is_trial_active=True
            )
            session.add(org)
            session.flush()
            org_id = org.id
            role = UserRole.ADMIN
            # Create default settings for new org
            create_default_settings(session, org_id, company_name=name)

        # Create user
        username = email.split('@')[0] + '_' + secrets.token_hex(3)  # Ensure unique username
        user = User(
            username=username,
            email=email,
            name=name or email,
            profile_photo=profile_photo,
            role=role,
            organization_id=org_id,
        )
        session.add(user)
        session.flush()
        session.commit()
        return {
            'id': user.id,
            'email': user.email,
            'name': user.name,
            'username': user.username,
            'organization_id': user.organization_id,
            'role': user.role
        }, org_id
    except Exception:
        session.rollback()
        raise
    finally:
        if session:
            session.close()


def _get_or_create_user_from_oauth_legacy(email: str, name: str, provider: str, profile_photo: str = None):
    """Legacy version for standard OAuth signup (creates new org)"""
    session = db.get_session()
    try:
        user = session.query(User).filter(User.email == email).first()

        if user:
            if profile_photo and not user.profile_photo:
                user.profile_photo = profile_photo
                session.commit()
            return user, session

        trial_start = datetime.utcnow()
        trial_end = trial_start + timedelta(days=int(os.getenv("TRIAL_PERIOD_DAYS", 7)))

        org = Organization(
            name=name or email.split('@')[0],
            plan_type='starter',
            trial_start_date=trial_start,
            trial_end_date=trial_end,
            is_trial_active=True
        )
        session.add(org)
        session.flush()

        base_username = email.split('@')[0]
        username = base_username
        counter = 1
        while session.query(User).filter(User.username == username).first():
            username = f"{base_username}{counter}"
            counter += 1

        user = User(
            username=username,
            password_hash='',
            name=name or email,
            email=email,
            role=UserRole.ADMIN,
            organization_id=org.id,
            profile_photo=profile_photo
        )
        session.add(user)
        session.flush()

        create_default_settings(session, org.id, company_name=org.name)

        session.commit()
        logger.info(f"Created new user via {provider} OAuth: {email}")
        return user, session

    except Exception as e:
        session.rollback()
        logger.error(f"Error creating user from OAuth: {e}")
        raise
