"""
FastAPI REST API for invoice processing system
"""
from fastapi import FastAPI, Depends
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from datetime import datetime, timedelta
import os

from src.api.database import startup_event
from src.api.auth import router as auth_router, get_current_user
from src.api.invoices import router as invoices_router
from src.api.transactions import router as transactions_router
from src.api.reconciliation import router as reconciliation_router
from src.api.users import router as users_router
from src.api.settings import router as settings_router
from src.api.reports import router as reports_router
from src.api.vehicles import router as vehicles_router

app = FastAPI(title="Invoice Processing API", version="1.0.0")

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://127.0.0.1:3000", "https://carrosserie-erik.fr"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount uploads directory for static file serving
os.makedirs("data/uploads", exist_ok=True)
app.mount("/api/uploads", StaticFiles(directory="data/uploads"), name="uploads")


@app.on_event("startup")
def startup_event_wrapper():
    """Database startup and migrations"""
    startup_event()
    
    # Start scheduler in background
    try:
        from src.scheduler.main import InvoiceScheduler
        import threading
        
        def start_scheduler_bg():
            try:
                scheduler = InvoiceScheduler()
                scheduler.start()
            except Exception as e:
                print(f"[Scheduler] Failed to start: {e}")
        
        thread = threading.Thread(target=start_scheduler_bg, daemon=True)
        thread.start()
        print("[Scheduler] Starting in background thread...")
    except Exception as e:
        print(f"[Scheduler] Failed to initialize: {e}")


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
        import threading
        def run_fetch():
            try:
                scheduler.process_new_invoices(since_date=since_date)
            except Exception as e:
                print(f"[Background] Error fetching emails: {e}")
        
        thread = threading.Thread(target=run_fetch, daemon=True)
        thread.start()
        
        return {
            "message": f"Email fetch triggered for last {since_days} days",
            "since_date": since_date.isoformat(),
            "status": "processing"
        }
    except Exception as e:
        from fastapi import HTTPException
        raise HTTPException(status_code=500, detail=str(e))


# Register routers
app.include_router(auth_router, prefix="/api/auth", tags=["Authentication"])
app.include_router(invoices_router, prefix="/api/invoices", tags=["Invoices"])
app.include_router(transactions_router, prefix="/api/transactions", tags=["Transactions"])
app.include_router(reconciliation_router, prefix="/api/reconciliation", tags=["Reconciliation"])
app.include_router(users_router, prefix="/api/users", tags=["Users"])
app.include_router(settings_router, prefix="/api/settings", tags=["Settings"])
app.include_router(reports_router, prefix="/api/reports", tags=["Reports"])
app.include_router(vehicles_router, prefix="/api/vehicles", tags=["Vehicles"])


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
