# Email Invitation Implementation TODO

## Current State
The invitation system is fully functional for manual testing - admins can generate invitation links and share them manually with PME users. The only missing piece is automatic email sending.

## Code Locations with TODO Comments

### 1. `src/api/permissions.py` (Line 249-251)
```python
# Send email (TODO: implement email service)
join_url = f"{os.getenv('FRONTEND_URL', 'http://localhost:3000')}/join?token={token}"
# TODO: send_invitation_email(invited_email, cf.name, join_url, current_user["name"])
```

**What to do**: After InvitationToken is created, send email to `invited_email` with the join_url

**Email template should include**:
- Cabinet name / Admin name
- Dossier name
- Permission level (read_only or read_write)
- Join button/link
- Expiration notice (7 days)
- Plain text alternative

## Implementation Options

### Option 1: SendGrid
**Pros**: Reliable, good deliverability, free tier available
**Setup**:
```python
import sendgrid
from sendgrid.helpers.mail import Mail

def send_invitation_email(to_email: str, dossier_name: str, join_url: str, admin_name: str):
    sg = sendgrid.SendGridAPIClient(os.getenv('SENDGRID_API_KEY'))
    message = Mail(
        from_email=os.getenv('MAIL_FROM', 'noreply@autocontable.fr'),
        to_emails=to_email,
        subject=f"Vous avez été invité à accéder à {dossier_name}",
        html_content=f"""
        <h2>Invitation d'accès</h2>
        <p>{admin_name} vous a invité à accéder au dossier: <strong>{dossier_name}</strong></p>
        <p><a href="{join_url}">Accepter l'invitation</a></p>
        <p>Ce lien expire dans 7 jours.</p>
        """
    )
    sg.send(message)
```

### Option 2: AWS SES
**Pros**: Cost-effective for high volume, part of AWS ecosystem
**Setup**: Similar to SendGrid, use boto3

### Option 3: Mailgun
**Pros**: Developer-friendly, REST API
**Setup**:
```python
import requests

def send_invitation_email(to_email: str, dossier_name: str, join_url: str, admin_name: str):
    domain = os.getenv('MAILGUN_DOMAIN')
    api_key = os.getenv('MAILGUN_API_KEY')
    
    requests.post(
        f"https://api.mailgun.net/v3/{domain}/messages",
        auth=("api", api_key),
        data={
            "from": f"AutoContable <noreply@{domain}>",
            "to": to_email,
            "subject": f"Invitation: {dossier_name}",
            "html": f"...",
        }
    )
```

### Option 4: In-house SMTP
**Pros**: No external dependencies, full control
**Setup**:
```python
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

def send_invitation_email(to_email: str, dossier_name: str, join_url: str, admin_name: str):
    smtp_server = os.getenv('SMTP_SERVER', 'localhost')
    smtp_port = int(os.getenv('SMTP_PORT', 587))
    smtp_user = os.getenv('SMTP_USER')
    smtp_pass = os.getenv('SMTP_PASSWORD')
    
    msg = MIMEMultipart('alternative')
    msg['Subject'] = f"Invitation: {dossier_name}"
    msg['From'] = os.getenv('MAIL_FROM', 'noreply@autocontable.fr')
    msg['To'] = to_email
    
    text = f"Vous avez été invité à accéder au dossier {dossier_name}.\n\nCliquez ici: {join_url}"
    html = f"""
    <html>
        <body>
            <h2>Invitation</h2>
            <p>Vous avez été invité par {admin_name} à accéder au dossier <strong>{dossier_name}</strong></p>
            <p><a href="{join_url}" style="background: #0066cc; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px; display: inline-block;">Accepter</a></p>
            <p><small>Ce lien expire dans 7 jours.</small></p>
        </body>
    </html>
    """
    
    msg.attach(MIMEText(text, 'plain'))
    msg.attach(MIMEText(html, 'html'))
    
    with smtplib.SMTP(smtp_server, smtp_port) as server:
        server.starttls()
        server.login(smtp_user, smtp_pass)
        server.sendmail(os.getenv('MAIL_FROM'), to_email, msg.as_string())
```

## Implementation Steps

1. **Choose email provider** (recommend SendGrid for reliability)

2. **Add environment variables** to `.env.local`:
   ```
   SENDGRID_API_KEY=SG.xxxxx
   MAIL_FROM=noreply@autocontable.fr
   ```

3. **Create email service module** (`src/services/email.py`):
   ```python
   def send_invitation_email(to_email: str, dossier_name: str, join_url: str, admin_name: str, cabinet_name: str):
       """Send invitation email to PME/client"""
       # Implementation here
   ```

4. **Update `src/api/permissions.py`** (line ~251):
   ```python
   from src.services.email import send_invitation_email
   
   # In invite_user_to_dossier function:
   send_invitation_email(
       invited_email,
       cf.name,
       join_url,
       current_user["name"]
   )
   ```

5. **Test with SendGrid sandbox** or email provider's test mode

6. **Add email verification** to catch invalid addresses before sending

## Alternative: Asynchronous Email

For better performance, use a task queue:

```python
from celery import shared_task

@shared_task
def send_invitation_email_async(to_email: str, dossier_name: str, join_url: str, admin_name: str):
    send_invitation_email(to_email, dossier_name, join_url, admin_name)

# In permissions.py:
send_invitation_email_async.delay(invited_email, cf.name, join_url, current_user["name"])
```

Benefits:
- Non-blocking (faster response to admin)
- Retry logic for failed sends
- Centralized email queue
- Can scale independently

## Email Template Best Practices

- **Subject**: Keep under 50 chars, include dossier name
- **Preview text**: Add 100-char preview after subject
- **Branding**: Include company logo, colors
- **CTA button**: Clear, contrasting color, easy to click
- **Plain text**: Include for spam filtering/accessibility
- **Unsubscribe**: Add unsubscribe link (email compliance)
- **Footer**: Company info, contact details
- **Mobile**: Responsive design (60% of opens are mobile)

## Testing

```python
# Test manually
from src.services.email import send_invitation_email
send_invitation_email(
    "test@example.com",
    "Test Dossier",
    "http://localhost:3000/join?token=test123",
    "Admin Name"
)
```

## Monitoring

1. Track email delivery rates
2. Log send failures
3. Monitor bounce/complaint rates
4. Alert on delivery issues
5. Archive sent emails for compliance

## Compliance

- **GDPR**: Users can unsubscribe from emails (but not transactional invites)
- **CAN-SPAM**: Include unsubscribe link in non-transactional emails
- **Data retention**: Store email logs for audit trail
- **Consent**: Invitations are implied opt-in (user requested by cabinet)

## Security

- Never log full email content
- Use environment variables for credentials (never commit keys)
- Validate email addresses before sending
- Rate limit email sending per user/org
- Log email events for audit trail
