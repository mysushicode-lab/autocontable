"""Invoice API package - combines all invoice sub-routers into a single router."""
from fastapi import APIRouter

from src.api.invoices.upload import router as upload_router
from src.api.invoices.crud import router as crud_router
from src.api.invoices.download import router as download_router

router = APIRouter()

router.include_router(upload_router, tags=["Invoices"])
router.include_router(crud_router, tags=["Invoices"])
router.include_router(download_router, tags=["Invoices"])
