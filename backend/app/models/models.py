"""
SQLAlchemy ORM models for Mintflow.
UUID primary keys; API is the only DB client (no Supabase RLS).
"""
import uuid
from datetime import datetime
from decimal import Decimal
from enum import Enum as PyEnum

from sqlalchemy import (
    Boolean, Column, DateTime, Enum, ForeignKey,
    Integer, Numeric, String, Text, JSON, Index,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import DeclarativeBase, relationship
from sqlalchemy.sql import func


class Base(DeclarativeBase):
    pass


def gen_uuid():
    return str(uuid.uuid4())


# ─── Enums ─────────────────────────────────────────────────────────────────

class SubscriptionTier(str, PyEnum):
    seed   = "seed"
    growth = "growth"
    pro    = "pro"


class AccountType(str, PyEnum):
    bank        = "bank"
    credit_card = "credit_card"
    cash        = "cash"
    wallet      = "wallet"


class TransactionType(str, PyEnum):
    income          = "income"
    expense         = "expense"
    credit_payment  = "credit_payment"   # CC bill payment — excluded from spend totals
    transfer        = "transfer"


class TransactionSource(str, PyEnum):
    plaid  = "plaid"
    manual = "manual"
    ocr    = "ocr"


class BudgetPeriod(str, PyEnum):
    monthly = "monthly"
    annual  = "annual"


class InsightPeriod(str, PyEnum):
    month = "month"
    year  = "year"


class NotificationType(str, PyEnum):
    daily_summary        = "daily_summary"
    budget_50            = "budget_50"
    budget_80            = "budget_80"
    budget_exceeded      = "budget_exceeded"
    weekly_digest        = "weekly_digest"
    monthly_report       = "monthly_report"
    milestone            = "milestone"
    inactivity           = "inactivity"
    ai_nudge             = "ai_nudge"
    salary_detected      = "salary_detected"
    card_payment_due     = "card_payment_due"
    subscription_renewal = "subscription_renewal"
    high_utilization     = "high_utilization"


class RecurringFrequency(str, PyEnum):
    weekly  = "weekly"
    monthly = "monthly"
    yearly  = "yearly"


class RecurringStatus(str, PyEnum):
    active     = "active"
    dismissed  = "dismissed"
    cancelled  = "cancelled"


class BillPaymentStatus(str, PyEnum):
    unpaid  = "unpaid"
    paid    = "paid"
    overdue = "overdue"


# ─── Users ─────────────────────────────────────────────────────────────────

class User(Base):
    __tablename__ = "users"

    id               = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    email            = Column(String(255), unique=True, nullable=False, index=True)
    password_hash    = Column(Text, nullable=True)  # null for social-only accounts
    google_sub       = Column(String(255), unique=True, nullable=True, index=True)
    apple_sub        = Column(String(255), unique=True, nullable=True, index=True)
    email_verified_at = Column(DateTime(timezone=True), nullable=True)
    full_name        = Column(String(255), nullable=True)
    avatar_url       = Column(String(512), nullable=True)
    subscription_tier = Column(Enum(SubscriptionTier), default=SubscriptionTier.seed, nullable=False)
    trial_ends_at    = Column(DateTime(timezone=True), nullable=True)
    locale           = Column(String(10), default="en-US")
    currency         = Column(String(3), default="USD")
    monthly_income   = Column(Numeric(12, 2), nullable=True)
    firebase_token   = Column(String(512), nullable=True)  # FCM device token
    created_at       = Column(DateTime(timezone=True), server_default=func.now())
    updated_at       = Column(DateTime(timezone=True), onupdate=func.now())

    # Relationships
    accounts          = relationship("Account", back_populates="user", cascade="all, delete-orphan")
    transactions      = relationship("Transaction", back_populates="user", cascade="all, delete-orphan")
    categories        = relationship("Category", back_populates="user", cascade="all, delete-orphan")
    budgets           = relationship("Budget", back_populates="user", cascade="all, delete-orphan")
    insights          = relationship("Insight", back_populates="user", cascade="all, delete-orphan")
    notification_prefs = relationship("NotificationPreference", back_populates="user", cascade="all, delete-orphan")
    auth_sessions     = relationship("AuthSession", back_populates="user", cascade="all, delete-orphan")
    password_reset_tokens = relationship(
        "PasswordResetToken", back_populates="user", cascade="all, delete-orphan"
    )
    recurring_subscriptions = relationship(
        "RecurringSubscription", back_populates="user", cascade="all, delete-orphan"
    )
    bills = relationship("Bill", back_populates="user", cascade="all, delete-orphan")
    bill_payments = relationship(
        "BillPayment", back_populates="user", cascade="all, delete-orphan"
    )

    @property
    def is_trial_active(self) -> bool:
        if self.trial_ends_at is None:
            return False
        return datetime.utcnow() < self.trial_ends_at.replace(tzinfo=None)

    @property
    def effective_tier(self) -> SubscriptionTier:
        """During trial, treat as Pro regardless of stored tier."""
        if self.is_trial_active:
            return SubscriptionTier.pro
        return self.subscription_tier

    def has_feature(self, feature: str) -> bool:
        """
        Server source of truth for entitlements. Keep in sync with
        Flutter `UserModel.hasFeature` — client must never unlock more.
        """
        tier = self.effective_tier
        growth_pro = [SubscriptionTier.growth, SubscriptionTier.pro]
        pro_only = [SubscriptionTier.pro]
        feature_map = {
            # Growth+
            "bank_sync":            growth_pro,
            "ai_categorization":    growth_pro,
            "ai_insights":          growth_pro,
            "needs_wants":          growth_pro,
            "spending_trends":      growth_pro,
            "annual_summary":       growth_pro,
            "smart_nudges":         growth_pro,
            "subscription_tracker": growth_pro,
            "shareable_card":       growth_pro,
            "credit_tracking":      growth_pro,
            "unlimited_goals":      growth_pro,
            "unlimited_bills":      growth_pro,
            "income_breakdown":     growth_pro,
            "category_budgets":     growth_pro,
            # Pro
            "unlimited_accounts":   pro_only,
            "credit_utilization":   pro_only,
            "ai_recommendations":   pro_only,
            "receipt_ocr":          pro_only,
            "custom_categories":    pro_only,
            "csv_export":           pro_only,
            "rollover_budgets":     pro_only,
            "debt_payoff_plan":     pro_only,
        }
        return tier in feature_map.get(feature, [])


# ─── Accounts ──────────────────────────────────────────────────────────────

class Account(Base):
    __tablename__ = "accounts"

    id                = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    user_id           = Column(UUID(as_uuid=False), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    plaid_account_id  = Column(String(255), unique=True, nullable=True)  # null for manual
    plaid_item_id     = Column(String(255), nullable=True)
    plaid_access_token = Column(Text, nullable=True)  # Fernet-encrypted at rest (enc:v1:)
    plaid_sync_cursor = Column(Text, nullable=True)   # /transactions/sync cursor per account
    name              = Column(String(255), nullable=False)
    institution_name  = Column(String(255), nullable=True)
    account_type      = Column(Enum(AccountType), nullable=False, default=AccountType.bank)
    currency          = Column(String(3), default="USD")
    balance           = Column(Numeric(14, 2), nullable=True)
    # Credit card specific
    credit_limit      = Column(Numeric(14, 2), nullable=True)
    outstanding_balance = Column(Numeric(14, 2), nullable=True)
    statement_day     = Column(Integer, nullable=True)  # day of month
    due_day           = Column(Integer, nullable=True)   # day of month
    is_active         = Column(Boolean, default=True)
    last_synced_at    = Column(DateTime(timezone=True), nullable=True)
    created_at        = Column(DateTime(timezone=True), server_default=func.now())

    user         = relationship("User", back_populates="accounts")
    transactions = relationship("Transaction", back_populates="account", cascade="all, delete-orphan")

    @property
    def available_credit(self) -> Decimal | None:
        if self.credit_limit is not None and self.outstanding_balance is not None:
            return self.credit_limit - self.outstanding_balance
        return None

    @property
    def credit_utilization_pct(self) -> float | None:
        if self.credit_limit and self.outstanding_balance and self.credit_limit > 0:
            return float(self.outstanding_balance / self.credit_limit * 100)
        return None


# ─── Categories ────────────────────────────────────────────────────────────

class Category(Base):
    __tablename__ = "categories"

    id         = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    user_id    = Column(UUID(as_uuid=False), ForeignKey("users.id", ondelete="CASCADE"), nullable=True, index=True)  # null = system default
    name       = Column(String(100), nullable=False)
    icon       = Column(String(50), nullable=True)
    color      = Column(String(7), nullable=True)   # hex color
    is_custom  = Column(Boolean, default=False)
    is_active  = Column(Boolean, default=True)
    sort_order = Column(Integer, default=0)

    user         = relationship("User", back_populates="categories")
    transactions = relationship("Transaction", back_populates="category")
    budgets      = relationship("Budget", back_populates="category")

    __table_args__ = (
        UniqueConstraint("user_id", "name", name="uq_category_user_name"),
    )


# ─── Merchant category cache ───────────────────────────────────────────────

class MerchantCache(Base):
    """
    Global (not per-user) cache of merchant → category mappings.
    Reduces Claude API calls by 60–70% at scale.
    """
    __tablename__ = "merchant_cache"

    id             = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    merchant_name  = Column(String(255), nullable=False, unique=True, index=True)
    category_name  = Column(String(100), nullable=False)
    is_need        = Column(Boolean, nullable=False)
    confidence     = Column(Numeric(3, 2), default=1.0)
    hit_count      = Column(Integer, default=1)
    created_at     = Column(DateTime(timezone=True), server_default=func.now())
    updated_at     = Column(DateTime(timezone=True), onupdate=func.now())


# ─── Transactions ──────────────────────────────────────────────────────────

class Transaction(Base):
    __tablename__ = "transactions"

    id                     = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    user_id                = Column(UUID(as_uuid=False), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    account_id             = Column(UUID(as_uuid=False), ForeignKey("accounts.id", ondelete="SET NULL"), nullable=True, index=True)
    category_id            = Column(UUID(as_uuid=False), ForeignKey("categories.id", ondelete="SET NULL"), nullable=True)
    plaid_transaction_id   = Column(String(255), unique=True, nullable=True)  # null for manual
    amount                 = Column(Numeric(12, 2), nullable=False)
    transaction_type       = Column(Enum(TransactionType), nullable=False, default=TransactionType.expense)
    is_need                = Column(Boolean, nullable=True)   # null = uncategorized
    description            = Column(String(500), nullable=True)
    merchant_name          = Column(String(255), nullable=True, index=True)
    date                   = Column(DateTime(timezone=True), nullable=False, index=True)
    source                 = Column(Enum(TransactionSource), default=TransactionSource.manual)
    is_credit_card_payment = Column(Boolean, default=False)  # CC bill payment — excluded from totals
    is_recurring           = Column(Boolean, default=False)
    notes                  = Column(Text, nullable=True)
    receipt_url            = Column(String(512), nullable=True)
    ai_categorized         = Column(Boolean, default=False)
    ai_confidence          = Column(Numeric(3, 2), nullable=True)
    created_at             = Column(DateTime(timezone=True), server_default=func.now())
    updated_at             = Column(DateTime(timezone=True), onupdate=func.now())

    user     = relationship("User", back_populates="transactions")
    account  = relationship("Account", back_populates="transactions")
    category = relationship("Category", back_populates="transactions")

    __table_args__ = (
        Index("ix_transactions_user_date", "user_id", "date"),
        Index("ix_transactions_user_type", "user_id", "transaction_type"),
    )

    @property
    def counts_as_spend(self) -> bool:
        """
        Returns True if this transaction should be included in spending totals.
        Credit card payments are excluded to prevent double-counting.
        """
        return (
            self.transaction_type == TransactionType.expense
            and not self.is_credit_card_payment
        )


# ─── Budgets ───────────────────────────────────────────────────────────────

class Budget(Base):
    __tablename__ = "budgets"

    id          = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    user_id     = Column(UUID(as_uuid=False), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    category_id = Column(UUID(as_uuid=False), ForeignKey("categories.id", ondelete="CASCADE"), nullable=True)  # null = overall
    amount      = Column(Numeric(12, 2), nullable=False)
    period      = Column(Enum(BudgetPeriod), default=BudgetPeriod.monthly)
    rollover    = Column(Boolean, default=False)
    is_active   = Column(Boolean, default=True)
    created_at  = Column(DateTime(timezone=True), server_default=func.now())
    updated_at  = Column(DateTime(timezone=True), onupdate=func.now())

    user     = relationship("User", back_populates="budgets")
    category = relationship("Category", back_populates="budgets")

    __table_args__ = (
        UniqueConstraint("user_id", "category_id", "period", name="uq_budget_user_category_period"),
    )


# ─── Insights ──────────────────────────────────────────────────────────────

class Insight(Base):
    """
    Cached AI-generated insights. Generated once per period, served from cache.
    Never regenerated on every screen open — only when stale.
    """
    __tablename__ = "insights"

    id           = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    user_id      = Column(UUID(as_uuid=False), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    period       = Column(Enum(InsightPeriod), nullable=False)
    period_key   = Column(String(7), nullable=False)   # "2025-11" or "2025"
    content      = Column(JSON, nullable=False)          # structured insight JSON
    thumbs_up    = Column(Boolean, nullable=True)
    generated_at = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="insights")

    __table_args__ = (
        UniqueConstraint("user_id", "period", "period_key", name="uq_insight_user_period"),
    )


# ─── Notification Preferences ──────────────────────────────────────────────

class NotificationPreference(Base):
    __tablename__ = "notification_preferences"

    id              = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    user_id         = Column(UUID(as_uuid=False), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    notification_type = Column(Enum(NotificationType), nullable=False)
    enabled         = Column(Boolean, default=True)
    time_of_day     = Column(String(5), nullable=True)  # "21:00" HH:MM
    updated_at      = Column(DateTime(timezone=True), onupdate=func.now())

    user = relationship("User", back_populates="notification_prefs")

    __table_args__ = (
        UniqueConstraint("user_id", "notification_type", name="uq_notif_user_type"),
    )

# ─── Auth sessions (refresh tokens) ────────────────────────────────────────

class AuthSession(Base):
    """
    Refresh-token rotation family. Raw tokens are never stored — only SHA-256 hashes.
    Reuse of a rotated token revokes the entire family.
    """
    __tablename__ = "auth_sessions"

    id            = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    user_id       = Column(UUID(as_uuid=False), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    family_id     = Column(UUID(as_uuid=False), nullable=False, index=True, default=gen_uuid)
    token_hash    = Column(String(64), nullable=False, unique=True)
    expires_at    = Column(DateTime(timezone=True), nullable=False)
    revoked_at    = Column(DateTime(timezone=True), nullable=True)
    replaced_by   = Column(UUID(as_uuid=False), nullable=True)
    user_agent    = Column(String(512), nullable=True)
    ip_address    = Column(String(64), nullable=True)
    created_at    = Column(DateTime(timezone=True), server_default=func.now())
    last_used_at  = Column(DateTime(timezone=True), nullable=True)

    user = relationship("User", back_populates="auth_sessions")


class PasswordResetToken(Base):
    __tablename__ = "password_reset_tokens"

    id         = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    user_id    = Column(UUID(as_uuid=False), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    token_hash = Column(String(64), nullable=False, unique=True)
    expires_at = Column(DateTime(timezone=True), nullable=False)
    used_at    = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="password_reset_tokens")


# ─── Recurring subscriptions (detected from bank txs) ──────────────────────

class RecurringSubscription(Base):
    """
    Auto-detected (or user-confirmed) recurring merchant charges.
    Distinct from RevenueCat app billing — this tracks Netflix/Spotify/etc.
    """
    __tablename__ = "recurring_subscriptions"

    id                = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    user_id           = Column(UUID(as_uuid=False), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    merchant_key      = Column(String(255), nullable=False)  # normalized for grouping
    display_name      = Column(String(255), nullable=False)
    typical_amount    = Column(Numeric(12, 2), nullable=False)
    currency          = Column(String(3), default="USD")
    frequency         = Column(Enum(RecurringFrequency), nullable=False, default=RecurringFrequency.monthly)
    status            = Column(Enum(RecurringStatus), nullable=False, default=RecurringStatus.active)
    occurrence_count  = Column(Integer, default=0)
    last_charged_at   = Column(DateTime(timezone=True), nullable=True)
    next_expected_at  = Column(DateTime(timezone=True), nullable=True)
    created_at        = Column(DateTime(timezone=True), server_default=func.now())
    updated_at        = Column(DateTime(timezone=True), onupdate=func.now())

    user = relationship("User", back_populates="recurring_subscriptions")

    __table_args__ = (
        UniqueConstraint("user_id", "merchant_key", name="uq_recurring_user_merchant"),
        Index("ix_recurring_user_status", "user_id", "status"),
    )


# ─── Bills (manual due-date obligations) ───────────────────────────────────

class Bill(Base):
    """
    User-managed recurring obligation with a day-of-month due date
    (rent, utilities, insurance). Distinct from Plaid-detected subscriptions.
    """
    __tablename__ = "bills"

    id           = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    user_id      = Column(UUID(as_uuid=False), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    name         = Column(String(255), nullable=False)
    amount       = Column(Numeric(12, 2), nullable=True)
    due_day      = Column(Integer, nullable=False)  # 1–31
    category_id  = Column(UUID(as_uuid=False), ForeignKey("categories.id", ondelete="SET NULL"), nullable=True)
    is_autopay   = Column(Boolean, default=False)
    is_active    = Column(Boolean, default=True)
    created_at   = Column(DateTime(timezone=True), server_default=func.now())
    updated_at   = Column(DateTime(timezone=True), onupdate=func.now())

    user     = relationship("User", back_populates="bills")
    payments = relationship("BillPayment", back_populates="bill", cascade="all, delete-orphan")

    __table_args__ = (
        Index("ix_bills_user_active", "user_id", "is_active"),
    )


class BillPayment(Base):
    """One month's payment record for a bill (created when marked paid)."""
    __tablename__ = "bill_payments"

    id             = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    bill_id        = Column(UUID(as_uuid=False), ForeignKey("bills.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id        = Column(UUID(as_uuid=False), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    amount_paid    = Column(Numeric(12, 2), nullable=True)
    due_date       = Column(DateTime(timezone=True), nullable=False)
    paid_date      = Column(DateTime(timezone=True), nullable=True)
    status         = Column(Enum(BillPaymentStatus), nullable=False, default=BillPaymentStatus.unpaid)
    transaction_id = Column(UUID(as_uuid=False), ForeignKey("transactions.id", ondelete="SET NULL"), nullable=True)
    created_at     = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="bill_payments")
    bill = relationship("Bill", back_populates="payments")

    __table_args__ = (
        UniqueConstraint("bill_id", "due_date", name="uq_bill_payment_due"),
        Index("ix_bill_payments_user_due", "user_id", "due_date"),
    )
