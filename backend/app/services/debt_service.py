"""
Debt payoff math — snowball (lowest balance first) and avalanche (highest APR first).

Industry-standard amortization with monthly compounding. Extra payment always
goes to the focus debt after minimums are applied to every account.
"""
from __future__ import annotations

from copy import deepcopy
from dataclasses import dataclass
from datetime import datetime, timezone
from decimal import Decimal, ROUND_HALF_UP
from typing import Literal

from app.models.models import Account, DebtStrategy

_DEFAULT_APR = Decimal("22.00")
_MIN_FLOOR = Decimal("25.00")
_MIN_PCT = Decimal("0.02")
_MONEY = Decimal("0.01")
_MAX_MONTHS = 600  # 50 years safety cap


@dataclass
class _Debt:
    account_id: str
    account_name: str
    balance: Decimal
    apr: Decimal
    minimum_payment: Decimal


def _money(v: Decimal) -> Decimal:
    return v.quantize(_MONEY, rounding=ROUND_HALF_UP)


def _default_minimum(balance: Decimal) -> Decimal:
    return max(_MIN_FLOOR, _money(balance * _MIN_PCT))


def accounts_to_debts(accounts: list[Account]) -> list[_Debt]:
    debts: list[_Debt] = []
    for a in accounts:
        bal = a.outstanding_balance
        if bal is None or bal <= 0:
            continue
        apr = a.apr if a.apr is not None else _DEFAULT_APR
        minimum = (
            a.minimum_payment
            if a.minimum_payment is not None and a.minimum_payment > 0
            else _default_minimum(bal)
        )
        debts.append(
            _Debt(
                account_id=str(a.id),
                account_name=a.name,
                balance=_money(bal),
                apr=_money(apr),
                minimum_payment=_money(minimum),
            )
        )
    return debts


def _sort_debts(debts: list[_Debt], strategy: DebtStrategy) -> list[_Debt]:
    if strategy == DebtStrategy.snowball:
        return sorted(debts, key=lambda d: (d.balance, -d.apr, d.account_name))
    return sorted(debts, key=lambda d: (-d.apr, d.balance, d.account_name))


def _simulate(
    debts: list[_Debt],
    monthly_extra: Decimal,
    strategy: DebtStrategy,
) -> dict:
    """
    Returns freedom_date, interest totals, and per-account allocations.
    """
    working = deepcopy(debts)
    order_index = {d.account_id: i + 1 for i, d in enumerate(_sort_debts(working, strategy))}
    payoff_dates: dict[str, datetime] = {}
    first_month_payment: dict[str, Decimal] = {d.account_id: Decimal("0") for d in working}
    interest_with_plan = Decimal("0")
    start = datetime.now(timezone.utc)
    month = 0

    while any(d.balance > 0 for d in working) and month < _MAX_MONTHS:
        month += 1
        # Accrue interest
        for d in working:
            if d.balance <= 0:
                continue
            monthly_rate = d.apr / Decimal("100") / Decimal("12")
            interest = _money(d.balance * monthly_rate)
            d.balance = _money(d.balance + interest)
            interest_with_plan += interest

        active = [d for d in working if d.balance > 0]
        if not active:
            break

        ordered = _sort_debts(active, strategy)
        remaining_extra = monthly_extra

        # Minimums first
        for d in ordered:
            pay = min(d.minimum_payment, d.balance)
            d.balance = _money(d.balance - pay)
            if month == 1:
                first_month_payment[d.account_id] = _money(
                    first_month_payment[d.account_id] + pay
                )
            if d.balance <= 0:
                d.balance = Decimal("0")
                payoff_dates.setdefault(
                    d.account_id,
                    _add_months(start, month),
                )

        # Extra to focus debt (first in ordered that still has balance)
        for d in ordered:
            if d.balance <= 0 or remaining_extra <= 0:
                continue
            extra = min(remaining_extra, d.balance)
            d.balance = _money(d.balance - extra)
            remaining_extra = _money(remaining_extra - extra)
            if month == 1:
                first_month_payment[d.account_id] = _money(
                    first_month_payment[d.account_id] + extra
                )
            if d.balance <= 0:
                d.balance = Decimal("0")
                payoff_dates.setdefault(
                    d.account_id,
                    _add_months(start, month),
                )
            break  # snowball/avalanche: all extra to one focus debt

    # Mins-only interest baseline
    interest_mins = _interest_minimums_only(debts)

    freedom = _add_months(start, month) if month > 0 else start
    allocations = []
    for d in debts:
        allocations.append(
            {
                "account_id": d.account_id,
                "account_name": d.account_name,
                "balance": float(d.balance),
                "apr": float(d.apr),
                "minimum_payment": float(d.minimum_payment),
                "total_payment": float(first_month_payment.get(d.account_id, d.minimum_payment)),
                "projected_payoff_date": payoff_dates.get(
                    d.account_id, freedom
                ).isoformat(),
                "payoff_order": order_index.get(d.account_id, 99),
            }
        )
    allocations.sort(key=lambda a: a["payoff_order"])

    saved = max(Decimal("0"), interest_mins - interest_with_plan)
    strategy_label = (
        "snowball (smallest balance first)"
        if strategy == DebtStrategy.snowball
        else "avalanche (highest APR first)"
    )
    narrative = (
        f"Using the {strategy_label} method with "
        f"${float(monthly_extra):.2f}/mo extra, you could be debt-free by "
        f"{freedom.strftime('%B %Y')}, saving about ${float(saved):.0f} in interest "
        f"versus minimums only."
    )

    return {
        "freedom_date": freedom.isoformat(),
        "total_interest_saved": float(_money(saved)),
        "total_interest_with_minimums": float(_money(interest_mins)),
        "total_interest_with_plan": float(_money(interest_with_plan)),
        "months_to_freedom": month,
        "allocations": allocations,
        "narrative": narrative,
    }


def _interest_minimums_only(debts: list[_Debt]) -> Decimal:
    working = deepcopy(debts)
    interest_total = Decimal("0")
    month = 0
    while any(d.balance > 0 for d in working) and month < _MAX_MONTHS:
        month += 1
        for d in working:
            if d.balance <= 0:
                continue
            monthly_rate = d.apr / Decimal("100") / Decimal("12")
            interest = _money(d.balance * monthly_rate)
            d.balance = _money(d.balance + interest)
            interest_total += interest
            pay = min(d.minimum_payment, d.balance)
            d.balance = _money(d.balance - pay)
            if d.balance < 0:
                d.balance = Decimal("0")
    return interest_total


def _add_months(dt: datetime, months: int) -> datetime:
    year = dt.year + (dt.month - 1 + months) // 12
    month = (dt.month - 1 + months) % 12 + 1
    day = min(dt.day, 28)  # avoid month-end overflow
    return dt.replace(year=year, month=month, day=day)


def build_debt_plan_content(
    accounts: list[Account],
    strategy: DebtStrategy | Literal["snowball", "avalanche"],
    monthly_extra_payment: Decimal,
) -> dict:
    if isinstance(strategy, str):
        strategy = DebtStrategy(strategy)
    debts = accounts_to_debts(accounts)
    if not debts:
        raise ValueError("No credit card balances to include in a debt plan")
    return _simulate(debts, _money(monthly_extra_payment), strategy)
