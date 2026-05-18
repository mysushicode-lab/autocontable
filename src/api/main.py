"""
FastAPI REST API for invoice processing system
"""
from contextlib import asynccontextmanager
from fastapi import FastAPI, Depends, HTTPException
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware
from datetime import datetime, timedelta
import os
import logging
import threading
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
logger = logging.getLogger(__name__)

from src.api.database import startup_event
from src.api.rate_limit import limiter
from src.api.auth import router as auth_router, get_current_user
from src.api.invoices import router as invoices_router
from src.api.transactions import router as transactions_router
from src.api.reconciliation import router as reconciliation_router
from src.api.users import router as users_router
from src.api.settings import router as settings_router
from src.api.reports import router as reports_router
from src.api.vehicles import router as vehicles_router
from src.api.payments import router as stripe_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan: run startup migrations and launch the scheduler."""
    # --- Startup ---
    startup_event()

    try:
        from src.scheduler.main import InvoiceScheduler

        def start_scheduler_bg():
            try:
                scheduler = InvoiceScheduler()
                scheduler.start()
            except Exception as e:
                logger.error(f"Scheduler failed to start: {e}")

        thread = threading.Thread(target=start_scheduler_bg, daemon=True)
        thread.start()
        logger.info("Scheduler starting in background thread")
    except Exception as e:
        logger.error(f"Scheduler failed to initialize: {e}")

    yield

    # --- Shutdown ---
    logger.info("Application shutting down")


app = FastAPI(title="Invoice Processing API", version="1.0.0", lifespan=lifespan)

# Rate limiting (slowapi)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(SlowAPIMiddleware)

# CORS - allow only the methods and headers actually used by the frontend
_default_origins = "http://localhost:3000,http://127.0.0.1:3000,https://carrosserie-erik.fr"
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

# Mount profile photos directory for public static serving (profile photos only)
os.makedirs("data/uploads/profile_photos", exist_ok=True)
app.mount("/api/uploads/profile_photos", StaticFiles(directory="data/uploads/profile_photos"), name="profile_photos")


@app.get("/")
def root():
    """Root endpoint"""
    return {
        "message": "Invoice Processing & Bank Reconciliation API",
        "version": "1.0.0"
    }


@app.post("/api/emails/fetch")
def trigger_email_fetch(since_days: int = 30, current_user: dict = Depends(get_current_user)):
    """
    Trigger immediate email fetching and processing.
    Called on frontend startup or on demand.

    Args:
        since_days: Fetch emails from last N days (default: 30)
    """
    from src.scheduler.main import InvoiceScheduler

    try:
        scheduler = InvoiceScheduler()
        since_date = datetime.now() - timedelta(days=since_days)

        # Run processing in background thread to not block API
        def run_fetch():
            try:
                scheduler.process_new_invoices(since_date=since_date)
            except Exception as e:
                logger.error(f"Background email fetch error: {e}")

        thread = threading.Thread(target=run_fetch, daemon=True)
        thread.start()

        return {
            "message": f"Email fetch triggered for last {since_days} days",
            "since_date": since_date.isoformat(),
            "status": "processing"
        }
    except Exception as e:
        logger.exception("trigger_email_fetch failed")
        raise HTTPException(status_code=500, detail="Internal server error")


# Register routers
app.include_router(auth_router, prefix="/api/auth", tags=["Authentication"])
app.include_router(invoices_router, prefix="/api/invoices", tags=["Invoices"])
app.include_router(transactions_router, prefix="/api/transactions", tags=["Transactions"])
app.include_router(reconciliation_router, prefix="/api/reconciliation", tags=["Reconciliation"])
app.include_router(users_router, prefix="/api/users", tags=["Users"])
app.include_router(settings_router, prefix="/api/settings", tags=["Settings"])
app.include_router(reports_router, prefix="/api/reports", tags=["Reports"])
app.include_router(vehicles_router, prefix="/api/vehicles", tags=["Vehicles"])
app.include_router(stripe_router, prefix="/api/stripe", tags=["Stripe"])


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
