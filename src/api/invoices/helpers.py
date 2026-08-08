"""Invoice helpers and utilities"""
import os
import hashlib
from fastapi import HTTPException
from src.utils.paths import DATA_DIR

_SAFE_DATA_ROOT = os.path.realpath(DATA_DIR)


def resolve_invoice_file_path(raw_path: str) -> str:
	"""Resolve and validate an invoice file path against the data root.

	Raises HTTPException 400 on path traversal, 404 if file not found.
	"""
	if not os.path.isabs(raw_path):
		resolved = os.path.realpath(os.path.join(os.getcwd(), raw_path.lstrip('/\\')))
	else:
		resolved = os.path.realpath(raw_path)

	if not (resolved == _SAFE_DATA_ROOT or resolved.startswith(_SAFE_DATA_ROOT + os.sep)):
		raise HTTPException(status_code=400, detail="Chemin de fichier invalide")

	if not os.path.exists(resolved):
		raise HTTPException(status_code=404, detail="Fichier PDF introuvable")

	return resolved


def compute_file_hash(file_bytes: bytes) -> str:
	"""Compute MD5 hash of file contents"""
	return hashlib.md5(file_bytes).hexdigest()


ALLOWED_INVOICE_EXTENSIONS = {".pdf", ".png", ".jpg", ".jpeg", ".tiff", ".bmp"}
