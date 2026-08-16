"""
Unit tests for core transaction business logic.
Focus: double-count prevention, categorization routing, spend calculations.
"""
import pytest
from decimal import Decimal
from unittest.mock import AsyncMock, MagicMock, patch
from datetime import datetime, timezone

from app.services.transaction_service import _is_cc_payment, create_transaction
from app.models.models import TransactionType, TransactionSource
from app.schemas.schemas import TransactionCreate


# ─── CC payment detection ─────────────────────────────────────────────────

class TestCCPaymentDetection:
    def test_autopay_detected(self):
        assert _is_cc_payment("AUTOPAY AMEX GOLD", "") is True

    def test_online_payment_detected(self):
        assert _is_cc_payment("ONLINE PAYMENT - THANK YOU", "") is True

    def test_mobile_payment_detected(self):
        assert _is_cc_payment("PAYMENT - MOBILE", "") is True

    def test_regular_purchase_not_detected(self):
        assert _is_cc_payment("WHOLE FOODS MARKET", "") is False

    def test_netflix_not_detected(self):
        assert _is_cc_payment("NETFLIX.COM", "") is False

    def test_starbucks_not_detected(self):
        assert _is_cc_payment("STARBUCKS #1234", "") is False

    def test_empty_strings(self):
        assert _is_cc_payment("", "") is False

    def test_case_insensitive(self):
        assert _is_cc_payment("Online Payment Thank You", "") is True


# ─── Transaction counts_as_spend property ────────────────────────────────

class TestCountsAsSpend:
    def _make_tx(self, tx_type, is_cc_payment=False):
        from app.models.models import Transaction
        tx = Transaction()
        tx.transaction_type = tx_type
        tx.is_credit_card_payment = is_cc_payment
        return tx

    def test_regular_expense_counts(self):
        tx = self._make_tx(TransactionType.expense)
        assert tx.counts_as_spend is True

    def test_cc_payment_does_not_count(self):
        tx = self._make_tx(TransactionType.expense, is_cc_payment=True)
        assert tx.counts_as_spend is False

    def test_income_does_not_count(self):
        tx = self._make_tx(TransactionType.income)
        assert tx.counts_as_spend is False

    def test_transfer_does_not_count(self):
        tx = self._make_tx(TransactionType.transfer)
        assert tx.counts_as_spend is False


# ─── User feature gating ─────────────────────────────────────────────────

class TestFeatureGating:
    def _make_user(self, tier, trial_ends_at=None):
        from app.models.models import User, SubscriptionTier
        user = User()
        user.subscription_tier = SubscriptionTier(tier)
        user.trial_ends_at = trial_ends_at
        return user

    def test_seed_has_no_bank_sync(self):
        user = self._make_user("seed")
        assert user.has_feature("bank_sync") is False

    def test_growth_has_bank_sync(self):
        user = self._make_user("growth")
        assert user.has_feature("bank_sync") is True

    def test_pro_has_unlimited_accounts(self):
        user = self._make_user("pro")
        assert user.has_feature("unlimited_accounts") is True

    def test_growth_has_no_unlimited_accounts(self):
        user = self._make_user("growth")
        assert user.has_feature("unlimited_accounts") is False

    def test_trial_user_gets_pro_features(self):
        from datetime import timedelta
        future = datetime.utcnow().replace(tzinfo=timezone.utc) + timedelta(days=5)
        user = self._make_user("seed", trial_ends_at=future)
        assert user.has_feature("unlimited_accounts") is True

    def test_expired_trial_reverts_to_seed(self):
        from datetime import timedelta
        past = datetime.utcnow().replace(tzinfo=timezone.utc) - timedelta(days=1)
        user = self._make_user("seed", trial_ends_at=past)
        assert user.has_feature("bank_sync") is False


# ─── Dashboard spend totals ───────────────────────────────────────────────

class TestDashboardSpendTotals:
    def test_cc_payments_excluded_from_totals(self):
        """
        Regression test: if a user spends $500 on CC and pays $500 bill,
        total spend should be $500 not $1000.
        """
        from app.models.models import Transaction, TransactionType
        transactions = []

        # CC purchase
        t1 = Transaction()
        t1.transaction_type = TransactionType.expense
        t1.is_credit_card_payment = False
        t1.amount = Decimal("500.00")
        transactions.append(t1)

        # CC bill payment
        t2 = Transaction()
        t2.transaction_type = TransactionType.expense
        t2.is_credit_card_payment = True
        t2.amount = Decimal("500.00")
        transactions.append(t2)

        total_spend = sum(
            t.amount for t in transactions if t.counts_as_spend
        )
        assert total_spend == Decimal("500.00"), (
            f"Expected $500 but got ${total_spend} — CC payment double-counted!"
        )