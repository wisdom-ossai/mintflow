"""baseline schema + plaid_sync_cursor

Revision ID: 0001_baseline
Revises:
Create Date: 2026-08-15

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "0001_baseline"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# Enum names match SQLAlchemy Enum() defaults from app.models.models
subscriptiontier = postgresql.ENUM(
    "seed", "growth", "pro", name="subscriptiontier", create_type=False
)
accounttype = postgresql.ENUM(
    "bank", "credit_card", "cash", "wallet", name="accounttype", create_type=False
)
transactiontype = postgresql.ENUM(
    "income", "expense", "credit_payment", "transfer", name="transactiontype", create_type=False
)
transactionsource = postgresql.ENUM(
    "plaid", "manual", "ocr", name="transactionsource", create_type=False
)
budgetperiod = postgresql.ENUM("monthly", "annual", name="budgetperiod", create_type=False)
insightperiod = postgresql.ENUM(
    "week", "month", "year", name="insightperiod", create_type=False
)
notificationtype = postgresql.ENUM(
    "daily_summary",
    "budget_50",
    "budget_80",
    "budget_exceeded",
    "weekly_digest",
    "monthly_report",
    "milestone",
    "inactivity",
    "ai_nudge",
    "salary_detected",
    "card_payment_due",
    "subscription_renewal",
    "high_utilization",
    name="notificationtype",
    create_type=False,
)


def upgrade() -> None:
    bind = op.get_bind()
    subscriptiontier.create(bind, checkfirst=True)
    accounttype.create(bind, checkfirst=True)
    transactiontype.create(bind, checkfirst=True)
    transactionsource.create(bind, checkfirst=True)
    budgetperiod.create(bind, checkfirst=True)
    insightperiod.create(bind, checkfirst=True)
    notificationtype.create(bind, checkfirst=True)

    op.create_table(
        "users",
        sa.Column("id", sa.UUID(as_uuid=False), primary_key=True),
        sa.Column("email", sa.String(255), nullable=False),
        sa.Column("full_name", sa.String(255), nullable=True),
        sa.Column("avatar_url", sa.String(512), nullable=True),
        sa.Column("subscription_tier", subscriptiontier, nullable=False),
        sa.Column("trial_ends_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("locale", sa.String(10), server_default="en-US"),
        sa.Column("currency", sa.String(3), server_default="USD"),
        sa.Column("monthly_income", sa.Numeric(12, 2), nullable=True),
        sa.Column("firebase_token", sa.String(512), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_users_email", "users", ["email"], unique=True)

    op.create_table(
        "accounts",
        sa.Column("id", sa.UUID(as_uuid=False), primary_key=True),
        sa.Column("user_id", sa.UUID(as_uuid=False), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("plaid_account_id", sa.String(255), unique=True, nullable=True),
        sa.Column("plaid_item_id", sa.String(255), nullable=True),
        sa.Column("plaid_access_token", sa.Text(), nullable=True),
        sa.Column("plaid_sync_cursor", sa.Text(), nullable=True),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("institution_name", sa.String(255), nullable=True),
        sa.Column("account_type", accounttype, nullable=False),
        sa.Column("currency", sa.String(3), server_default="USD"),
        sa.Column("balance", sa.Numeric(14, 2), nullable=True),
        sa.Column("credit_limit", sa.Numeric(14, 2), nullable=True),
        sa.Column("outstanding_balance", sa.Numeric(14, 2), nullable=True),
        sa.Column("statement_day", sa.Integer(), nullable=True),
        sa.Column("due_day", sa.Integer(), nullable=True),
        sa.Column("is_active", sa.Boolean(), server_default=sa.text("true")),
        sa.Column("last_synced_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_accounts_user_id", "accounts", ["user_id"])

    op.create_table(
        "categories",
        sa.Column("id", sa.UUID(as_uuid=False), primary_key=True),
        sa.Column("user_id", sa.UUID(as_uuid=False), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=True),
        sa.Column("name", sa.String(100), nullable=False),
        sa.Column("icon", sa.String(50), nullable=True),
        sa.Column("color", sa.String(7), nullable=True),
        sa.Column("is_custom", sa.Boolean(), server_default=sa.text("false")),
        sa.Column("is_active", sa.Boolean(), server_default=sa.text("true")),
        sa.Column("sort_order", sa.Integer(), server_default="0"),
        sa.UniqueConstraint("user_id", "name", name="uq_category_user_name"),
    )
    op.create_index("ix_categories_user_id", "categories", ["user_id"])

    op.create_table(
        "merchant_cache",
        sa.Column("id", sa.UUID(as_uuid=False), primary_key=True),
        sa.Column("merchant_name", sa.String(255), nullable=False, unique=True),
        sa.Column("category_name", sa.String(100), nullable=False),
        sa.Column("is_need", sa.Boolean(), nullable=False),
        sa.Column("confidence", sa.Numeric(3, 2), server_default="1.0"),
        sa.Column("hit_count", sa.Integer(), server_default="1"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_merchant_cache_merchant_name", "merchant_cache", ["merchant_name"])

    op.create_table(
        "transactions",
        sa.Column("id", sa.UUID(as_uuid=False), primary_key=True),
        sa.Column("user_id", sa.UUID(as_uuid=False), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("account_id", sa.UUID(as_uuid=False), sa.ForeignKey("accounts.id", ondelete="SET NULL"), nullable=True),
        sa.Column("category_id", sa.UUID(as_uuid=False), sa.ForeignKey("categories.id", ondelete="SET NULL"), nullable=True),
        sa.Column("plaid_transaction_id", sa.String(255), unique=True, nullable=True),
        sa.Column("amount", sa.Numeric(12, 2), nullable=False),
        sa.Column("transaction_type", transactiontype, nullable=False),
        sa.Column("is_need", sa.Boolean(), nullable=True),
        sa.Column("description", sa.String(500), nullable=True),
        sa.Column("merchant_name", sa.String(255), nullable=True),
        sa.Column("date", sa.DateTime(timezone=True), nullable=False),
        sa.Column("source", transactionsource),
        sa.Column("is_credit_card_payment", sa.Boolean(), server_default=sa.text("false")),
        sa.Column("is_recurring", sa.Boolean(), server_default=sa.text("false")),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("receipt_url", sa.String(512), nullable=True),
        sa.Column("ai_categorized", sa.Boolean(), server_default=sa.text("false")),
        sa.Column("ai_confidence", sa.Numeric(3, 2), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_transactions_user_id", "transactions", ["user_id"])
    op.create_index("ix_transactions_account_id", "transactions", ["account_id"])
    op.create_index("ix_transactions_merchant_name", "transactions", ["merchant_name"])
    op.create_index("ix_transactions_date", "transactions", ["date"])
    op.create_index("ix_transactions_user_date", "transactions", ["user_id", "date"])
    op.create_index("ix_transactions_user_type", "transactions", ["user_id", "transaction_type"])

    op.create_table(
        "budgets",
        sa.Column("id", sa.UUID(as_uuid=False), primary_key=True),
        sa.Column("user_id", sa.UUID(as_uuid=False), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("category_id", sa.UUID(as_uuid=False), sa.ForeignKey("categories.id", ondelete="CASCADE"), nullable=True),
        sa.Column("amount", sa.Numeric(12, 2), nullable=False),
        sa.Column("period", budgetperiod, nullable=False),
        sa.Column("rollover", sa.Boolean(), server_default=sa.text("false")),
        sa.Column("is_active", sa.Boolean(), server_default=sa.text("true")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint("user_id", "category_id", "period", name="uq_budget_user_cat_period"),
    )
    op.create_index("ix_budgets_user_id", "budgets", ["user_id"])

    op.create_table(
        "insights",
        sa.Column("id", sa.UUID(as_uuid=False), primary_key=True),
        sa.Column("user_id", sa.UUID(as_uuid=False), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("period", insightperiod, nullable=False),
        sa.Column("period_key", sa.String(20), nullable=False),
        sa.Column("content", postgresql.JSONB(), nullable=False),
        sa.Column("thumbs_up", sa.Boolean(), nullable=True),
        sa.Column("generated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.UniqueConstraint("user_id", "period", "period_key", name="uq_insight_user_period"),
    )
    op.create_index("ix_insights_user_id", "insights", ["user_id"])

    op.create_table(
        "notification_preferences",
        sa.Column("id", sa.UUID(as_uuid=False), primary_key=True),
        sa.Column("user_id", sa.UUID(as_uuid=False), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("notification_type", notificationtype, nullable=False),
        sa.Column("enabled", sa.Boolean(), server_default=sa.text("true")),
        sa.Column("time_of_day", sa.String(5), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint("user_id", "notification_type", name="uq_notif_user_type"),
    )
    op.create_index("ix_notification_preferences_user_id", "notification_preferences", ["user_id"])


def downgrade() -> None:
    op.drop_table("notification_preferences")
    op.drop_table("insights")
    op.drop_table("budgets")
    op.drop_table("transactions")
    op.drop_table("merchant_cache")
    op.drop_table("categories")
    op.drop_table("accounts")
    op.drop_table("users")
    bind = op.get_bind()
    notificationtype.drop(bind, checkfirst=True)
    insightperiod.drop(bind, checkfirst=True)
    budgetperiod.drop(bind, checkfirst=True)
    transactionsource.drop(bind, checkfirst=True)
    transactiontype.drop(bind, checkfirst=True)
    accounttype.drop(bind, checkfirst=True)
    subscriptiontier.drop(bind, checkfirst=True)
