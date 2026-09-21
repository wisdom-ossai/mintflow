"""
Manual bills — user-defined due-date obligations (rent, utilities, etc.).
Seed: up to 3 active bills. Growth+ (`unlimited_bills`): unlimited.
Distinct from Plaid-detected `/recurring-subscriptions`.
"""
from __future__ import annotations

import calendar
from datetime import datetime, timezone
from decimal import Decimal
from typing import Annotated, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import extract, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.auth import CurrentUser
from app.db.session import get_db
from app.models.models import Bill, BillPayment, BillPaymentStatus
from app.schemas.schemas import (
    BillCreate,
    BillPayRequest,
    BillPaymentRead,
    BillRead,
    BillUpdate,
    OKResponse,
)

router = APIRouter(prefix="/bills", tags=["bills"])

_SEED_BILL_CAP = 3


def due_date_for_month(year: int, month: int, due_day: int) -> datetime:
    """Clamp due_day to the last day of the month (e.g. 31 → 28/29 in Feb)."""
    last = calendar.monthrange(year, month)[1]
    day = min(max(due_day, 1), last)
    return datetime(year, month, day, tzinfo=timezone.utc)


async def _active_bill_count(db: AsyncSession, user_id: str) -> int:
    result = await db.execute(
        select(func.count())
        .select_from(Bill)
        .where(
            Bill.user_id == user_id,
            Bill.is_active == True,  # noqa: E712
        )
    )
    return int(result.scalar() or 0)


async def _get_user_bill(
    db: AsyncSession, user_id: str, bill_id: str
) -> Bill:
    result = await db.execute(
        select(Bill).where(Bill.id == bill_id, Bill.user_id == user_id)
    )
    bill = result.scalar_one_or_none()
    if not bill:
        raise HTTPException(status_code=404, detail="Bill not found")
    return bill


@router.get("", response_model=list[BillRead], summary="List active bills")
async def list_bills(
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
    include_inactive: bool = Query(False),
):
    q = select(Bill).where(Bill.user_id == current_user.id)
    if not include_inactive:
        q = q.where(Bill.is_active == True)  # noqa: E712
    q = q.order_by(Bill.due_day.asc(), Bill.name.asc())
    result = await db.execute(q)
    return [BillRead.model_validate(b) for b in result.scalars().all()]


@router.post(
    "",
    response_model=BillRead,
    status_code=201,
    summary="Create a bill",
)
async def create_bill(
    payload: BillCreate,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    if not current_user.has_feature("unlimited_bills"):
        count = await _active_bill_count(db, str(current_user.id))
        if count >= _SEED_BILL_CAP:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=(
                    f"Free plan allows {_SEED_BILL_CAP} bills. "
                    "Upgrade to Growth for unlimited."
                ),
            )

    bill = Bill(
        user_id=current_user.id,
        name=payload.name.strip(),
        amount=payload.amount,
        due_day=payload.due_day,
        category_id=payload.category_id,
        is_autopay=payload.is_autopay,
        is_active=True,
    )
    db.add(bill)
    await db.flush()
    await db.refresh(bill)
    return BillRead.model_validate(bill)


@router.patch("/{bill_id}", response_model=BillRead, summary="Update a bill")
async def update_bill(
    bill_id: str,
    payload: BillUpdate,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    bill = await _get_user_bill(db, str(current_user.id), bill_id)
    data = payload.model_dump(exclude_unset=True)
    if "name" in data and data["name"] is not None:
        data["name"] = data["name"].strip()
    for key, value in data.items():
        setattr(bill, key, value)
    await db.flush()
    await db.refresh(bill)
    return BillRead.model_validate(bill)


@router.delete("/{bill_id}", response_model=OKResponse, summary="Delete a bill")
async def delete_bill(
    bill_id: str,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    bill = await _get_user_bill(db, str(current_user.id), bill_id)
    await db.delete(bill)
    await db.flush()
    return OKResponse(message="Bill deleted")


@router.get(
    "/payments",
    response_model=list[BillPaymentRead],
    summary="List bill payments for a month",
)
async def list_payments(
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
    year: Optional[int] = Query(None),
    month: Optional[int] = Query(None, ge=1, le=12),
):
    now = datetime.now(timezone.utc)
    y = year or now.year
    m = month or now.month

    result = await db.execute(
        select(BillPayment)
        .options(selectinload(BillPayment.bill))
        .where(
            BillPayment.user_id == current_user.id,
            extract("year", BillPayment.due_date) == y,
            extract("month", BillPayment.due_date) == m,
        )
        .order_by(BillPayment.due_date.asc())
    )
    rows = result.scalars().all()
    out: list[BillPaymentRead] = []
    for p in rows:
        out.append(
            BillPaymentRead(
                id=str(p.id),
                bill_id=str(p.bill_id),
                user_id=str(p.user_id),
                amount_paid=p.amount_paid,
                due_date=p.due_date,
                paid_date=p.paid_date,
                status=p.status.value if hasattr(p.status, "value") else str(p.status),
                transaction_id=str(p.transaction_id) if p.transaction_id else None,
                bill=BillRead.model_validate(p.bill) if p.bill else None,
            )
        )
    return out


@router.post(
    "/{bill_id}/pay",
    response_model=BillPaymentRead,
    summary="Mark bill paid for the current (or paid_date) month",
)
async def mark_bill_paid(
    bill_id: str,
    payload: BillPayRequest,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    bill = await _get_user_bill(db, str(current_user.id), bill_id)
    if not bill.is_active:
        raise HTTPException(status_code=400, detail="Bill is inactive")

    paid_at = payload.paid_date or datetime.now(timezone.utc)
    if paid_at.tzinfo is None:
        paid_at = paid_at.replace(tzinfo=timezone.utc)

    due = due_date_for_month(paid_at.year, paid_at.month, bill.due_day)

    existing = await db.execute(
        select(BillPayment).where(
            BillPayment.bill_id == bill.id,
            BillPayment.due_date == due,
        )
    )
    payment = existing.scalar_one_or_none()
    amount = payload.amount_paid if payload.amount_paid is not None else bill.amount

    if payment is None:
        payment = BillPayment(
            bill_id=bill.id,
            user_id=current_user.id,
            amount_paid=amount,
            due_date=due,
            paid_date=paid_at,
            status=BillPaymentStatus.paid,
        )
        db.add(payment)
    else:
        payment.amount_paid = amount
        payment.paid_date = paid_at
        payment.status = BillPaymentStatus.paid

    await db.flush()
    await db.refresh(payment)

    return BillPaymentRead(
        id=str(payment.id),
        bill_id=str(payment.bill_id),
        user_id=str(payment.user_id),
        amount_paid=payment.amount_paid,
        due_date=payment.due_date,
        paid_date=payment.paid_date,
        status=BillPaymentStatus.paid.value,
        transaction_id=None,
        bill=BillRead.model_validate(bill),
    )
