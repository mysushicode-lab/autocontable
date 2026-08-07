# PME Invitation & OAuth Integration Flow

## Overview
This document describes the complete PME (client) invitation system that allows cabinet admins to invite external PME users to access specific dossiers via email invitations with optional OAuth (Google/LinkedIn) signup.

## System Components

### Backend

#### Models
- **InvitationToken** (`src/storage/models.py`)
  - Stores invitation details with 7-day expiration
  - Tracks usage to prevent reuse
  - Links to organization, dossier, and permission level
  - Fields: token, organization_id, client_file_id, invited_email, permission_level, expires_at, used_by_user_id, used_at, created_by_user_id, created_at

- **DossierPermission** (existing)
  - Grants user access to specific dossier at specified level
  - Levels: read_only, read_write, admin
  - Auto-created on PME signup from invitation

#### Endpoints

##### 1. Generate Invitation (`POST /api/permissions/invite`)
- **Auth**: Admin required, permissions feature gated
- **Input**: 
  ```json
  {
    "email": "pme@example.com",
    "client_file_id": 123,
    "permission_level": "read_write"
  }
  ```
- **Process**:
  - Validate dossier exists in admin's org
  - Check user not already in org
  - Generate 32-char URL-safe token
  - Create InvitationToken record (7-day expiry)
  - Return join_url
- **Output**:
  ```json
  {
    "success": true,
    "join_url": "http://localhost:3000/join?token=...",
    "expires_at": "2026-08-15T12:34:56"
  }
  ```

##### 2. Manual Signup via Token (`POST /api/auth/join-from-invitation`)
- **Input**:
  ```json
  {
    "token": "...",
    "username": "pme_user",
    "password": "secure_password",
    "name": "PME Name"
  }
  ```
- **Process**:
  - Validate token exists, not used, not expired
  - Check username not taken
  - Create USER as CLIENT role in cabinet's organization
  - Grant DossierPermission if dossier specified
  - Mark invitation as used
  - Create UserToken for immediate login
- **Output**:
  ```json
  {
    "access_token": "token_value",
    "token_type": "bearer",
    "user": {...}
  }
  ```

##### 3. OAuth Google Invitation (`GET /api/auth/google-invitation?token=...`)
- Stores token in session
- Redirects to Google OAuth consent screen

##### 4. OAuth Google Callback Invitation (`GET /api/auth/google-callback-invitation`)
- Validates invitation token
- Creates CLIENT user in cabinet org via OAuth data
- Grants DossierPermission
- Marks invitation used
- Redirects to frontend with access_token in hash

##### 5-8. LinkedIn Equivalents
- Same flow as Google for LinkedIn provider

### Frontend

#### Components

##### PermissionsModal (`frontend/src/components/PermissionsModal.js`)
- **Features**:
  - Show existing users with dossier access
  - Add existing organization users to dossier
  - Invite new PME users via email
  - Display invitation link with copy-to-clipboard
  - Show expiration (7 days)
- **States**:
  - Invitation form hidden
  - Invitation form visible with email/permission inputs
  - Link generated (shows link + copy button)

##### Join Page (`frontend/src/app/join/page.js`)
- **Features**:
  - Extract token from URL
  - Show signup form (name, username, password)
  - Show OAuth buttons (Google, LinkedIn)
  - Handle token validation errors
  - Auto-redirect to /portfolio on success
  - Auto-redirect if token missing/invalid

##### OAuth Callback (`frontend/src/app/(auth)/oauth-callback/page.js`)
- Extracts token from URL hash
- Validates with /api/auth/me
- Stores token in localStorage
- Redirects clients to /portfolio, admins to /dashboard

## Complete Flow Diagram

### Cabinet Admin Invites PME

```
1. Admin goes to Portfolio → Selects Dossier → Clicks "Accès"
   ↓
2. PermissionsModal opens, shows contact_email pre-filled
   ↓
3. Admin enters email, selects permission level (read_only or read_write)
   ↓
4. Frontend: POST /api/permissions/invite
   ↓
5. Backend: Create InvitationToken, return join_url
   ↓
6. Frontend: Display link with "Copy to Clipboard" button
   ↓
7. Admin copies link and sends to PME (manually)
```

