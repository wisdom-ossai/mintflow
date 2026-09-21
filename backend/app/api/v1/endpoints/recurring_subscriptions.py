"""
Recurring merchant subscriptions — auto-detected from Plaid transactions.
Gated by Growth+ feature `subscription_tracker`.
Distinct from RevenueCat `/subscriptions` (app billing).
"""
from __future__ import annotations

from decimal import Decimal
from typing import Annotated, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import require_feature
from app.db.session import get_db
from app.models.models import RecurringStatus, RecurringSubscription, User
from app.schemas.schemas import (
    OKResponse,
    RecurringDetectResponse,
    RecurringSubscriptionListResponse,
    RecurringSubscriptionRead,
    RecurringSubscriptionUpdate,
)
from app.services.recurring_service import detect_and_upsert_recurring

router = APIRouter(
    prefix="/recurring-subscriptions",
    tags=["recurring-subscriptions"],
)

_VALID_STATUS = {s.value for s in RecurringStatus}


def _monthly_equivalent(amount: Decimal, frequency: str) -> Decimal:
    if frequency == "weekly":
        return (amount * Decimal("52") / Decimal("12")).quantize(Decimal("0.01"))
    if frequency == "yearly":
        return (amount / Decimal("12")).quantize(Decimal("0.01"))
    return amount


@router.get(
    "",
    response_model=RecurringSubscriptionListResponse,
    summary="List detected recurring subscriptions",
)
async def list_recurring(
    current_user: Annotated[User, Depends(require_feature("subscription_tracker"))],
    db: Annotated[AsyncSession, Depends(get_db)],
    status: Optional[str] = Query(
        "active",
        description="Filter by status, or `all`",
    ),
):
    q = select(RecurringSubscription).where(
        RecurringSubscription.user_id == current_user.id
    )
    if status and status != "all":
        if status not in _VALID_STATUS:
            raise HTTPException(status_code=422, detail="Invalid status filter")
        q = q.where(RecurringSubscription.status == RecurringStatus(status))
    q = q.order_by(RecurringSubscription.typical_amount.desc())

    result = await db.execute(q)
    rows = result.scalars().all()

    monthly_total = Decimal("0.00")
    active_count = 0
    for r in rows:
        if r.status == RecurringStatus.active:
            active_count += 1
            monthly_total += _monthly_equivalent(
                Decimal(str(r.typical_amount)), r.frequency.value
            )

    return RecurringSubscriptionListResponse(
        items=[RecurringSubscriptionRead.model_validate(r) for r in rows],
        monthly_total=monthly_total.quantize(Decimal("0.01")),
        active_count=active_count,
    )


@router.post(
    "/detect",
    response_model=RecurringDetectResponse,
    summary="Re-run recurring detection on transaction history",
)
async def run_detect(
    current_user: Annotated[User, Depends(require_feature("subscription_tracker"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    stats = await detect_and_upsert_recurring(db, str(current_user.id))
    return RecurringDetectResponse(**stats)


@router.patch(
    "/{subscription_id}",
    response_model=RecurringSubscriptionRead,
    summary="Update recurring subscription (dismiss / cancel / rename)",
)
async def update_recurring(
    subscription_id: str,
    payload: RecurringSubscriptionUpdate,
    current_user: Annotated[User, Depends(require_feature("subscription_tracker"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    result = await db.execute(
        select(RecurringSubscription).where(
            RecurringSubscription.id == subscription_id,
            RecurringSubscription.user_id == current_user.id,
        )
    )
    row = result.scalar_one_or_none()
    if not row:
        raise HTTPException(status_code=404, detail="Subscription not found")

    if payload.status is not None:
        if payload.status not in _VALID_STATUS:
            raise HTTPException(status_code=422, detail="Invalid status")
        row.status = RecurringStatus(payload.status)
    if payload.display_name is not None:
        name = payload.display_name.strip()
        if not name:
            raise HTTPException(status_code=422, detail="display_name cannot be empty")
        row.display_name = name

    await db.flush()
    await db.refresh(row)
    return RecurringSubscriptionRead.model_validate(row)


@router.delete(
    "/{subscription_id}",
    response_model=OKResponse,
    summary="Dismiss a detected subscription",
)
async def dismiss_recurring(
    subscription_id: str,
    current_user: Annotated[User, Depends(require_feature("subscription_tracker"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    result = await db.execute(
        select(RecurringSubscription).where(
            RecurringSubscription.id == subscription_id,
            RecurringSubscription.user_id == current_user.id,
        )
    )
    row = result.scalar_one_or_none()
    if not row:
        raise HTTPException(status_code=404, detail="Subscription not found")
    row.status = RecurringStatus.dismissed
    await db.flush()
    return OKResponse(message="Subscription dismissed")
