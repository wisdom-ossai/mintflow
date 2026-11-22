"""
Savings goals — named targets with contribution progress.
Seed: 1 active goal. Growth+ (`unlimited_goals`): unlimited.
"""
from __future__ import annotations

from decimal import Decimal
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import CurrentUser
from app.db.session import get_db
from app.models.models import GoalStatus, SavingsGoal
from app.schemas.schemas import GoalContribute, GoalCreate, GoalRead, GoalUpdate, OKResponse

router = APIRouter(prefix="/goals", tags=["goals"])

_SEED_GOAL_CAP = 1


async def _active_goal_count(db: AsyncSession, user_id: str) -> int:
    result = await db.execute(
        select(func.count())
        .select_from(SavingsGoal)
        .where(
            SavingsGoal.user_id == user_id,
            SavingsGoal.status != GoalStatus.paused,
        )
    )
    return int(result.scalar() or 0)


async def _get_user_goal(
    db: AsyncSession, user_id: str, goal_id: str
) -> SavingsGoal:
    result = await db.execute(
        select(SavingsGoal).where(
            SavingsGoal.id == goal_id,
            SavingsGoal.user_id == user_id,
        )
    )
    goal = result.scalar_one_or_none()
    if not goal:
        raise HTTPException(status_code=404, detail="Goal not found")
    return goal


def _maybe_complete(goal: SavingsGoal) -> None:
    if goal.current_amount >= goal.target_amount:
        goal.status = GoalStatus.completed
    elif goal.status == GoalStatus.completed:
        goal.status = GoalStatus.active


@router.get("", response_model=list[GoalRead], summary="List savings goals")
async def list_goals(
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    result = await db.execute(
        select(SavingsGoal)
        .where(SavingsGoal.user_id == current_user.id)
        .order_by(SavingsGoal.created_at.desc())
    )
    return [GoalRead.model_validate(g) for g in result.scalars().all()]


@router.post(
    "",
    response_model=GoalRead,
    status_code=201,
    summary="Create a savings goal",
)
async def create_goal(
    payload: GoalCreate,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    if not current_user.has_feature("unlimited_goals"):
        count = await _active_goal_count(db, str(current_user.id))
        if count >= _SEED_GOAL_CAP:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=(
                    f"Free plan allows {_SEED_GOAL_CAP} goal. "
                    "Upgrade to Growth for unlimited goals."
                ),
            )

    current = payload.current_amount or Decimal("0")
    goal = SavingsGoal(
        user_id=current_user.id,
        name=payload.name.strip(),
        target_amount=payload.target_amount,
        current_amount=current,
        target_date=payload.target_date,
        linked_account_id=payload.linked_account_id,
        icon=payload.icon,
        color=payload.color,
        status=GoalStatus.active,
    )
    _maybe_complete(goal)
    db.add(goal)
    await db.flush()
    await db.refresh(goal)
    return GoalRead.model_validate(goal)


@router.patch("/{goal_id}", response_model=GoalRead, summary="Update a goal")
async def update_goal(
    goal_id: str,
    payload: GoalUpdate,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    goal = await _get_user_goal(db, str(current_user.id), goal_id)
    data = payload.model_dump(exclude_unset=True)
    if "name" in data and data["name"] is not None:
        data["name"] = data["name"].strip()
    for key, value in data.items():
        setattr(goal, key, value)
    _maybe_complete(goal)
    await db.flush()
    await db.refresh(goal)
    return GoalRead.model_validate(goal)


@router.post(
    "/{goal_id}/contribute",
    response_model=GoalRead,
    summary="Add a contribution toward a goal",
)
async def contribute(
    goal_id: str,
    payload: GoalContribute,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    goal = await _get_user_goal(db, str(current_user.id), goal_id)
    goal.current_amount = (goal.current_amount or Decimal("0")) + payload.amount
    _maybe_complete(goal)
    await db.flush()
    await db.refresh(goal)
    return GoalRead.model_validate(goal)


@router.delete(
    "/{goal_id}",
    response_model=OKResponse,
    summary="Delete a savings goal",
)
async def delete_goal(
    goal_id: str,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    goal = await _get_user_goal(db, str(current_user.id), goal_id)
    await db.delete(goal)
    await db.flush()
    return OKResponse(message="Goal deleted")