### PME Signs Up (Manual)

```
1. PME receives link: http://localhost:3000/join?token=xyz...
   ↓
2. Frontend: Load /join page, extract token
   ↓
3. PME fills form: name, username, password
   ↓
4. PME clicks "Créer mon compte"
   ↓
5. Frontend: POST /api/auth/join-from-invitation
   ↓
6. Backend:
   - Validate token (exists, not used, not expired)
   - Create USER (CLIENT role in cabinet org)
   - Grant DossierPermission
   - Mark invitation used
   - Return access_token
   ↓
7. Frontend: Store token in localStorage
   ↓
8. Frontend: Redirect to /portfolio
   ↓
9. PME can now view assigned dossier
```

### PME Signs Up (OAuth Google)

```
1. PME receives link, clicks "Continuer avec Google"
   ↓
2. Frontend: Redirect to /api/auth/google-invitation?token=xyz...
   ↓
3. Backend: Store token in session, redirect to Google OAuth
   ↓
4. PME: Logs in with Google
   ↓
5. Google redirects to /api/auth/google-callback-invitation
   ↓
6. Backend:
   - Get token from session
   - Validate invitation token
   - Fetch Google user info (email, name, picture)
   - Create USER via _get_or_create_user_from_oauth (CLIENT role)
   - Grant DossierPermission
   - Mark invitation used
   - Create UserToken
   - Redirect to /oauth-callback#token=...&role=client
   ↓
7. Frontend oauth-callback:
   - Extract token from hash
   - Validate with /api/auth/me
   - Store token in localStorage
   - Redirect to /portfolio
   ↓
8. PME can now view assigned dossier
```

## Security Features

1. **Token-based invitations**: 32-char URL-safe tokens prevent guessing
2. **Token expiration**: 7-day automatic expiration
3. **Single-use tokens**: Marked as used after first signup
4. **Email verification**: User email must match invitation email (for manual signup)
5. **Organization isolation**: PME can only access granted dossiers
6. **Role hierarchy**: Permission levels enforced (read_only < read_write < admin)
7. **Admin-only invitations**: Only org admins can generate invitations
8. **Dossier ownership**: Can only invite to dossiers in user's org

## Feature Gating

- Permissions feature gated behind billing tier (default: 'starter' plan)
- PME invitations require permissions feature enabled
- Check `usePlanGate('permissions')` in frontend before showing UI

## Testing Checklist

- [ ] Admin generates invitation link
- [ ] Link contains valid token
- [ ] Link works for 7 days
- [ ] PME can sign up manually with username/password
- [ ] PME can sign up with Google OAuth
- [ ] PME can sign up with LinkedIn OAuth
- [ ] PME auto-gets correct permission level
- [ ] PME can only see granted dossier (not other org dossiers)
- [ ] Invitation token prevents reuse (second attempt fails)
- [ ] Expired token shows error
- [ ] Duplicate email in org shows error
- [ ] Admin can invite multiple PME to same dossier
- [ ] Different PME can have different permission levels on same dossier
- [ ] Cabinet admin can still manage all dossiers
- [ ] PME cannot invite other users

## Future Enhancements

1. **Email notifications**: Automatically send invitation email with link
2. **Invitation management**: Show pending invitations, resend, revoke
3. **Bulk invitations**: Invite multiple PME at once
4. **Invitation templates**: Customize invitation message
5. **Expiration customization**: Allow variable expiration periods
6. **Automatic signup**: Pre-populated form from invitation data
7. **Invite status tracking**: See which invites have been accepted
8. **Selective revocation**: Revoke access without deleting user

## Known Limitations

1. Email sending not yet implemented (marked as TODO in code)
2. No invitation resend functionality
3. No invitation revocation (can only grant/remove permissions after user joins)
4. No bulk invitation UI
5. No invitation templates
