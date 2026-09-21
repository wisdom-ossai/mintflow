"""
Detect recurring merchant charges from transaction history.

Industry approach (Rocket Money / Monarch style):
  group expenses by normalized merchant → look for stable cadence + amount →
  upsert a RecurringSubscription and flag matching txs is_recurring.

Pure detection helpers are sync/unit-testable; DB upsert is async.
"""
from __future__ import annotations

import logging
import re
import statistics
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from typing import Iterable, Optional

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.models import (
    RecurringFrequency,
    RecurringStatus,
    RecurringSubscription,
    Transaction,
    TransactionType,
)

logger = logging.getLogger(__name__)

# Cadence windows (days between consecutive charges)
_CADENCE = {
    RecurringFrequency.weekly: (5, 10),
    RecurringFrequency.monthly: (25, 40),
    RecurringFrequency.yearly: (340, 390),
}
_LOOKBACK_DAYS = 400
_MIN_OCCURRENCES = 2
_AMOUNT_TOLERANCE = Decimal("0.15")  # ±15%
_AMOUNT_FLOOR = Decimal("1.50")     # or ±$1.50 absolute


@dataclass(frozen=True)
class DetectedSeries:
    merchant_key: str
    display_name: str
    typical_amount: Decimal
    frequency: RecurringFrequency
    occurrence_count: int
    last_charged_at: datetime
    next_expected_at: datetime
    transaction_ids: tuple[str, ...]


def normalize_merchant(name: str) -> str:
    """Collapse store numbers / legal suffixes so Netflix variants group together."""
    s = (name or "").lower().strip()
    s = re.sub(r"[^\w\s]", " ", s)
    s = re.sub(r"\b(inc|llc|ltd|co|corp|com|www)\b", " ", s)
    s = re.sub(r"\b\d{2,}\b", " ", s)  # store / ref numbers
    s = re.sub(r"\s+", " ", s).strip()
    return s[:255]


def _median_amount(amounts: list[Decimal]) -> Decimal:
    vals = sorted(amounts)
    n = len(vals)
    mid = n // 2
    if n % 2:
        return vals[mid]
    return (vals[mid - 1] + vals[mid]) / 2


def _amounts_consistent(amounts: list[Decimal], typical: Decimal) -> bool:
    if typical <= 0:
        return False
    for a in amounts:
        diff = abs(a - typical)
        if diff <= _AMOUNT_FLOOR:
            continue
        if typical == 0 or diff / typical > _AMOUNT_TOLERANCE:
            return False
    return True


def _classify_frequency(gaps: list[float]) -> Optional[RecurringFrequency]:
    if not gaps:
        return None
    med = statistics.median(gaps)
    for freq, (lo, hi) in _CADENCE.items():
        if lo <= med <= hi:
            return freq
    return None


def _interval_days(freq: RecurringFrequency) -> int:
    return {
        RecurringFrequency.weekly: 7,
        RecurringFrequency.monthly: 30,
        RecurringFrequency.yearly: 365,
    }[freq]


