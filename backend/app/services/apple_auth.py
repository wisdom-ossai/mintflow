"""
Verify Sign in with Apple identity tokens (RS256 JWKS from Apple).
Audience is the iOS bundle ID (and optional Services IDs).
"""
from __future__ import annotations

import logging
import time
from typing import Any

import httpx
from jose import jwt
from jose.exceptions import JWTError

from app.core.config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

_APPLE_ISS = "https://appleid.apple.com"
_JWKS_URL = "https://appleid.apple.com/auth/keys"
_jwks: dict[str, Any] | None = None
_jwks_at: float = 0.0
_JWKS_TTL = 3600.0


def _load_jwks() -> dict[str, Any]:
    global _jwks, _jwks_at
    now = time.monotonic()
    if _jwks is not None and (now - _jwks_at) < _JWKS_TTL:
        return _jwks
    with httpx.Client(timeout=10.0) as client:
        resp = client.get(_JWKS_URL)
        resp.raise_for_status()
        _jwks = resp.json()
        _jwks_at = now
    return _jwks


def verify_apple_identity_token(token: str) -> dict[str, Any]:
    """
    Returns Apple claims: sub, email (optional after first auth), email_verified.
    Raises ValueError on invalid token.
    """
    audiences = settings.apple_audiences
    if not audiences:
        raise ValueError("Sign in with Apple is not configured (APPLE_BUNDLE_ID)")

    try:
        header = jwt.get_unverified_header(token)
    except JWTError as e:
        raise ValueError("Invalid Apple identity token") from e

    kid = header.get("kid")
    keys = _load_jwks().get("keys") or []
    matching = next((k for k in keys if k.get("kid") == kid), None)
    if matching is None:
        # Key rotation — refresh JWKS once
        global _jwks
        _jwks = None
        keys = _load_jwks().get("keys") or []
        matching = next((k for k in keys if k.get("kid") == kid), None)
    if matching is None:
        raise ValueError("Invalid Apple identity token")

    last_error: Exception | None = None
    for audience in audiences:
        try:
            return jwt.decode(
                token,
                matching,
                algorithms=["RS256"],
                audience=audience,
                issuer=_APPLE_ISS,
                options={"verify_at_hash": False},
            )
        except Exception as e:
            last_error = e
            continue
    logger.warning("Apple identity token verification failed: %s", last_error)
    raise ValueError("Invalid Apple identity token")
