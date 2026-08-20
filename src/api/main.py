"""
FastAPI REST API for invoice processing system
"""
from contextlib import asynccontextmanager
from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.sessions import SessionMiddleware
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware
from datetime import datetime, timedelta
import os
import logging
import threading
import secrets

import src.config  # noqa: F401 — loads .env + .env.local before anything else

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
logger = logging.getLogger(__name__)

from src.api.database import startup_event
from src.api.rate_limit import limiter
from src.api.auth import router as auth_router, get_current_user
from src.api.auth_account import router as auth_account_router
from src.api.password import router as password_router
from src.api.oauth import router as oauth_router
from src.api.invoices import router as invoices_router
from src.api.transactions import router as transactions_router
from src.api.reconciliation import router as reconciliation_router
from src.api.users import router as users_router
from src.api.settings import router as settings_router
from src.api.reports import router as reports_router
from src.api.payments import router as stripe_router
from src.api.client_files import router as client_files_router
from src.api.audit import router as audit_router
from src.api.notifications import router as notifications_router
from src.api.integrations import router as integrations_router
from src.api.client_portal import router as client_portal_router
from src.api.upload_link import router as upload_link_router
from src.api.analytics import router as analytics_router
from src.api.permissions import router as permissions_router
from src.api.pcg import router as pcg_router
from src.api.webhooks import router as webhooks_router
from src.api.billing import router as billing_router
from src.api.whatsapp import router as whatsapp_router
from src.api.marketing_sync import router as marketing_sync_router
from src.api.affiliates import router as affiliates_router
from src.api.routes.quiz import router as quiz_router
from src.api.email_events import router as email_events_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan: run startup migrations.

    The invoice scheduler runs in its own dedicated container (see
    docker-compose service `scheduler`), so we don't launch it here to avoid
    double-execution and resource contention.
    """
    # --- Startup ---
    startup_event()
    logger.info("API ready")

    yield

    # --- Shutdown ---
    logger.info("Application shutting down")


app = FastAPI(title="Invoice Processing API", version="1.0.0", lifespan=lifespan)

# Session middleware (required for OAuth state management)
SESSION_SECRET = os.getenv("SESSION_SECRET", secrets.token_hex(32))
_is_production = os.getenv("FRONTEND_URL", "").startswith("https")
app.add_middleware(
    SessionMiddleware,
    secret_key=SESSION_SECRET,
    session_cookie="oauth_session",
    max_age=1800,
    same_site="lax",
    https_only=_is_production,
)

# Rate limiting (slowapi)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(SlowAPIMiddleware)

# CORS - allow only the methods and headers actually used by the frontend
_default_origins = "http://localhost:3000,http://127.0.0.1:3000"
allowed_origins = [o.strip() for o in os.getenv("CORS_ORIGINS", _default_origins).split(",") if o.strip()]

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "Accept", "Origin", "X-Requested-With"],
    expose_headers=["Content-Disposition"],
    max_age=600,
)

from src.utils.paths import PROFILE_PHOTOS_DIR
os.makedirs(PROFILE_PHOTOS_DIR, exist_ok=True)


@app.get("/api/uploads/profile_photos/{filename}")
def serve_profile_photo(filename: str, current_user: dict = Depends(get_current_user)):
    """Serve profile photo only if the requesting user belongs to the same organisation."""
    from fastapi.responses import FileResponse
    from src.storage.database import db
    from src.storage.models import User

    # Reject path traversal attempts
    if ".." in filename or "/" in filename or "\\" in filename:
        raise HTTPException(status_code=400, detail="Nom de fichier invalide")

    # Only user_{id}.ext filenames are generated — enforce the pattern
    import re
    if not re.fullmatch(r"user_\d+\.(jpg|jpeg|png|gif|webp)", filename, re.IGNORECASE):
        raise HTTPException(status_code=400, detail="Nom de fichier invalide")

    user_id = int(filename.split("_")[1].split(".")[0])
    session = db.get_session()
    try:
        user = session.query(User).filter(
            User.id == user_id,
            User.organization_id == current_user["organization_id"],
        ).first()
        if not user:
            raise HTTPException(status_code=404, detail="Photo introuvable")
    finally:
        session.close()

    safe_root = os.path.realpath(PROFILE_PHOTOS_DIR)
    file_path = os.path.realpath(os.path.join(safe_root, filename))
    if not (file_path == safe_root or file_path.startswith(safe_root + os.sep)):
        raise HTTPException(status_code=400, detail="Nom de fichier invalide")
    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="Photo introuvable")

    return FileResponse(file_path)


@app.get("/")
def root():
    """Root endpoint"""
    return {
        "message": "Invoice Processing & Bank Reconciliation API",
        "version": "1.0.0"
    }


@app.post("/api/emails/fetch")
def trigger_email_fetch(since_days: int = 30, current_user: dict = Depends(get_current_user)):
    """Trigger immediate email fetching for the caller's organisation only.

    Args:
        since_days: Fetch emails from last N days (default: 30, max: 90)
    """
    from src.scheduler.main import InvoiceScheduler

    role = current_user.get("role", "")
    if role not in ("admin", "accountant"):
        raise HTTPException(status_code=403, detail="Accès réservé aux administrateurs et comptables")

    if since_days < 1 or since_days > 90:
        raise HTTPException(status_code=400, detail="since_days doit être entre 1 et 90")

    org_id = current_user.get("organization_id")
    if not org_id:
        raise HTTPException(status_code=400, detail="Aucune organisation associée à ce compte")

    since_date = datetime.utcnow() - timedelta(days=since_days)

    def run_fetch():
        try:
            scheduler = InvoiceScheduler()
            scheduler.process_org_invoices(org_id, since_date=since_date)
        except Exception as e:
            logger.error(f"Background email fetch error for org {org_id}: {e}")

    thread = threading.Thread(target=run_fetch, daemon=True)
    thread.start()

    return {
        "message": f"Email fetch triggered for organisation {org_id} (last {since_days} days)",
        "since_date": since_date.isoformat(),
        "status": "processing",
    }


# Register routers
app.include_router(auth_router, prefix="/api/auth", tags=["Authentication"])
app.include_router(auth_account_router, prefix="/api/auth", tags=["Authentication"])
app.include_router(password_router, prefix="/api/auth", tags=["Authentication"])
app.include_router(oauth_router, prefix="/api", tags=["OAuth"])
app.include_router(invoices_router, prefix="/api/invoices", tags=["Invoices"])
app.include_router(transactions_router, prefix="/api/transactions", tags=["Transactions"])
app.include_router(reconciliation_router, prefix="/api/reconciliation", tags=["Reconciliation"])
app.include_router(users_router, prefix="/api/users", tags=["Users"])
app.include_router(settings_router, prefix="/api/settings", tags=["Settings"])
app.include_router(reports_router, prefix="/api/reports", tags=["Reports"])
app.include_router(stripe_router, prefix="/api/stripe", tags=["Stripe"])
app.include_router(client_files_router, prefix="/api/client-files", tags=["ClientFiles"])
app.include_router(audit_router, prefix="/api/audit", tags=["Audit"])
app.include_router(notifications_router, prefix="/api/notifications", tags=["Notifications"])
app.include_router(integrations_router, prefix="/api/integrations", tags=["Integrations"])
app.include_router(client_portal_router, prefix="/api/portal", tags=["Client Portal"])
app.include_router(upload_link_router, prefix="/api/depot", tags=["Upload Link"])
app.include_router(analytics_router, prefix="/api/analytics", tags=["Analytics"])
app.include_router(permissions_router, prefix="/api/permissions", tags=["Permissions"])
app.include_router(pcg_router, prefix="/api/pcg", tags=["PCG"])
app.include_router(webhooks_router, prefix="/api/webhooks", tags=["Webhooks"])
app.include_router(billing_router, prefix="/api/billing", tags=["Billing"])
app.include_router(whatsapp_router, prefix="/api/whatsapp", tags=["WhatsApp"])
app.include_router(marketing_sync_router, prefix="/api/marketing", tags=["Marketing"])
app.include_router(affiliates_router, prefix="/api/affiliates", tags=["Affiliates"])
app.include_router(email_events_router, prefix="/api", tags=["Email Events"])
app.include_router(quiz_router, tags=["Quiz"])


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=int(os.getenv("BACKEND_PORT", 8001)))
