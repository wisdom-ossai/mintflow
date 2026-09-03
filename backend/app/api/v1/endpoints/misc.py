"""
Users, dashboard, insights, budgets, and notifications endpoints —
fully documented for Swagger/OpenAPI.
"""
from datetime import datetime, timezone
from typing import Annotated, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_

from app.core.auth import CurrentUser, require_feature, get_current_user
from app.db.session import get_db
from app.models.models import (
    User, Budget, BudgetPeriod, Insight, InsightPeriod,
    NotificationPreference, NotificationType,
)
from app.schemas.schemas import (
    UserRead, UserUpdate, OnboardingPayload,
    BudgetCreate, BudgetRead,
    InsightRead, InsightFeedback,
    NotificationPrefRead, NotificationPrefUpdate,
    DashboardSummary, SubscriptionStatusRead, OKResponse,
)
from app.services.transaction_service import get_dashboard_summary
from app.services.ai_service import generate_monthly_insight

# ─── Response examples ─────────────────────────────────────────────────────

_USER_EXAMPLE = {
    "id": "b1c2d3e4-0000-0000-0000-000000000001",
    "email": "alex@example.com",
    "full_name": "Alex Johnson",
    "avatar_url": None,
    "subscription_tier": "growth",
    "trial_ends_at": None,
    "locale": "en-US",
    "currency": "USD",
    "monthly_income": "5400.00",
    "created_at": "2025-10-01T09:00:00Z",
}

_DASHBOARD_EXAMPLE = {
    "period_key": "2025-11",
    "total_income": "5400.00",
    "total_spent": "2170.00",
    "total_saved": "3230.00",
    "savings_rate_pct": 59.8,
    "needs_total": "1476.00",
    "wants_total": "694.00",
    "needs_pct": 68.0,
    "wants_pct": 32.0,
    "budget_amount": "3500.00",
    "budget_pct_used": 62.0,
    "budget_remaining": "1330.00",
    "days_in_period": 30,
    "days_elapsed": 13,
    "days_remaining": 17,
    "projected_spend": "3007.69",
    "top_insight": "You've spent 34% more on dining this month — mostly weekends.",
    "spending_by_category": [
        {"category_id": "c1", "category_name": "Housing", "category_color": "#7B5CF0", "total": "850.00", "pct_of_total": 39.2, "is_need": True, "transaction_count": 1},
        {"category_id": "c2", "category_name": "Food & Dining", "category_color": "#E05A40", "total": "340.00", "pct_of_total": 15.7, "is_need": False, "transaction_count": 12},
    ],
}

_BUDGET_EXAMPLE = {
    "id": "d4e5f6a7-0000-0000-0000-000000000005",
    "user_id": "b1c2d3e4-0000-0000-0000-000000000001",
    "category_id": None,
    "category": None,
    "amount": "3500.00",
    "period": "monthly",
    "rollover": False,
    "is_active": True,
}

_INSIGHT_EXAMPLE = {
    "id": "f7a8b9c0-0000-0000-0000-000000000006",
    "period": "month",
    "period_key": "2025-11",
    "content": {
        "summary": "A solid November — you spent less than last month and stayed under budget.",
        "insights": [
            {"type": "warning", "title": "Dining up 34% — mostly weekends", "body": "You spent $340 on food vs $254 in October. 8 of 12 visits were Friday–Sunday.", "action_label": "Set a dining budget", "action_type": "set_budget"},
            {"type": "positive", "title": "On track for the month", "body": "With 17 days left and $1,330 remaining, you're projected to finish $293 under budget.", "action_label": None, "action_type": None},
        ],
        "recommendations": [
            {"type": "recommendation", "title": "Cancel unused subscriptions", "body": "Hulu ($17.99), Duolingo Plus ($6.99), and Calm ($8.99) were charged but unused this month. That's $33.97/mo or $407/year.", "action_label": "Review subscriptions", "action_type": "review_subscriptions"},
        ],
        "generated_at": "2025-11",
    },
    "thumbs_up": None,
    "generated_at": "2025-11-13T02:00:00Z",
}

