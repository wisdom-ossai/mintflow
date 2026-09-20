"""Sign in with Apple audience config and placeholder email."""
from app.core.config import Settings
from app.services.auth_service import _apple_placeholder_email


def _settings(**kwargs) -> Settings:
    base = {
        "SECRET_KEY": "k" * 32,
        "DATABASE_URL": "postgresql+asyncpg://u:p@localhost/db",
        "PLAID_CLIENT_ID": "id",
        "PLAID_SECRET": "sec",
        "ANTHROPIC_API_KEY": "ant",
        "APPLE_BUNDLE_ID": "app.mintflow.ios",
    }
    base.update(kwargs)
    return Settings(_env_file=None, **base)


def test_apple_audiences_include_bundle_and_extras():
    s = _settings(APPLE_CLIENT_IDS="app.mintflow.ios, com.mintflow.service")
    assert s.apple_audiences == ["app.mintflow.ios", "com.mintflow.service"]


def test_apple_placeholder_email_is_unique_and_validish():
    email = _apple_placeholder_email("001234.abcdEFGH.xxxx")
    assert email.endswith("@signin.mintflow.app")
    assert "001234.abcdEFGH.xxxx" in email
