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
    if google_id and google_secret:
        oauth.register(
            name='google',
            client_id=google_id,
            client_secret=google_secret,
            server_metadata_url='https://accounts.google.com/.well-known/openid-configuration',
            client_kwargs={'scope': 'openid email profile'},
        )
        logger.info(f"Google OAuth registered (client_id: {google_id[:20]}...)")
    else:
        logger.warning("Google OAuth NOT configured: GOOGLE_CLIENT_ID or GOOGLE_CLIENT_SECRET missing")

    linkedin_id = os.getenv('LINKEDIN_CLIENT_ID')
    linkedin_secret = os.getenv('LINKEDIN_CLIENT_SECRET')
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
        )
        logger.info("LinkedIn OAuth registered")
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
            from src.utils.defaults import create_default_settings
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


@router.get("/auth/google")
async def google_login(request: Request):
    """Redirect to Google OAuth consent screen"""
    _ensure_oauth_registered()
    redirect_uri = os.getenv('GOOGLE_REDIRECT_URI')
    if not redirect_uri:
        raise HTTPException(status_code=500, detail="OAuth Google non configure: GOOGLE_REDIRECT_URI manquant")
    if not hasattr(oauth, 'google'):
        raise HTTPException(status_code=500, detail="OAuth Google non configure: credentials manquantes")
    return await oauth.google.authorize_redirect(request, redirect_uri)


@router.get("/auth/google/callback")
async def google_callback(request: Request):
    """Handle Google OAuth callback"""
    _ensure_oauth_registered()
    try:
        token = await oauth.google.authorize_access_token(request)

        user_info = token.get('userinfo')
        if not user_info:
            raise HTTPException(status_code=400, detail="Impossible de recuperer les informations depuis Google")

        email = user_info.get('email')
        name = user_info.get('name')
        picture = user_info.get('picture')

        if not email:
            raise HTTPException(status_code=400, detail="Email non fourni par Google")

        user_data, org_id = _get_or_create_user_from_oauth(email, name, 'google', picture)

        session = db.get_session()
        try:
            token_value = _create_user_token(session, user_data['id'])
            session.commit()
            role = 'client' if user_data['role'] == UserRole.CLIENT else 'admin'

            frontend_url = os.getenv('FRONTEND_URL', 'http://localhost:3000')
            return RedirectResponse(
                url=f"{frontend_url}/oauth-callback#token={token_value}&role={role}",
                status_code=302
            )
        finally:
            session.close()

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
    _ensure_oauth_registered()
    redirect_uri = os.getenv('LINKEDIN_REDIRECT_URI')
    if not redirect_uri:
        raise HTTPException(status_code=500, detail="OAuth LinkedIn non configure: LINKEDIN_REDIRECT_URI manquant")
    if not hasattr(oauth, 'linkedin'):
        raise HTTPException(status_code=500, detail="OAuth LinkedIn non configure: credentials manquantes")
    return await oauth.linkedin.authorize_redirect(request, redirect_uri)


@router.get("/auth/linkedin/callback")
async def linkedin_callback(request: Request):
    """Handle LinkedIn OAuth callback"""
    _ensure_oauth_registered()
    try:
        token = await oauth.linkedin.authorize_access_token(request)

        resp = await oauth.linkedin.get('https://api.linkedin.com/v2/userinfo', token=token)
        user_info = resp.json()

        email = user_info.get('email')
        name = user_info.get('name')
        picture = user_info.get('picture')

        if not email:
            raise HTTPException(status_code=400, detail="Email non fourni par LinkedIn")

        user_data, org_id = _get_or_create_user_from_oauth(email, name, 'linkedin', picture)

        session = db.get_session()
        try:
            token_value = _create_user_token(session, user_data['id'])
            session.commit()
            role = 'client' if user_data['role'] == UserRole.CLIENT else 'admin'

            frontend_url = os.getenv('FRONTEND_URL', 'http://localhost:3000')
            return RedirectResponse(
                url=f"{frontend_url}/oauth-callback#token={token_value}&role={role}",
                status_code=302
            )
        finally:
            session.close()

    except Exception as e:
        logger.error(f"LinkedIn OAuth callback error: {e}", exc_info=True)
        frontend_url = os.getenv('FRONTEND_URL', 'http://localhost:3000')
        return RedirectResponse(
            url=f"{frontend_url}/login?error=oauth_failed",
            status_code=302
        )


@router.get("/auth/google-invitation")
async def google_login_invitation(request: Request):
    """Redirect to Google OAuth for invitation flow (PME joining via token)"""
    _ensure_oauth_registered()
    token = request.query_params.get('token')
    if not token:
        raise HTTPException(status_code=400, detail="Token d'invitation manquant")

    redirect_uri = os.getenv('GOOGLE_REDIRECT_URI')
    if not redirect_uri:
        raise HTTPException(status_code=500, detail="OAuth Google non configuré")

    # Store token in session for callback
    request.session['invitation_token'] = token
    return await oauth.google.authorize_redirect(request, redirect_uri)