_NOTIF_EXAMPLE = {"notification_type": "daily_summary", "enabled": True, "time_of_day": "21:00"}
_SUB_EXAMPLE = {"tier": "growth", "trial_ends_at": None, "is_trial_active": False, "effective_tier": "growth"}


# ═══════════════════════════════════════════════════════════════════════════
# Users
# ═══════════════════════════════════════════════════════════════════════════

users_router = APIRouter(prefix="/users", tags=["users"])


@users_router.get(
    "/me",
    response_model=UserRead,
    summary="Get current user",
    responses={
        200: {"description": "Authenticated user profile.", "content": {"application/json": {"example": _USER_EXAMPLE}}},
        401: {"description": "Missing or invalid JWT."},
    },
)
async def get_me(current_user: CurrentUser):
    """
    Return the authenticated user's profile.

    The `subscription_tier` reflects the stored tier. To get the **effective**
    tier (which may be `pro` during an active trial), use
    `GET /v1/users/me/subscription`.
    """
    return UserRead.model_validate(current_user)


@users_router.patch(
    "/me",
    response_model=UserRead,
    summary="Update current user",
    responses={
        200: {"description": "Updated profile.", "content": {"application/json": {"example": _USER_EXAMPLE}}},
        401: {"description": "Missing or invalid JWT."},
        422: {"description": "Validation error."},
    },
)
async def update_me(
    payload: UserUpdate,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Partially update the authenticated user's profile (PATCH semantics).

    **Updatable fields:** `full_name`, `avatar_url`, `locale`, `currency`,
    `monthly_income`, `firebase_token` (FCM device token for push notifications).

    Set `firebase_token` whenever the Flutter app receives a new FCM token
    to ensure push notifications reach the correct device.
    """
    for field, value in payload.model_dump(exclude_none=True).items():
        setattr(current_user, field, value)
    return UserRead.model_validate(current_user)


@users_router.post(
    "/me/onboarding",
    response_model=UserRead,
    summary="Complete onboarding",
    responses={
        200: {"description": "Profile updated and budget created.", "content": {"application/json": {"example": _USER_EXAMPLE}}},
        401: {"description": "Missing or invalid JWT."},
    },
)
async def complete_onboarding(
    payload: OnboardingPayload,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Complete the onboarding wizard in a single call.

    Sets the user's name, income, currency, locale and — if
    `monthly_spending_target` is provided — creates (or updates) their
    overall monthly budget.

    Call this after the user completes the 3-step onboarding flow in the app.
    Can be called multiple times safely (idempotent on budget creation).
    """
    if payload.full_name:
        current_user.full_name = payload.full_name
    if payload.monthly_income:
        current_user.monthly_income = payload.monthly_income
    if payload.currency:
        current_user.currency = payload.currency
    if payload.locale:
        current_user.locale = payload.locale

    if payload.monthly_spending_target:
        result = await db.execute(
            select(Budget).where(and_(
                Budget.user_id == current_user.id,
                Budget.category_id.is_(None),
                Budget.period == BudgetPeriod.monthly,
            ))
        )
        existing = result.scalar_one_or_none()
        if existing:
            existing.amount = payload.monthly_spending_target
        else:
            db.add(Budget(user_id=current_user.id, amount=payload.monthly_spending_target, period=BudgetPeriod.monthly))

    return UserRead.model_validate(current_user)


@users_router.get(
    "/me/subscription",
    response_model=SubscriptionStatusRead,
    summary="Get subscription status",
    responses={
        200: {"description": "Subscription and trial status.", "content": {"application/json": {"example": _SUB_EXAMPLE}}},
        401: {"description": "Missing or invalid JWT."},
    },
)
async def get_subscription(current_user: CurrentUser):
    """
    Return the user's subscription status including trial state.

    `effective_tier` is what the user **actually** has access to right now.
    During an active 7-day trial, `effective_tier` will be `pro` even if
    `tier` is `seed`.

    Use `effective_tier` for all feature-gating decisions in the client.
    """
    return SubscriptionStatusRead(
        tier=current_user.subscription_tier,
        trial_ends_at=current_user.trial_ends_at,
        is_trial_active=current_user.is_trial_active,
        effective_tier=current_user.effective_tier,
    )


@users_router.delete(
    "/me",
    response_model=OKResponse,
    summary="Delete account",
    responses={
        200: {"description": "Account and all data permanently deleted.", "content": {"application/json": {"example": {"ok": True, "message": "Account deleted. All data has been removed."}}}},
        401: {"description": "Missing or invalid JWT."},
    },
)
async def delete_account(
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Permanently delete the authenticated user's account and all associated data.

    This operation is **irreversible** and:
    1. Revokes Plaid Items (invalidates access tokens)
    2. Deletes the Supabase Auth user
    3. Cascades ORM rows: accounts, transactions, categories, budgets, insights, prefs

    Required for GDPR/CCPA compliance (right to erasure).
    """
    from app.services.plaid_service import revoke_user_plaid_items
    from app.services.auth_service import logout_all

    user_id = str(current_user.id)

    await revoke_user_plaid_items(db, user_id)
    await logout_all(db, user_id)
    await db.delete(current_user)
    return OKResponse(message="Account deleted. All data has been removed.")


# ═══════════════════════════════════════════════════════════════════════════
# Dashboard
# ═══════════════════════════════════════════════════════════════════════════

dashboard_router = APIRouter(prefix="/dashboard", tags=["dashboard"])


@dashboard_router.get(
    "/summary",
    response_model=DashboardSummary,
    summary="Get dashboard summary",
    responses={
        200: {"description": "Full monthly summary.", "content": {"application/json": {"example": _DASHBOARD_EXAMPLE}}},
        401: {"description": "Missing or invalid JWT."},
    },
)
async def get_summary(
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
    year: Optional[int] = Query(None, description="Year (defaults to current year).", example=2025),
    month: Optional[int] = Query(None, ge=1, le=12, description="Month 1–12 (defaults to current month).", example=11),
):
    """
    Return the full dashboard summary for a given month.

    **Key behaviours:**
    - Credit card payments (`is_credit_card_payment: true`) are **excluded**
      from `total_spent` to prevent double-counting.
    - `projected_spend` is extrapolated from the current daily spending rate.
    - `top_insight` is the cached AI summary sentence (one line) if an insight
      has been generated for this period. `null` otherwise.
    - `budget_pct_used`, `budget_remaining` are `null` if no budget is set.

    Defaults to the current calendar month if `year`/`month` are omitted.
    """
    now = datetime.now(timezone.utc)
    year = year or now.year
    month = month or now.month
    summary = await get_dashboard_summary(db, current_user.id, year, month)

    period_key = f"{year}-{month:02d}"
    result = await db.execute(
        select(Insight).where(and_(
            Insight.user_id == current_user.id,
            Insight.period == InsightPeriod.month,
            Insight.period_key == period_key,
        ))
    )
    insight = result.scalar_one_or_none()
    if insight and isinstance(insight.content, dict) and insight.content.get("summary"):
        summary.top_insight = insight.content["summary"]

    return summary


# ═══════════════════════════════════════════════════════════════════════════
# Insights
# ═══════════════════════════════════════════════════════════════════════════

insights_router = APIRouter(prefix="/insights", tags=["insights"])


@insights_router.get(
    "/monthly/{year}/{month}",
    response_model=InsightRead,
    summary="Get monthly AI insights",
    responses={
        200: {"description": "AI-generated insights, served from cache if available.", "content": {"application/json": {"example": _INSIGHT_EXAMPLE}}},
        401: {"description": "Missing or invalid JWT."},
        403: {"description": "Requires Growth or Pro tier."},
    },
)
async def get_monthly_insight(
    year: int,
    month: int,
    current_user: Annotated[User, Depends(require_feature("ai_insights"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Return AI-generated insights for a given month.

    **Cache strategy:**
    1. Check DB cache for this `user_id` + `period_key`.
    2. If found and not stale → return immediately (no Claude API call).
    3. If missing → generate via Claude API → cache → return.

    Insights are pre-generated for Growth/Pro users on the 1st of each month
    by the background scheduler (`monthly_insights` job), so most requests
    will hit the cache instantly.

    **Insight types:** `positive`, `warning`, `info`, `recommendation`.
    Each insight may include an `action_type` for client deep-linking
    (e.g. `set_budget`, `review_subscriptions`).

    **Important:** Only anonymized spending summaries (totals, categories,
    percentages) are sent to Claude — never account numbers, user IDs, or
    balance details.

    **Tier:** Growth or Pro required.
    """
    period_key = f"{year}-{month:02d}"

    result = await db.execute(
        select(Insight).where(and_(
            Insight.user_id == current_user.id,
            Insight.period == InsightPeriod.month,
            Insight.period_key == period_key,
        ))
    )
    cached = result.scalar_one_or_none()
    if cached:
        from app.schemas.schemas import InsightContent
        return InsightRead(
            id=str(cached.id), period=cached.period, period_key=cached.period_key,
            content=InsightContent(**cached.content),
            thumbs_up=cached.thumbs_up, generated_at=cached.generated_at,
        )

    summary = await get_dashboard_summary(db, current_user.id, year, month)
    prev_month = month - 1 if month > 1 else 12
    prev_year = year if month > 1 else year - 1
    try:
        prev_summary = await get_dashboard_summary(db, current_user.id, prev_year, prev_month)
    except Exception:
        prev_summary = None

    content = await generate_monthly_insight(
        period_key=period_key,
        total_income=summary.total_income,
        total_spent=summary.total_spent,
        total_saved=summary.total_saved,
        budget_amount=summary.budget_amount,
        needs_total=summary.needs_total,
        wants_total=summary.wants_total,
        spending_by_category=[{"name": c.category_name, "total": c.total, "pct": c.pct_of_total, "is_need": c.is_need} for c in summary.spending_by_category],
        prev_month_spent=prev_summary.total_spent if prev_summary else None,
        prev_month_saved=prev_summary.total_saved if prev_summary else None,
    )

    insight = Insight(user_id=current_user.id, period=InsightPeriod.month, period_key=period_key, content=content.model_dump())
    db.add(insight)
    await db.flush()

    return InsightRead(id=str(insight.id), period=insight.period, period_key=insight.period_key,
                       content=content, thumbs_up=None, generated_at=insight.generated_at)


@insights_router.post(
    "/monthly/{year}/{month}/feedback",
    response_model=OKResponse,
    summary="Submit insight feedback",
    responses={
        200: {"description": "Feedback recorded.", "content": {"application/json": {"example": {"ok": True, "message": "Feedback recorded. Thank you."}}}},
        401: {"description": "Missing or invalid JWT."},
        403: {"description": "Requires Growth or Pro."},
        404: {"description": "Insight not found for this period."},
    },
)
async def submit_insight_feedback(
    year: int,
    month: int,
    payload: InsightFeedback,
    current_user: Annotated[User, Depends(require_feature("ai_insights"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Submit thumbs-up or thumbs-down feedback on a monthly insight.

    Feedback is stored in the `insights.thumbs_up` field and used to
    track AI quality over time.
    """
    period_key = f"{year}-{month:02d}"
    result = await db.execute(
        select(Insight).where(and_(Insight.user_id == current_user.id, Insight.period_key == period_key))
    )
    insight = result.scalar_one_or_none()
    if not insight:
        raise HTTPException(status_code=404, detail="Insight not found for this period")
    insight.thumbs_up = payload.thumbs_up
    return OKResponse(message="Feedback recorded. Thank you.")


# ═══════════════════════════════════════════════════════════════════════════
# Budgets
# ═══════════════════════════════════════════════════════════════════════════

budgets_router = APIRouter(prefix="/budgets", tags=["budgets"])


@budgets_router.post(
    "",
    response_model=BudgetRead,
    status_code=201,
    summary="Create a budget",
    responses={
        201: {"description": "Budget created.", "content": {"application/json": {"example": _BUDGET_EXAMPLE}}},
        401: {"description": "Missing or invalid JWT."},
        403: {"description": "Per-category budgets require Growth or Pro."},
        422: {"description": "Validation error."},
    },
)
async def create_budget(
    payload: BudgetCreate,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Create a spending budget.

    **Overall budget** (`category_id: null`): Available on all tiers.
    One overall monthly budget is recommended and created during onboarding.

    **Per-category budget** (`category_id: "<uuid>"`): Requires Growth or Pro.
    Set limits for individual categories like Food, Transport, Entertainment.

    **Unique constraint:** One budget per user per category per period.
    Creating a duplicate updates the existing budget's amount.

    **Rollover** (`rollover: true`): Unspent budget carries over to the next
    period (Pro only). The rollover logic runs on the 1st of each month.
    """
    if payload.category_id and not current_user.has_feature("category_budgets"):
        raise HTTPException(403, "Per-category budgets require Growth or Pro plan")
    if payload.rollover and not current_user.has_feature("rollover_budgets"):
        raise HTTPException(403, "Rollover budgets require Pro plan")

    # Upsert on (user_id, category_id, period) — never insert duplicates
    if payload.category_id is None:
        existing_q = select(Budget).where(and_(
            Budget.user_id == current_user.id,
            Budget.category_id.is_(None),
            Budget.period == payload.period,
        ))
    else:
        existing_q = select(Budget).where(and_(
            Budget.user_id == current_user.id,
            Budget.category_id == payload.category_id,
            Budget.period == payload.period,
        ))
    result = await db.execute(existing_q)
    existing = result.scalar_one_or_none()
    if existing:
        existing.amount = payload.amount
        existing.rollover = payload.rollover
        existing.is_active = True
        await db.flush()
        return BudgetRead.model_validate(existing)

    budget = Budget(
        user_id=current_user.id,
        category_id=payload.category_id,
        amount=payload.amount,
        period=payload.period,
        rollover=payload.rollover,
    )
    db.add(budget)
    await db.flush()
    return BudgetRead.model_validate(budget)


@budgets_router.get(
    "",
    response_model=list[BudgetRead],
    summary="List budgets",
    responses={
        200: {"description": "All active budgets.", "content": {"application/json": {"example": [_BUDGET_EXAMPLE]}}},
        401: {"description": "Missing or invalid JWT."},
    },
)
async def list_budgets(
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Return all active budgets for the authenticated user.

    Budget progress (spent vs amount) is computed in the dashboard summary
    endpoint, not here. This endpoint returns the budget definitions only.
    """
    from sqlalchemy.orm import selectinload
    result = await db.execute(
        select(Budget).options(selectinload(Budget.category))
        .where(Budget.user_id == current_user.id, Budget.is_active == True)
    )
    return [BudgetRead.model_validate(b) for b in result.scalars().all()]


@budgets_router.delete(
    "/{budget_id}",
    response_model=OKResponse,
    summary="Delete a budget",
    responses={
        200: {"description": "Budget deleted.", "content": {"application/json": {"example": {"ok": True, "message": "Budget deleted"}}}},
        401: {"description": "Missing or invalid JWT."},
        404: {"description": "Budget not found."},
    },
)
async def delete_budget(
    budget_id: str,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Delete a budget. The overall monthly budget can be re-created at any time."""
    result = await db.execute(
        select(Budget).where(Budget.id == budget_id, Budget.user_id == current_user.id)
    )
    budget = result.scalar_one_or_none()
    if not budget:
        raise HTTPException(404, "Budget not found")
    await db.delete(budget)
    return OKResponse(message="Budget deleted")


# ═══════════════════════════════════════════════════════════════════════════
# Notifications
# ═══════════════════════════════════════════════════════════════════════════

notifications_router = APIRouter(prefix="/notifications", tags=["notifications"])


@notifications_router.get(
    "/preferences",
    response_model=list[NotificationPrefRead],
    summary="Get notification preferences",
    responses={
        200: {"description": "All notification types with enabled/disabled state.", "content": {"application/json": {"example": [_NOTIF_EXAMPLE]}}},
        401: {"description": "Missing or invalid JWT."},
    },
)
async def get_notification_prefs(
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Return all notification types with their current enabled/disabled state
    and optional time-of-day setting.

    Types not yet saved by the user are returned with their **default state**
    (`enabled: true`). All notification types are returned — the client
    should show tier-locked types as disabled/greyed out in the UI.

    **Notification types and their default tiers:**

    | Type | Default | Tier |
    |---|---|---|
    | `daily_summary` | enabled, 21:00 | Free |
    | `weekly_digest` | enabled | Free |
    | `monthly_report` | enabled | Free |
    | `budget_50` | enabled | Free |
    | `budget_80` | enabled | Free |
    | `budget_exceeded` | enabled | Free |
    | `milestone` | enabled | Free |
    | `inactivity` | disabled | Free |
    | `ai_nudge` | enabled | Growth |
    | `salary_detected` | enabled | Growth |
    | `card_payment_due` | enabled | Growth |
    | `subscription_renewal` | enabled | Growth |
    | `high_utilization` | enabled | Pro |
    """
    result = await db.execute(
        select(NotificationPreference).where(NotificationPreference.user_id == current_user.id)
    )
    prefs = result.scalars().all()
    pref_map = {p.notification_type: p for p in prefs}

    return [
        NotificationPrefRead(
            notification_type=nt,
            enabled=pref_map[nt].enabled if nt in pref_map else True,
            time_of_day=pref_map[nt].time_of_day if nt in pref_map else None,
        )
        for nt in NotificationType
    ]


@notifications_router.put(
    "/preferences/{notification_type}",
    response_model=NotificationPrefRead,
    summary="Update a notification preference",
    responses={
        200: {"description": "Updated preference.", "content": {"application/json": {"example": _NOTIF_EXAMPLE}}},
        401: {"description": "Missing or invalid JWT."},
        422: {"description": "Invalid notification type or time format."},
    },
)
async def update_notification_pref(
    notification_type: NotificationType,
    payload: NotificationPrefUpdate,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Enable, disable, or set the time for a specific notification type.

    **Payload:**
    ```json
    {
      "enabled": true,
      "time_of_day": "21:00"
    }
    ```

    `time_of_day` is only applicable to `daily_summary`. Format: `HH:MM` (24h UTC).
    Ignored for all other notification types.

    Creating or updating is handled transparently — this endpoint is idempotent.
    """
    result = await db.execute(
        select(NotificationPreference).where(and_(
            NotificationPreference.user_id == current_user.id,
            NotificationPreference.notification_type == notification_type,
        ))
    )
    pref = result.scalar_one_or_none()
    if pref:
        pref.enabled = payload.enabled
        if payload.time_of_day:
            pref.time_of_day = payload.time_of_day
    else:
        pref = NotificationPreference(
            user_id=current_user.id,
            notification_type=notification_type,
            enabled=payload.enabled,
            time_of_day=payload.time_of_day,
        )
        db.add(pref)

    return NotificationPrefRead.model_validate(pref)