"""
Notification service.
Handles push notification delivery via Firebase Cloud Messaging.
"""
import logging
from datetime import datetime, timezone
from decimal import Decimal
from typing import Optional

from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.models.models import User, NotificationPreference, NotificationType, Budget, BudgetPeriod
from app.services.ai_service import generate_notification_copy
from app.services.transaction_service import get_dashboard_summary

logger = logging.getLogger(__name__)
settings = get_settings()

# Firebase admin SDK — initialized lazily
_firebase_initialized = False


def _init_firebase():
    global _firebase_initialized
    if _firebase_initialized:
        return
    try:
        import firebase_admin
        from firebase_admin import credentials
        cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_PATH)
        firebase_admin.initialize_app(cred)
        _firebase_initialized = True
    except Exception as e:
        logger.warning(f"Firebase init failed (notifications will be skipped): {e}")


async def _is_enabled(
    db: AsyncSession,
    user_id: str,
    notification_type: NotificationType,
) -> bool:
    result = await db.execute(
        select(NotificationPreference).where(
            and_(
                NotificationPreference.user_id == user_id,
                NotificationPreference.notification_type == notification_type,
            )
        )
    )
    pref = result.scalar_one_or_none()
    if pref is None:
        return True  # default enabled
    return pref.enabled


async def send_push(
    firebase_token: str,
    title: str,
    body: str,
    data: Optional[dict] = None,
) -> bool:
    """Send a single push notification via FCM."""
    _init_firebase()
    try:
        from firebase_admin import messaging
        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            data=data or {},
            token=firebase_token,
            android=messaging.AndroidConfig(priority="normal"),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(sound="default")
                )
            ),
        )
        messaging.send(message)
        return True
    except Exception as e:
        logger.error(f"Push notification failed: {e}")
        return False


# ─── Scheduled notification jobs ──────────────────────────────────────────

async def send_daily_summary(db: AsyncSession, user: User) -> None:
    """Send end-of-day spending summary to a user."""
    if not user.firebase_token:
        return
    if not await _is_enabled(db, user.id, NotificationType.daily_summary):
        return

    now = datetime.now(timezone.utc)
    summary = await get_dashboard_summary(db, user.id, now.year, now.month)

    # Fetch budget for notification copy
    budget_result = await db.execute(
        select(Budget).where(
            and_(
                Budget.user_id == user.id,
                Budget.category_id.is_(None),
                Budget.period == BudgetPeriod.monthly,
                Budget.is_active == True,
            )
        )
    )
    budget = budget_result.scalar_one_or_none()

    # Get top category
    top_cat = summary.spending_by_category[0] if summary.spending_by_category else None

    body = await generate_notification_copy(
        notification_type="daily_summary",
        total_spent=summary.total_spent,
        budget_amount=budget.amount if budget else None,
        days_remaining=summary.days_remaining,
        top_category=top_cat.category_name if top_cat else None,
        top_category_amount=top_cat.total if top_cat else None,
    )

    await send_push(
        firebase_token=user.firebase_token,
        title="Flowra daily summary",
        body=body,
        data={"type": "daily_summary", "screen": "dashboard"},
    )


async def send_budget_threshold_alert(
    db: AsyncSession,
    user: User,
    pct: int,
    total_spent: Decimal,
    budget_amount: Decimal,
    days_remaining: int,
) -> None:
    """Send a budget threshold alert (50%, 80%, or 100% exceeded)."""
    if not user.firebase_token:
        return

    notif_type_map = {
        80:  NotificationType.budget_80,
        100: NotificationType.budget_exceeded,
    }
    notif_type = notif_type_map.get(pct, NotificationType.budget_80)

    if not await _is_enabled(db, user.id, notif_type):
        return

    if pct >= 100:
        body = f"You've gone over your monthly budget. ${float(total_spent - budget_amount):.2f} over."
        title = "Budget exceeded"
    else:
        body = await generate_notification_copy(
            notification_type="budget_80",
            total_spent=total_spent,
            budget_amount=budget_amount,
            days_remaining=days_remaining,
        )
        title = f"Budget {pct}% used"

    await send_push(
        firebase_token=user.firebase_token,
        title=title,
        body=body,
        data={"type": notif_type.value, "screen": "budgets"},
    )


async def send_card_payment_reminder(
    db: AsyncSession,
    user: User,
    card_name: str,
    amount_due: Decimal,
    due_date: str,
) -> None:
    """Send credit card payment due reminder."""
    if not user.firebase_token:
        return
    if not await _is_enabled(db, user.id, NotificationType.card_payment_due):
        return

    body = f"{card_name} payment of ${amount_due:.2f} is due on {due_date}."
    await send_push(
        firebase_token=user.firebase_token,
        title="Card payment due soon",
        body=body,
        data={"type": "card_payment_due", "screen": "accounts"},
    )


async def send_milestone(
    db: AsyncSession,
    user: User,
    milestone_type: str,
    amount_saved: Optional[Decimal] = None,
) -> None:
    """Send a celebratory milestone notification."""
    if not user.firebase_token:
        return

    messages = {
        "first_under_budget": (
            "First month under budget!",
            f"You finished the month ${float(amount_saved):.2f} under your target. Keep it up.",
        ),
        "savings_streak": (
            "Savings streak!",
            "You've stayed under budget 3 months in a row. That's real progress.",
        ),
        "first_transaction": (
            "You're tracking!",
            "Your first transaction is logged. Flowra is on it.",
        ),
    }

    title, body = messages.get(milestone_type, ("Nice work!", "You're making progress with Flowra."))
    await send_push(
        firebase_token=user.firebase_token,
        title=title,
        body=body,
        data={"type": "milestone", "screen": "insights"},
    )