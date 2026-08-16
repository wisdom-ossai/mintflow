"""
Fernet encryption for secrets stored at rest (Plaid access tokens).
Key is derived from SECRET_KEY so existing env vars work without a second secret.
"""
from __future__ import annotations

import base64
import hashlib
from functools import lru_cache

from cryptography.fernet import Fernet, InvalidToken

from app.core.config import get_settings

_PREFIX = "enc:v1:"


@lru_cache
def _fernet() -> Fernet:
    # Fernet requires a 32-byte url-safe base64 key; derive from SECRET_KEY.
    digest = hashlib.sha256(get_settings().SECRET_KEY.encode("utf-8")).digest()
    return Fernet(base64.urlsafe_b64encode(digest))


def encrypt_secret(plaintext: str | None) -> str | None:
    if plaintext is None:
        return None
    if plaintext.startswith(_PREFIX):
        return plaintext
    token = _fernet().encrypt(plaintext.encode("utf-8")).decode("utf-8")
    return f"{_PREFIX}{token}"


def decrypt_secret(ciphertext: str | None) -> str | None:
    if ciphertext is None:
        return None
    if not ciphertext.startswith(_PREFIX):
        # Legacy plaintext rows — return as-is so sync still works until re-encrypted.
        return ciphertext
    raw = ciphertext[len(_PREFIX) :]
    try:
        return _fernet().decrypt(raw.encode("utf-8")).decode("utf-8")
    except InvalidToken as exc:
        raise ValueError("Failed to decrypt secret") from exc
