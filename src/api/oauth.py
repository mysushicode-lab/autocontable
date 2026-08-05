"""OAuth authentication endpoints (Google & LinkedIn)"""
import os
import secrets
from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import RedirectResponse
from authlib.integrations.starlette_client import OAuth
from src.storage.database import db
from src.storage.models import User, Organization, UserRole
from src.utils.defaults import create_default_settings
from src.api.auth import _create_user_token
from datetime import datetime, timedelta
import logging

logger = logging.getLogger(__name__)
router = APIRouter()

# OAuth2 configuration
oauth = OAuth()

# Google OAuth
oauth.register(
    name='google',
    client_id=os.getenv('GOOGLE_CLIENT_ID'),
    client_secret=os.getenv('GOOGLE_CLIENT_SECRET'),
    server_metadata_url='https://accounts.google.com/.well-known/openid-configuration',
    client_kwargs={'scope': 'openid email profile'},
)

# LinkedIn OAuth
oauth.register(
    name='linkedin',
    client_id=os.getenv('LINKEDIN_CLIENT_ID'),
    client_secret=os.getenv('LINKEDIN_CLIENT_SECRET'),
    authorize_url='https://www.linkedin.com/oauth/v2/authorization',
    authorize_params=None,
    access_token_url='https://www.linkedin.com/oauth/v2/accessToken',
    access_token_params=None,
    client_kwargs={'scope': 'openid email profile'},
    server_metadata_url='https://www.linkedin.com/oauth/.well-known/openid-configuration',
)


def _get_or_create_user_from_oauth(email: str, name: str, provider: str, profile_photo: str = None):
    """Get existing user or create new one from OAuth data"""
    session = db.get_session()
    try:
        # Check if user exists
        user = session.query(User).filter(User.email == email).first()

        if user:
            # User exists - update profile photo if provided
            if profile_photo and not user.profile_photo:
                user.profile_photo = profile_photo
                session.commit()
            return user, session

        # Create new organization and user
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

        # Generate unique username from email
        base_username = email.split('@')[0]
        username = base_username
        counter = 1
        while session.query(User).filter(User.username == username).first():
            username = f"{base_username}{counter}"
            counter += 1

        user = User(
            username=username,
            password_hash='',  # OAuth users don't have password
            name=name or email,
            email=email,
            role=UserRole.ADMIN,
            organization_id=org.id,
            profile_photo=profile_photo
        )
        session.add(user)
        session.flush()

        # Create default settings
        create_default_settings(session, org.id, company_name=org.name)

        session.commit()
        logger.info(f"Created new user via {provider} OAuth: {email}")
        return user, session

    except Exception as e:
        session.rollback()
        logger.error(f"Error creating user from OAuth: {e}")
        raise


@router.get("/auth/google")
async def google_login(request: Request):
    """Redirect to Google OAuth consent screen"""
    redirect_uri = os.getenv('GOOGLE_REDIRECT_URI')
    if not redirect_uri:
        raise HTTPException(status_code=500, detail="Google OAuth not configured")
    return await oauth.google.authorize_redirect(request, redirect_uri)


@router.get("/auth/google/callback")
async def google_callback(request: Request):
    """Handle Google OAuth callback"""
    try:
        # Exchange code for token
        token = await oauth.google.authorize_access_token(request)

        # Get user info
        user_info = token.get('userinfo')
        if not user_info:
            raise HTTPException(status_code=400, detail="Failed to get user info from Google")

        email = user_info.get('email')
        name = user_info.get('name')
        picture = user_info.get('picture')

        if not email:
            raise HTTPException(status_code=400, detail="Email not provided by Google")

        # Create or get user
        user, session = _get_or_create_user_from_oauth(email, name, 'google', picture)

        # Create auth token
        token_value = _create_user_token(session, user.id)
        role = 'client' if user.role == UserRole.CLIENT else 'admin'
        session.commit()
        session.close()

        # Redirect to frontend - token in fragment (never sent to server/logs)
        frontend_url = os.getenv('FRONTEND_URL', 'http://localhost:3000')
        return RedirectResponse(
            url=f"{frontend_url}/oauth-callback#token={token_value}&role={role}",
            status_code=302
        )

    except Exception as e:
        logger.error(f"Google OAuth callback error: {e}", exc_info=True)
        frontend_url = os.getenv('FRONTEND_URL', 'http://localhost:3000')
        return RedirectResponse(
            url=f"{frontend_url}/login?error=oauth_failed",
            status_code=302
        )


@router.get("/auth/linkedin")
async def linkedin_login(request: Request):
    """Redirect to LinkedIn OAuth consent screen"""
    redirect_uri = os.getenv('LINKEDIN_REDIRECT_URI')
    if not redirect_uri:
        raise HTTPException(status_code=500, detail="LinkedIn OAuth not configured")
    return await oauth.linkedin.authorize_redirect(request, redirect_uri)


@router.get("/auth/linkedin/callback")
async def linkedin_callback(request: Request):
    """Handle LinkedIn OAuth callback"""
    try:
        # Exchange code for token
        token = await oauth.linkedin.authorize_access_token(request)

        # Get user info from LinkedIn UserInfo endpoint
        resp = await oauth.linkedin.get('https://api.linkedin.com/v2/userinfo', token=token)
        user_info = resp.json()

        email = user_info.get('email')
        name = user_info.get('name')
        picture = user_info.get('picture')

        if not email:
            raise HTTPException(status_code=400, detail="Email not provided by LinkedIn")

        # Create or get user
        user, session = _get_or_create_user_from_oauth(email, name, 'linkedin', picture)

        # Create auth token
        token_value = _create_user_token(session, user.id)
        role = 'client' if user.role == UserRole.CLIENT else 'admin'
        session.commit()
        session.close()

        # Redirect to frontend - token in fragment (never sent to server/logs)
        frontend_url = os.getenv('FRONTEND_URL', 'http://localhost:3000')
        return RedirectResponse(
            url=f"{frontend_url}/oauth-callback#token={token_value}&role={role}",
            status_code=302
        )

    except Exception as e:
        logger.error(f"LinkedIn OAuth callback error: {e}", exc_info=True)
        frontend_url = os.getenv('FRONTEND_URL', 'http://localhost:3000')
        return RedirectResponse(
            url=f"{frontend_url}/login?error=oauth_failed",
            status_code=302
        )
