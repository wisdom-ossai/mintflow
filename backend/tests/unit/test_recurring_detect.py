"""Unit tests for recurring subscription detection (Plaid-first)."""
from datetime import datetime, timedelta, timezone
from decimal import Decimal

from app.models.models import RecurringFrequency
from app.services.recurring_service import (
    detect_series_from_transactions,
    normalize_merchant,
)


def _d(n: int) -> datetime:
    return datetime(2025, 1, 1, tzinfo=timezone.utc) + timedelta(days=n)


class TestNormalizeMerchant:
    def test_strips_legal_and_store_numbers(self):
        assert normalize_merchant("NETFLIX.COM #1234") == "netflix"
        assert normalize_merchant("Spotify USA Inc") == "spotify usa"

    def test_empty(self):
        assert normalize_merchant("") == ""
        assert normalize_merchant("   ") == ""


class TestDetectSeries:
    def test_monthly_netflix(self):
        rows = [
            ("1", "NETFLIX.COM", Decimal("15.99"), _d(0)),
            ("2", "NETFLIX.COM", Decimal("15.99"), _d(30)),
            ("3", "Netflix.com", Decimal("15.99"), _d(61)),
        ]
        found = detect_series_from_transactions(rows)
        assert len(found) == 1
        s = found[0]
        assert s.merchant_key == "netflix"
        assert s.frequency == RecurringFrequency.monthly
        assert s.occurrence_count == 3
        assert s.typical_amount == Decimal("15.99")

    def test_weekly_consistent(self):
        rows = [
            ("1", "HelloFresh", Decimal("80.00"), _d(0)),
            ("2", "HelloFresh", Decimal("80.00"), _d(7)),
            ("3", "HelloFresh", Decimal("82.00"), _d(14)),
        ]
        found = detect_series_from_transactions(rows)
        assert len(found) == 1
        assert found[0].frequency == RecurringFrequency.weekly

    def test_ignores_one_off(self):
        rows = [
            ("1", "IKEA", Decimal("240.00"), _d(0)),
            ("2", "IKEA", Decimal("12.00"), _d(90)),  # amount inconsistent
        ]
        assert detect_series_from_transactions(rows) == []

    def test_needs_two_occurrences(self):
        rows = [("1", "Hulu", Decimal("12.00"), _d(0))]
        assert detect_series_from_transactions(rows) == []

    def test_irregular_gaps_ignored(self):
        rows = [
            ("1", "Uber", Decimal("25.00"), _d(0)),
            ("2", "Uber", Decimal("25.00"), _d(3)),
            ("3", "Uber", Decimal("25.00"), _d(40)),
        ]
        assert detect_series_from_transactions(rows) == []