@router.get("/auth/google-callback-invitation")
async def google_callback_invitation(request: Request):
    """Handle Google OAuth callback for invitation flow"""
    _ensure_oauth_registered()
    try:
        token = await oauth.google.authorize_access_token(request)
        user_info = token.get('userinfo')
        if not user_info:
            raise HTTPException(status_code=400, detail="Impossible de récupérer les infos depuis Google")

        email = user_info.get('email')
        name = user_info.get('name')
        picture = user_info.get('picture')

        if not email:
            raise HTTPException(status_code=400, detail="Email non fourni par Google")

        # Get invitation from session
        invitation_token = request.session.get('invitation_token')
        if not invitation_token:
            raise HTTPException(status_code=400, detail="Token d'invitation manquant en session")

        # Validate invitation token
        session = db.get_session()
        try:
            from src.storage.models import InvitationToken, DossierPermission
            invitation = session.query(InvitationToken).filter(
                InvitationToken.token == invitation_token,
                InvitationToken.used_at.is_(None),
                InvitationToken.expires_at > datetime.utcnow()
            ).first()

            if not invitation:
                raise HTTPException(status_code=400, detail="Lien d'invitation invalide ou expiré")

            # Get or create user in the org from invitation
            user_data, org_id = _get_or_create_user_from_oauth(
                email, name, 'google', picture,
                organization_id=invitation.organization_id
            )
            user_id = user_data['id']

            # Grant dossier access if specified
            if invitation.client_file_id:
                existing_perm = session.query(DossierPermission).filter(
                    DossierPermission.user_id == user_id,
                    DossierPermission.client_file_id == invitation.client_file_id
                ).first()
                if not existing_perm:
                    session.add(DossierPermission(
                        user_id=user_id,
                        client_file_id=invitation.client_file_id,
                        permission_level=invitation.permission_level,
                    ))

            # Mark invitation as used
            invitation.used_by_user_id = user_id
            invitation.used_at = datetime.utcnow()
            session.commit()

            token_value = _create_user_token(session, user_id)
            session.close()

            frontend_url = os.getenv('FRONTEND_URL', 'http://localhost:3000')
            return RedirectResponse(
                url=f"{frontend_url}/oauth-callback#token={token_value}&role=client",
                status_code=302
            )

        finally:
            session.close()

    except Exception as e:
        logger.error(f"Google OAuth invitation callback error: {e}", exc_info=True)
        frontend_url = os.getenv('FRONTEND_URL', 'http://localhost:3000')
        return RedirectResponse(
            url=f"{frontend_url}/join?error=oauth_failed",
            status_code=302
        )


@router.get("/auth/linkedin-invitation")
async def linkedin_login_invitation(request: Request):
    """Redirect to LinkedIn OAuth for invitation flow"""
    _ensure_oauth_registered()
    token = request.query_params.get('token')
    if not token:
        raise HTTPException(status_code=400, detail="Token d'invitation manquant")

    redirect_uri = os.getenv('LINKEDIN_REDIRECT_URI')
    if not redirect_uri:
        raise HTTPException(status_code=500, detail="OAuth LinkedIn non configuré")

    request.session['invitation_token'] = token
    return await oauth.linkedin.authorize_redirect(request, redirect_uri)


@router.get("/auth/linkedin-callback-invitation")
async def linkedin_callback_invitation(request: Request):
    """Handle LinkedIn OAuth callback for invitation flow"""
    _ensure_oauth_registered()
    try:
        token = await oauth.linkedin.authorize_access_token(request)
        user_info = token.get('userinfo')
        if not user_info:
            raise HTTPException(status_code=400, detail="Impossible de récupérer les infos depuis LinkedIn")

        email = user_info.get('email')
        name = user_info.get('name')
        picture = user_info.get('picture')

        if not email:
            raise HTTPException(status_code=400, detail="Email non fourni par LinkedIn")

        invitation_token = request.session.get('invitation_token')
        if not invitation_token:
            raise HTTPException(status_code=400, detail="Token d'invitation manquant en session")

        session = db.get_session()
        try:
            from src.storage.models import InvitationToken, DossierPermission
            invitation = session.query(InvitationToken).filter(
                InvitationToken.token == invitation_token,
                InvitationToken.used_at.is_(None),
                InvitationToken.expires_at > datetime.utcnow()
            ).first()

            if not invitation:
                raise HTTPException(status_code=400, detail="Lien d'invitation invalide ou expiré")

            user_data, org_id = _get_or_create_user_from_oauth(
                email, name, 'linkedin', picture,
                organization_id=invitation.organization_id
            )
            user_id = user_data['id']

            if invitation.client_file_id:
                existing_perm = session.query(DossierPermission).filter(
                    DossierPermission.user_id == user_id,
                    DossierPermission.client_file_id == invitation.client_file_id
                ).first()
                if not existing_perm:
                    session.add(DossierPermission(
                        user_id=user_id,
                        client_file_id=invitation.client_file_id,
                        permission_level=invitation.permission_level,
                    ))

            invitation.used_by_user_id = user_id
            invitation.used_at = datetime.utcnow()
            session.commit()

            token_value = _create_user_token(session, user_id)
            session.close()

            frontend_url = os.getenv('FRONTEND_URL', 'http://localhost:3000')
            return RedirectResponse(
                url=f"{frontend_url}/oauth-callback#token={token_value}&role=client",
                status_code=302
            )

        finally:
            session.close()

    except Exception as e:
        logger.error(f"LinkedIn OAuth invitation callback error: {e}", exc_info=True)
        frontend_url = os.getenv('FRONTEND_URL', 'http://localhost:3000')
        return RedirectResponse(
            url=f"{frontend_url}/join?error=oauth_failed",
            status_code=302
        )
