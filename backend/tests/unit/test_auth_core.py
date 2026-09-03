"""Auth password + JWT unit tests."""
from datetime import datetime, timedelta, timezone

import pytest

from app.core.password import generate_opaque_token, hash_password, hash_token, verify_password
from app.core.security_jwt import create_access_token, decode_access_token


def test_argon2_roundtrip():
    h = hash_password("CorrectHorseBattery1!")
    assert verify_password(h, "CorrectHorseBattery1!")
    assert not verify_password(h, "wrong")


def test_opaque_token_hash():
    raw = generate_opaque_token()
    assert hash_token(raw) != raw
    assert hash_token(raw) == hash_token(raw)


def test_access_jwt(monkeypatch):
    monkeypatch.setenv("SECRET_KEY", "unit-test-secret-key-32chars-min!!")
    from app.core import config, security_jwt

    config.get_settings.cache_clear()
    monkeypatch.setattr(
        security_jwt,
        "settings",
        type(
            "S",
            (),
            {
                "SECRET_KEY": "unit-test-secret-key-32chars-min!!",
                "JWT_ALGORITHM": "HS256",
                "ACCESS_TOKEN_MINUTES": 15,
            },
        )(),
    )
    token = create_access_token(user_id="u1", email="a@b.com")
    payload = decode_access_token(token)
    assert payload["sub"] == "u1"
    assert payload["email"] == "a@b.com"
    assert payload["type"] == "access"
