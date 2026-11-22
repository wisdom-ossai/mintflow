"""Unit tests for snowball / avalanche debt payoff math."""
from decimal import Decimal
from types import SimpleNamespace

from app.models.models import DebtStrategy
from app.services.debt_service import accounts_to_debts, build_debt_plan_content


def _cc(name, balance, apr=None, minimum=None, id_="a1"):
    return SimpleNamespace(
        id=id_,
        name=name,
        outstanding_balance=Decimal(str(balance)),
        apr=Decimal(str(apr)) if apr is not None else None,
        minimum_payment=Decimal(str(minimum)) if minimum is not None else None,
    )


class TestDebtPlan:
    def test_requires_balances(self):
        try:
            build_debt_plan_content([], DebtStrategy.snowball, Decimal("100"))
            assert False, "expected ValueError"
        except ValueError as e:
            assert "No credit card" in str(e)

    def test_snowball_orders_lowest_balance_first(self):
        accounts = [
            _cc("High", 5000, apr=20, minimum=100, id_="h"),
            _cc("Low", 500, apr=25, minimum=25, id_="l"),
        ]
        content = build_debt_plan_content(
            accounts, DebtStrategy.snowball, Decimal("200")
        )
        assert content["allocations"][0]["account_id"] == "l"
        assert content["allocations"][0]["payoff_order"] == 1
        assert content["months_to_freedom"] > 0
        assert content["total_interest_saved"] >= 0

    def test_avalanche_orders_highest_apr_first(self):
        accounts = [
            _cc("Cheap", 2000, apr=10, minimum=50, id_="c"),
            _cc("Expensive", 2000, apr=29, minimum=50, id_="e"),
        ]
        content = build_debt_plan_content(
            accounts, DebtStrategy.avalanche, Decimal("150")
        )
        assert content["allocations"][0]["account_id"] == "e"
        assert "avalanche" in content["narrative"].lower()

    def test_default_apr_and_minimum(self):
        debts = accounts_to_debts([_cc("Card", 1000, id_="x")])
        assert len(debts) == 1
        assert debts[0].apr == Decimal("22.00")
        assert debts[0].minimum_payment == Decimal("25.00")
