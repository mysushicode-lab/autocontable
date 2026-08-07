"""File encryption at rest using AES-256-GCM."""
import os
import logging
from typing import Optional

import src.config  # noqa: F401

logger = logging.getLogger(__name__)

# Encryption key from env (32 bytes = 256 bits, hex-encoded = 64 chars)
_ENCRYPTION_KEY_HEX = os.getenv("FILE_ENCRYPTION_KEY")

try:
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM
    ENCRYPTION_AVAILABLE = bool(_ENCRYPTION_KEY_HEX)
    if ENCRYPTION_AVAILABLE:
        _KEY = bytes.fromhex(_ENCRYPTION_KEY_HEX)
        if len(_KEY) != 32:
            logger.error("FILE_ENCRYPTION_KEY must be 64 hex chars (32 bytes)")
            ENCRYPTION_AVAILABLE = False
except ImportError:
    ENCRYPTION_AVAILABLE = False
    logger.warning("cryptography library not installed — encryption disabled")


def encrypt_file(file_path: str) -> bool:
    """Encrypt a file in-place using AES-256-GCM.

    Adds a .enc extension. Returns True on success.
    The original file is replaced by the encrypted version.
    """
    if not ENCRYPTION_AVAILABLE:
        return False

    try:
        nonce = os.urandom(12)  # 96-bit nonce for GCM
        aesgcm = AESGCM(_KEY)

        with open(file_path, 'rb') as f:
            plaintext = f.read()

        ciphertext = aesgcm.encrypt(nonce, plaintext, None)

        # Write: nonce (12 bytes) + ciphertext
        enc_path = file_path + '.enc'
        with open(enc_path, 'wb') as f:
            f.write(nonce + ciphertext)

        # Remove original
        os.remove(file_path)
        return True
    except Exception as e:
        logger.error(f"Encryption failed for {file_path}: {e}")
        return False


def decrypt_file(enc_path: str) -> Optional[bytes]:
    """Decrypt a .enc file and return the plaintext bytes.

    Returns None if decryption fails or encryption is not available.
    """
    if not ENCRYPTION_AVAILABLE:
        return None

    try:
        with open(enc_path, 'rb') as f:
            data = f.read()

        nonce = data[:12]
        ciphertext = data[12:]

        aesgcm = AESGCM(_KEY)
        plaintext = aesgcm.decrypt(nonce, ciphertext, None)
        return plaintext
    except Exception as e:
        logger.error(f"Decryption failed for {enc_path}: {e}")
        return None


def is_encrypted(file_path: str) -> bool:
    """Check if a file path refers to an encrypted file."""
    return file_path.endswith('.enc')


def get_decrypted_path(file_path: str) -> str:
    """Get the path to serve — decrypts to temp if needed, returns original otherwise."""
    if not file_path:
        return file_path

    # If the .enc version exists, it's encrypted
    enc_path = file_path + '.enc' if not file_path.endswith('.enc') else file_path

    if os.path.exists(enc_path):
        # Decrypt to a temp file for serving
        import tempfile
        plaintext = decrypt_file(enc_path)
        if plaintext is None:
            return file_path  # Fallback to original path (will 404 naturally)

        # Write to temp file
        suffix = os.path.splitext(file_path.replace('.enc', ''))[1]
        tmp = tempfile.NamedTemporaryFile(delete=False, suffix=suffix)
        tmp.write(plaintext)
        tmp.close()
        return tmp.name

    # Not encrypted, return as-is
    return file_path
