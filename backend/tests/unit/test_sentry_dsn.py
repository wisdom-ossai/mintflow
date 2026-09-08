"""Sentry must not start (or crash boot) on empty/placeholder DSNs."""
from app.core.config import usable_sentry_dsn


def test_empty_and_whitespace_are_ignored():
    assert usable_sentry_dsn(None) is None
    assert usable_sentry_dsn("") is None
    assert usable_sentry_dsn("   ") is None


def test_placeholder_from_env_example_is_ignored():
    # Railway crash: sentry_sdk.utils.BadDsn: Missing public key
    assert usable_sentry_dsn("https://your-sentry-dsn") is None


def test_dsn_without_project_id_is_ignored():
    assert usable_sentry_dsn("https://abc123@o0.ingest.sentry.io") is None
    assert usable_sentry_dsn("https://abc123@o0.ingest.sentry.io/") is None


def test_real_dsn_is_accepted():
    dsn = "https://abc123def@o123.ingest.sentry.io/456"
    assert usable_sentry_dsn(dsn) == dsn
