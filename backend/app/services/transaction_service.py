"""
Transaction service — core business logic.
Handles creation, categorization, Plaid sync, and spending calculations.
"""
import logging
from datetime import datetime, timezone
from decimal import Decimal
from typing import Optional
from sqlalchemy import select, func, and_, extract
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.models import (
    Transaction, TransactionType, TransactionSource,
    Category, MerchantCache, Account, AccountType,
)
from app.schemas.schemas import (
    TransactionCreate, TransactionUpdate, TransactionFilters,
    TransactionListResponse, TransactionRead, DashboardSummary,
    SpendingByCategory,
)
from app.services.ai_service import categorize_transaction

logger = logging.getLogger(__name__)

# ─── Keyword-based CC payment detection ────────────────────────────────────
CC_PAYMENT_KEYWORDS = [
    "autopay", "payment - thank you", "online payment",
    "credit card payment", "card payment", "payment received",
    "mobile payment", "payment - web", "payment - mobile",
]


def _is_cc_payment(description: str, merchant: str) -> bool:
    """
    Heuristic to detect if a transaction is a credit card bill payment.
    These must be excluded from spend totals to prevent double-counting.
    """
    text = f"{description or ''} {merchant or ''}".lower()
    return any(kw in text for kw in CC_PAYMENT_KEYWORDS)


# ─── Merchant cache lookup ──────────────────────────────────────────────────

async def get_cached_category(
    db: AsyncSession,
    merchant_name: str,
) -> Optional[dict]:
    """Check global merchant cache before calling Claude."""
    result = await db.execute(
        select(MerchantCache).where(
            MerchantCache.merchant_name == merchant_name.lower().strip()
        )
    )
    cached = result.scalar_one_or_none()
    if cached:
        # Increment hit counter
        cached.hit_count += 1
        return {
            "category_name": cached.category_name,
            "is_need": cached.is_need,
            "confidence": float(cached.confidence),
        }
    return None


async def save_to_cache(
    db: AsyncSession,
    merchant_name: str,
    category_name: str,
    is_need: bool,
    confidence: float,
) -> None:
    """Persist new merchant categorization to global cache."""
    key = merchant_name.lower().strip()
    result = await db.execute(
        select(MerchantCache).where(MerchantCache.merchant_name == key)
    )
    existing = result.scalar_one_or_none()
    if existing:
        existing.category_name = category_name
        existing.is_need = is_need
        existing.confidence = confidence
    else:
        db.add(MerchantCache(
            merchant_name=key,
            category_name=category_name,
            is_need=is_need,
            confidence=confidence,
        ))


# ─── Category resolution ────────────────────────────────────────────────────

async def resolve_category(
    db: AsyncSession,
    user_id: str,
    category_name: str,
) -> Optional[Category]:
    """Find or create a category by name for this user."""
    # Check system categories first
    result = await db.execute(
        select(Category).where(
            and_(
                Category.name == category_name,
                Category.user_id.is_(None),
            )
        )
    )
    cat = result.scalar_one_or_none()
    if cat:
        return cat

    # Check user's custom categories
    result = await db.execute(
        select(Category).where(
            and_(
                Category.name == category_name,
                Category.user_id == user_id,
            )
        )
    )
    return result.scalar_one_or_none()


# ─── Auto-categorize a transaction ─────────────────────────────────────────

async def auto_categorize(
    db: AsyncSession,
    user_id: str,
    merchant_name: Optional[str],
    amount: Decimal,
    is_credit_card_payment: bool = False,
    allow_ai: bool = False,
) -> dict:
    """
    Categorize a transaction using:
    1. Short-circuit for CC payments
    2. Global merchant cache (no API cost) — always allowed
    3. Claude API on cache miss — Growth/Pro only (`allow_ai`)

    Returns: {"category": Category|None, "is_need": bool|None, "ai_categorized": bool, "ai_confidence": float|None}
    """
    if is_credit_card_payment:
        return {"category": None, "is_need": None, "ai_categorized": False, "ai_confidence": None}

    if not merchant_name:
        return {"category": None, "is_need": None, "ai_categorized": False, "ai_confidence": None}

    cached = await get_cached_category(db, merchant_name)
    if cached:
        category = await resolve_category(db, user_id, cached["category_name"])
        return {
            "category": category,
            "is_need": cached["is_need"],
            "ai_categorized": True,
            "ai_confidence": cached["confidence"],
        }

    if not allow_ai:
        return {"category": None, "is_need": None, "ai_categorized": False, "ai_confidence": None}

    result = await categorize_transaction(merchant_name, amount)

    if result["confidence"] >= 0.7:
        await save_to_cache(
            db,
            merchant_name,
            result["category"],
            result["is_need"],
            result["confidence"],
        )

    category = await resolve_category(db, user_id, result["category"])
    return {
        "category": category,
        "is_need": result["is_need"],
        "ai_categorized": True,
        "ai_confidence": result["confidence"],
    }


