"""OAuth authentication endpoints (Google & LinkedIn)"""
import os
from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import RedirectResponse
from src.storage.database import db
from src.storage.models import UserRole
from src.api.auth import _create_user_token
from src.api.oauth_helpers import (
    oauth,
    _ensure_oauth_registered,
    _get_or_create_user_from_oauth,
)
from datetime import datetime
import logging

logger = logging.getLogger(__name__)
router = APIRouter()


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
            response = RedirectResponse(
                url=f"{frontend_url}/oauth-callback?success=true&role={role}",
                status_code=302
            )
            response.set_cookie(
                'auth_token',
                token_value,
                httponly=True,
                secure=os.getenv('ENV', 'development') == 'production',
                samesite='Lax',
                max_age=7*24*60*60
            )
            return response
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
            response = RedirectResponse(
                url=f"{frontend_url}/oauth-callback?success=true&role={role}",
                status_code=302
            )
            response.set_cookie(
                'auth_token',
                token_value,
                httponly=True,
                secure=os.getenv('ENV', 'development') == 'production',
                samesite='Lax',
                max_age=7*24*60*60
            )
            return response
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
            response = RedirectResponse(
                url=f"{frontend_url}/oauth-callback?success=true&role=client",
                status_code=302
            )
            response.set_cookie(
                'auth_token',
                token_value,
                httponly=True,
                secure=os.getenv('ENV', 'production') == 'production',
                samesite='Lax',
                max_age=7*24*60*60
            )
            return response

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
            response = RedirectResponse(
                url=f"{frontend_url}/oauth-callback?success=true&role=client",
                status_code=302
            )
            response.set_cookie(
                'auth_token',
                token_value,
                httponly=True,
                secure=os.getenv('ENV', 'production') == 'production',
                samesite='Lax',
                max_age=7*24*60*60
            )
            return response

        finally:
            session.close()

    except Exception as e:
        logger.error(f"LinkedIn OAuth invitation callback error: {e}", exc_info=True)
        frontend_url = os.getenv('FRONTEND_URL', 'http://localhost:3000')
        return RedirectResponse(
            url=f"{frontend_url}/join?error=oauth_failed",
            status_code=302
        )
