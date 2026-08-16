"""
Unit tests for P0 auth/crypto/feature-map invariants.
"""
from datetime import datetime, timedelta, timezone
from decimal import Decimal

import pytest

from app.core.crypto import decrypt_secret, encrypt_secret
from app.models.models import SubscriptionTier, User
from app.services.transaction_service import _is_cc_payment


class TestCrypto:
    def test_roundtrip(self, monkeypatch):
        monkeypatch.setenv("SECRET_KEY", "test-secret-key-for-fernet-derivation")
        # Clear cached settings + fernet
        from app.core import config, crypto

        config.get_settings.cache_clear()
        crypto._fernet.cache_clear()
        monkeypatch.setattr(
            "app.core.crypto.get_settings",
            lambda: type("S", (), {"SECRET_KEY": "test-secret-key-for-fernet-derivation"})(),
        )
        crypto._fernet.cache_clear()

        plain = "access-sandbox-abc123"
        enc = encrypt_secret(plain)
        assert enc is not None
        assert enc.startswith("enc:v1:")
        assert decrypt_secret(enc) == plain
        # Idempotent encrypt
        assert encrypt_secret(enc) == enc
        # Legacy plaintext passthrough
        assert decrypt_secret("legacy-plain-token") == "legacy-plain-token"


class TestFeatureMap:
    def _user(self, tier: SubscriptionTier, trial_ends_at=None) -> User:
        u = User()
        u.subscription_tier = tier
        u.trial_ends_at = trial_ends_at
        return u

    def test_seed_manual_only(self):
        u = self._user(SubscriptionTier.seed)
        assert not u.has_feature("bank_sync")
        assert not u.has_feature("ai_categorization")
        assert not u.has_feature("ai_insights")
        assert not u.has_feature("debt_payoff_plan")

    def test_growth_features(self):
        u = self._user(SubscriptionTier.growth)
        assert u.has_feature("bank_sync")
        assert u.has_feature("ai_categorization")
        assert u.has_feature("ai_insights")
        assert u.has_feature("category_budgets")
        assert u.has_feature("unlimited_goals")
        assert not u.has_feature("debt_payoff_plan")
        assert not u.has_feature("unlimited_accounts")

    def test_pro_and_trial(self):
        future = datetime.utcnow() + timedelta(days=3)
        u = self._user(SubscriptionTier.seed, trial_ends_at=future)
        assert u.is_trial_active
        assert u.effective_tier == SubscriptionTier.pro
        assert u.has_feature("debt_payoff_plan")
        assert u.has_feature("receipt_ocr")


class TestCcPayment:
    def test_keywords(self):
        assert _is_cc_payment("Online Payment", "Chase")
        assert not _is_cc_payment("Whole Foods", "Whole Foods")
