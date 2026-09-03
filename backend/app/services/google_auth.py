"""
Verify Google ID tokens from the Flutter google_sign_in SDK.
"""
from __future__ import annotations

import logging
from typing import Any

from google.auth.transport import requests as google_requests
from google.oauth2 import id_token

from app.core.config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()


def verify_google_id_token(token: str) -> dict[str, Any]:
    """
    Returns Google claims: sub, email, email_verified, name, picture.
    Raises ValueError on invalid token.
    """
    audiences = settings.google_audiences
    if not audiences:
        raise ValueError("Google Sign-In is not configured (GOOGLE_CLIENT_ID)")

    last_error: Exception | None = None
    for audience in audiences:
        try:
            return id_token.verify_oauth2_token(
                token,
                google_requests.Request(),
                audience,
            )
        except Exception as e:
            last_error = e
            continue
    logger.warning("Google ID token verification failed: %s", last_error)
    raise ValueError("Invalid Google ID token")