# ─── Create transaction ─────────────────────────────────────────────────────

async def create_transaction(
    db: AsyncSession,
    user_id: str,
    payload: TransactionCreate,
    source: TransactionSource = TransactionSource.manual,
    allow_ai: bool = False,
    plaid_transaction_id: Optional[str] = None,
) -> Transaction:
    """
    Create a new transaction with auto-categorization.
    Detects CC payments and marks them appropriately.
    Merchant cache hits are free; Claude runs only when `allow_ai` is True.
    """
    is_cc_payment = _is_cc_payment(
        payload.description or "",
        payload.merchant_name or "",
    )

    if payload.transaction_type in (TransactionType.income, TransactionType.transfer):
        is_cc_payment = False

    category_id = payload.category_id
    is_need = payload.is_need
    ai_categorized = False
    ai_confidence = None

    if not category_id and payload.transaction_type == TransactionType.expense:
        ai_result = await auto_categorize(
            db, user_id,
            payload.merchant_name,
            payload.amount,
            is_cc_payment,
            allow_ai=allow_ai,
        )
        if ai_result["category"]:
            category_id = ai_result["category"].id
        if is_need is None:
            is_need = ai_result["is_need"]
        ai_categorized = ai_result["ai_categorized"]
        ai_confidence = ai_result.get("ai_confidence")

    tx = Transaction(
        user_id=user_id,
        account_id=payload.account_id,
        category_id=category_id,
        amount=payload.amount,
        transaction_type=(
            TransactionType.credit_payment if is_cc_payment else payload.transaction_type
        ),
        is_need=is_need,
        description=payload.description,
        merchant_name=payload.merchant_name,
        date=payload.date,
        source=source,
        is_credit_card_payment=is_cc_payment,
        notes=payload.notes,
        ai_categorized=ai_categorized,
        ai_confidence=ai_confidence,
        plaid_transaction_id=plaid_transaction_id,
    )
    db.add(tx)
    await db.flush()
    return tx


# ─── List transactions ──────────────────────────────────────────────────────

