"""
APScheduler background jobs.
Runs inside the FastAPI process when SCHEDULER_ENABLED=true (exactly one process).
Jobs: daily summary (respects time_of_day prefs), card reminders, monthly insights, Plaid sync.
"""
import logging
from datetime import datetime, timezone

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.db.session import AsyncSessionLocal
from app.models.models import (
    Account,
    AccountType,
    NotificationPreference,
    NotificationType,
    SubscriptionTier,
    User,
)
from app.services.notification_service import send_card_payment_reminder, send_daily_summary
from app.services.transaction_service import get_dashboard_summary

logger = logging.getLogger(__name__)
scheduler = AsyncIOScheduler(timezone="UTC")


async def _run_daily_summaries():
    """
    Send daily summaries. Respects each user's notification_preferences.time_of_day
    (HH:MM, UTC for v1 — locale TZ expansion is a later product decision).
    Runs every hour; only sends when current UTC hour matches the pref.
    """
    now = datetime.now(timezone.utc)
    current_hhmm = f"{now.hour:02d}:{now.minute:02d}"
    current_hour = f"{now.hour:02d}"

    logger.info("Running daily summary job at %s UTC", current_hhmm)
    async with AsyncSessionLocal() as db:
        try:
            result = await db.execute(
                select(User).where(User.firebase_token.is_not(None))
            )
            users = result.scalars().all()
            for user in users:
                try:
                    pref_result = await db.execute(
                        select(NotificationPreference).where(
                            NotificationPreference.user_id == user.id,
                            NotificationPreference.notification_type
                            == NotificationType.daily_summary,
                        )
                    )
                    pref = pref_result.scalar_one_or_none()
                    if pref and not pref.enabled:
                        continue
                    # Default 21:00 UTC when no pref
                    wanted = (pref.time_of_day if pref and pref.time_of_day else "21:00")[:5]
                    if wanted[:2] != current_hour:
                        continue
                    # Only fire once in the matching hour (at :00–:14 window)
                    if now.minute > 14:
                        continue
                    await send_daily_summary(db, user)
                except Exception as e:
                    logger.error("Daily summary failed for user %s: %s", user.id, e)
            await db.commit()
        except Exception as e:
            logger.error("Daily summary job error: %s", e)
            await db.rollback()


async def _run_card_payment_reminders():
    logger.info("Running card payment reminder job")
    now = datetime.now(timezone.utc)
    target_day = (now.day + 3) % 31 or 31

    async with AsyncSessionLocal() as db:
        try:
            result = await db.execute(
                select(Account)
                .options(selectinload(Account.user))
                .where(
                    Account.account_type == AccountType.credit_card,
                    Account.due_day == target_day,
                    Account.is_active == True,  # noqa: E712
                )
            )
            accounts = result.scalars().all()

            for account in accounts:
                user = account.user
                if not user or not user.firebase_token:
                    continue
                if account.outstanding_balance and account.outstanding_balance > 0:
                    due_date = f"{now.strftime('%B')} {target_day}"
                    await send_card_payment_reminder(
                        db=db,
                        user=user,
                        card_name=account.name,
                        amount_due=account.outstanding_balance,
                        due_date=due_date,
                    )
            await db.commit()
        except Exception as e:
            logger.error("Card reminder job error: %s", e)
            await db.rollback()


async def _run_monthly_insight_generation():
    logger.info("Running monthly insight pre-generation")
    now = datetime.now(timezone.utc)
    month = now.month - 1 if now.month > 1 else 12
    year = now.year if now.month > 1 else now.year - 1

    async with AsyncSessionLocal() as db:
        try:
            result = await db.execute(select(User))
            users = result.scalars().all()

            for user in users:
                if not user.has_feature("ai_insights"):
                    continue
                try:
                    from app.models.models import Insight, InsightPeriod
                    from sqlalchemy import and_

                    period_key = f"{year}-{month:02d}"
                    existing = await db.execute(
                        select(Insight).where(
                            and_(
                                Insight.user_id == user.id,
                                Insight.period_key == period_key,
                            )
                        )
                    )
                    if existing.scalar_one_or_none():
                        continue

                    summary = await get_dashboard_summary(db, user.id, year, month)
                    from app.services.ai_service import generate_monthly_insight

                    content = await generate_monthly_insight(
                        period_key=period_key,
                        total_income=summary.total_income,
                        total_spent=summary.total_spent,
                        total_saved=summary.total_saved,
                        budget_amount=summary.budget_amount,
                        needs_total=summary.needs_total,
                        wants_total=summary.wants_total,
                        spending_by_category=[
                            {
                                "name": c.category_name,
                                "total": c.total,
                                "pct": c.pct_of_total,
                                "is_need": c.is_need,
                            }
                            for c in summary.spending_by_category
                        ],
                    )
                    insight = Insight(
                        user_id=user.id,
                        period=InsightPeriod.month,
                        period_key=period_key,
                        content=content.model_dump(),
                    )
                    db.add(insight)
                except Exception as e:
                    logger.error("Insight generation failed for user %s: %s", user.id, e)

            await db.commit()
        except Exception as e:
            logger.error("Monthly insight job error: %s", e)
            await db.rollback()


async def _run_plaid_sync():
    logger.info("Running scheduled Plaid sync")
    async with AsyncSessionLocal() as db:
        try:
            result = await db.execute(
                select(Account).where(
                    Account.plaid_access_token.is_not(None),
                    Account.is_active == True,  # noqa: E712
                )
            )
            accounts = result.scalars().all()

            from app.services.plaid_service import sync_transactions

            for account in accounts:
                try:
                    await sync_transactions(db, account)
                except Exception as e:
                    logger.error("Plaid sync failed for account %s: %s", account.id, e)

            # Catch-up detect for users who only had older txs (no new adds this run)
            try:
                from app.services.recurring_service import detect_and_upsert_recurring

                user_ids = {str(a.user_id) for a in accounts}
                for uid in user_ids:
                    try:
                        await detect_and_upsert_recurring(db, uid)
                    except Exception as e:
                        logger.error("Recurring detect failed for user %s: %s", uid, e)
            except Exception as e:
                logger.error("Recurring detect batch error: %s", e)

            await db.commit()
        except Exception as e:
            logger.error("Plaid sync job error: %s", e)
            await db.rollback()


def setup_scheduler():
    # Hourly tick — daily summaries filter by user time_of_day
    scheduler.add_job(
        _run_daily_summaries,
        CronTrigger(minute=0),
        id="daily_summaries",
        replace_existing=True,
    )
    scheduler.add_job(
        _run_card_payment_reminders,
        CronTrigger(hour=9, minute=0),
        id="card_reminders",
        replace_existing=True,
    )
    scheduler.add_job(
        _run_monthly_insight_generation,
        CronTrigger(day=1, hour=2, minute=0),
        id="monthly_insights",
        replace_existing=True,
    )
    scheduler.add_job(
        _run_plaid_sync,
        CronTrigger(hour="*/6"),
        id="plaid_sync",
        replace_existing=True,
    )
    logger.info("Background scheduler configured")