def detect_series_from_transactions(
    rows: Iterable[tuple[str, str, Decimal, datetime]],
) -> list[DetectedSeries]:
    """
    rows: (transaction_id, merchant_name, amount, date)
    Amounts should be absolute expense values (> 0).
    """
    by_key: dict[str, list[tuple[str, str, Decimal, datetime]]] = defaultdict(list)
    for tx_id, merchant, amount, dt in rows:
        key = normalize_merchant(merchant)
        if not key or amount <= 0:
            continue
        by_key[key].append((tx_id, merchant, amount, dt))

    detected: list[DetectedSeries] = []
    for key, items in by_key.items():
        if len(items) < _MIN_OCCURRENCES:
            continue
        items.sort(key=lambda r: r[3])
        amounts = [r[2] for r in items]
        typical = _median_amount(amounts)
        if not _amounts_consistent(amounts, typical):
            continue

        gaps = [
            (items[i][3] - items[i - 1][3]).total_seconds() / 86400.0
            for i in range(1, len(items))
        ]
        freq = _classify_frequency(gaps)
        if freq is None:
            continue

        # Prefer most common original casing/name (longest non-empty)
        display = max((r[1] for r in items), key=lambda n: len(n or ""))
        last_at = items[-1][3]
        if last_at.tzinfo is None:
            last_at = last_at.replace(tzinfo=timezone.utc)
        next_at = last_at + timedelta(days=_interval_days(freq))

        detected.append(
            DetectedSeries(
                merchant_key=key,
                display_name=display.strip() or key.title(),
                typical_amount=typical.quantize(Decimal("0.01")),
                frequency=freq,
                occurrence_count=len(items),
                last_charged_at=last_at,
                next_expected_at=next_at,
                transaction_ids=tuple(r[0] for r in items),
            )
        )
    return detected


async def detect_and_upsert_recurring(
    db: AsyncSession,
    user_id: str,
) -> dict:
    """
    Scan recent expenses for the user, upsert recurring_subscriptions,
    and mark matching transactions is_recurring=True.
    Safe to call after every Plaid sync (idempotent upsert).
    """
    since = datetime.now(timezone.utc) - timedelta(days=_LOOKBACK_DAYS)
    result = await db.execute(
        select(
            Transaction.id,
            Transaction.merchant_name,
            Transaction.amount,
            Transaction.date,
        ).where(
            Transaction.user_id == user_id,
            Transaction.transaction_type == TransactionType.expense,
            Transaction.is_credit_card_payment == False,  # noqa: E712
            Transaction.merchant_name.is_not(None),
            Transaction.date >= since,
        )
    )
    rows_raw = result.all()
    rows = [
        (str(r.id), r.merchant_name or "", abs(Decimal(str(r.amount))), r.date)
        for r in rows_raw
        if r.merchant_name
    ]

    series_list = detect_series_from_transactions(rows)
    created = 0
    updated = 0
    flagged_ids: list[str] = []

    for series in series_list:
        existing = await db.execute(
            select(RecurringSubscription).where(
                RecurringSubscription.user_id == user_id,
                RecurringSubscription.merchant_key == series.merchant_key,
            )
        )
        row = existing.scalar_one_or_none()
        if row is None:
            db.add(
                RecurringSubscription(
                    user_id=user_id,
                    merchant_key=series.merchant_key,
                    display_name=series.display_name,
                    typical_amount=series.typical_amount,
                    frequency=series.frequency,
                    status=RecurringStatus.active,
                    occurrence_count=series.occurrence_count,
                    last_charged_at=series.last_charged_at,
                    next_expected_at=series.next_expected_at,
                )
            )
            created += 1
        else:
            row.display_name = series.display_name
            row.typical_amount = series.typical_amount
            row.frequency = series.frequency
            row.occurrence_count = series.occurrence_count
            row.last_charged_at = series.last_charged_at
            row.next_expected_at = series.next_expected_at
            # Do not flip dismissed/cancelled back to active automatically.
            updated += 1

        flagged_ids.extend(series.transaction_ids)

    if flagged_ids:
        # Chunk updates to avoid huge IN clauses
        unique_ids = list(set(flagged_ids))
        for i in range(0, len(unique_ids), 500):
            chunk = unique_ids[i : i + 500]
            await db.execute(
                update(Transaction)
                .where(
                    Transaction.user_id == user_id,
                    Transaction.id.in_(chunk),
                )
                .values(is_recurring=True)
            )

    await db.flush()
    logger.info(
        "Recurring detect user=%s created=%s updated=%s flagged=%s",
        user_id,
        created,
        updated,
        len(set(flagged_ids)),
    )
    return {
        "created": created,
        "updated": updated,
        "detected": len(series_list),
        "flagged_transactions": len(set(flagged_ids)),
    }