async def list_transactions(
    db: AsyncSession,
    user_id: str,
    filters: TransactionFilters,
) -> TransactionListResponse:
    query = (
        select(Transaction)
        .options(selectinload(Transaction.category))
        .where(Transaction.user_id == user_id)
    )

    if filters.start_date:
        query = query.where(Transaction.date >= filters.start_date)
    if filters.end_date:
        query = query.where(Transaction.date <= filters.end_date)
    if filters.transaction_type:
        query = query.where(Transaction.transaction_type == filters.transaction_type)
    if filters.category_id:
        query = query.where(Transaction.category_id == filters.category_id)
    if filters.account_id:
        query = query.where(Transaction.account_id == filters.account_id)
    if filters.is_need is not None:
        query = query.where(Transaction.is_need == filters.is_need)
    if filters.search:
        term = f"%{filters.search}%"
        query = query.where(
            Transaction.merchant_name.ilike(term) |
            Transaction.description.ilike(term)
        )

    # Count total
    count_result = await db.execute(
        select(func.count()).select_from(query.subquery())
    )
    total = count_result.scalar_one()

    # Paginate
    offset = (filters.page - 1) * filters.page_size
    query = query.order_by(Transaction.date.desc()).offset(offset).limit(filters.page_size)
    result = await db.execute(query)
    transactions = result.scalars().all()

    return TransactionListResponse(
        transactions=[TransactionRead.model_validate(t) for t in transactions],
        total=total,
        page=filters.page,
        page_size=filters.page_size,
        total_pages=max(1, -(-total // filters.page_size)),
    )


# ─── Dashboard summary ──────────────────────────────────────────────────────

async def get_dashboard_summary(
    db: AsyncSession,
    user_id: str,
    year: int,
    month: int,
) -> DashboardSummary:
    """
    Compute the full dashboard summary for a given month.
    Excludes CC payments from spend totals.
    """
    from calendar import monthrange
    from datetime import date

    days_in_month = monthrange(year, month)[1]
    period_start = datetime(year, month, 1, tzinfo=timezone.utc)
    period_end = datetime(year, month, days_in_month, 23, 59, 59, tzinfo=timezone.utc)
    today = datetime.now(timezone.utc)
    days_elapsed = min((today - period_start).days + 1, days_in_month)
    days_remaining = max(days_in_month - days_elapsed, 0)
    period_key = f"{year}-{month:02d}"

    # Fetch all transactions for the month
    result = await db.execute(
        select(Transaction)
        .options(selectinload(Transaction.category))
        .where(
            and_(
                Transaction.user_id == user_id,
                Transaction.date >= period_start,
                Transaction.date <= period_end,
            )
        )
    )
    txs = result.scalars().all()

    total_income = Decimal("0")
    total_spent = Decimal("0")
    needs_total = Decimal("0")
    wants_total = Decimal("0")
    category_totals: dict[str, dict] = {}

    for tx in txs:
        if tx.transaction_type == TransactionType.income:
            total_income += tx.amount
        elif tx.counts_as_spend:
            total_spent += tx.amount
            if tx.is_need is True:
                needs_total += tx.amount
            elif tx.is_need is False:
                wants_total += tx.amount

            # Group by category
            cat_name = tx.category.name if tx.category else "Other"
            cat_id = str(tx.category_id) if tx.category_id else None
            cat_color = tx.category.color if tx.category else None
            if cat_name not in category_totals:
                category_totals[cat_name] = {
                    "category_id": cat_id,
                    "category_name": cat_name,
                    "category_color": cat_color,
                    "total": Decimal("0"),
                    "is_need": tx.is_need,
                    "transaction_count": 0,
                }
            category_totals[cat_name]["total"] += tx.amount
            category_totals[cat_name]["transaction_count"] += 1

    total_saved = total_income - total_spent
    savings_rate = float(total_saved / total_income * 100) if total_income > 0 else 0.0
    needs_pct = float(needs_total / total_spent * 100) if total_spent > 0 else 0.0
    wants_pct = float(wants_total / total_spent * 100) if total_spent > 0 else 0.0

    # Fetch overall budget
    from app.models.models import Budget, BudgetPeriod
    budget_result = await db.execute(
        select(Budget).where(
            and_(
                Budget.user_id == user_id,
                Budget.category_id.is_(None),
                Budget.period == BudgetPeriod.monthly,
                Budget.is_active == True,
            )
        )
    )
    budget = budget_result.scalar_one_or_none()
    budget_amount = budget.amount if budget else None
    budget_pct_used = float(total_spent / budget_amount * 100) if budget_amount else None
    budget_remaining = (budget_amount - total_spent) if budget_amount else None

    # Projected spend
    projected_spend = None
    if days_elapsed > 0 and days_in_month > 0:
        daily_rate = total_spent / days_elapsed
        projected_spend = daily_rate * days_in_month

    # Build spending by category list
    spending_by_category = [
        SpendingByCategory(
            category_id=v["category_id"],
            category_name=v["category_name"],
            category_color=v["category_color"],
            total=v["total"],
            pct_of_total=float(v["total"] / total_spent * 100) if total_spent > 0 else 0,
            is_need=v["is_need"],
            transaction_count=v["transaction_count"],
        )
        for v in sorted(category_totals.values(), key=lambda x: x["total"], reverse=True)
    ]

    return DashboardSummary(
        period_key=period_key,
        total_income=total_income,
        total_spent=total_spent,
        total_saved=total_saved,
        savings_rate_pct=savings_rate,
        needs_total=needs_total,
        wants_total=wants_total,
        needs_pct=needs_pct,
        wants_pct=wants_pct,
        budget_amount=budget_amount,
        budget_pct_used=budget_pct_used,
        budget_remaining=budget_remaining,
        days_in_period=days_in_month,
        days_elapsed=days_elapsed,
        days_remaining=days_remaining,
        projected_spend=projected_spend,
        spending_by_category=spending_by_category,
        top_insight=None,  # filled by insight service if available
    )