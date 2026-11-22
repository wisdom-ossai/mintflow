"""
Pro debt payoff plans — snowball / avalanche simulation over credit card balances.
"""
from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import require_feature
from app.db.session import get_db
from app.models.models import Account, AccountType, DebtPlan, User
from app.schemas.schemas import DebtPlanCreate, DebtPlanRead
from app.services.debt_service import build_debt_plan_content

router = APIRouter(prefix="/debt", tags=["debt"])


@router.get(
    "/plan",
    response_model=DebtPlanRead,
    summary="Get the latest debt payoff plan",
)
async def get_debt_plan(
    current_user: Annotated[User, Depends(require_feature("debt_payoff_plan"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    result = await db.execute(
        select(DebtPlan)
        .where(DebtPlan.user_id == current_user.id)
        .order_by(DebtPlan.generated_at.desc())
        .limit(1)
    )
    plan = result.scalar_one_or_none()
    if not plan:
        raise HTTPException(status_code=404, detail="No debt plan generated yet")
    return DebtPlanRead.model_validate(plan)


@router.post(
    "/plan",
    response_model=DebtPlanRead,
    status_code=201,
    summary="Generate a debt payoff plan",
)
async def generate_debt_plan(
    payload: DebtPlanCreate,
    current_user: Annotated[User, Depends(require_feature("debt_payoff_plan"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    result = await db.execute(
        select(Account).where(
            Account.user_id == current_user.id,
            Account.account_type == AccountType.credit_card,
            Account.is_active == True,  # noqa: E712
        )
    )
    accounts = list(result.scalars().all())
    try:
        content = build_debt_plan_content(
            accounts,
            payload.strategy,
            payload.monthly_extra_payment,
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        ) from e

    plan = DebtPlan(
        user_id=current_user.id,
        strategy=payload.strategy,
        monthly_extra_payment=payload.monthly_extra_payment,
        content=content,
    )
    db.add(plan)
    await db.flush()
    await db.refresh(plan)
    return DebtPlanRead.model_validate(plan)
