"""Unit tests for bill due-date clamping."""
from datetime import datetime, timezone

from app.api.v1.endpoints.bills import due_date_for_month


class TestDueDateForMonth:
    def test_normal_day(self):
        d = due_date_for_month(2026, 9, 15)
        assert d == datetime(2026, 9, 15, tzinfo=timezone.utc)

    def test_clamps_feb_non_leap(self):
        d = due_date_for_month(2025, 2, 31)
        assert d.day == 28

    def test_clamps_feb_leap(self):
        d = due_date_for_month(2024, 2, 31)
        assert d.day == 29

    def test_april_30(self):
        d = due_date_for_month(2026, 4, 31)
        assert d.day == 30
