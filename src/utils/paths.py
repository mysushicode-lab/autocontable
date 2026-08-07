"""Centralized data paths — all configurable via env vars."""
import os

import src.config  # noqa: F401

DATA_DIR = os.getenv("DATA_DIR", "data")

INVOICES_DIR = os.getenv("INVOICES_DIR", os.path.join(DATA_DIR, "invoices"))
INVOICE_UPLOAD_DIR = os.getenv("INVOICE_UPLOAD_DIR", os.path.join(DATA_DIR, "uploads", "invoices"))
BANK_UPLOAD_DIR = os.getenv("BANK_UPLOAD_DIR", os.path.join(DATA_DIR, "uploads", "bank_statements"))
EXPORTS_DIR = os.getenv("EXPORTS_DIR", os.path.join(DATA_DIR, "exports"))
PROFILE_PHOTOS_DIR = os.getenv("PROFILE_PHOTOS_DIR", os.path.join(DATA_DIR, "uploads", "profile_photos"))
