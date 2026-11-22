"""savings_goals, debt_plans, account apr/min, bill_due notification enum

Revision ID: 0008_goals_debt_ocr
Revises: 0007_bills
Create Date: 2026-11-21
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "0008_goals_debt_ocr"
down_revision: Union[str, None] = "0007_bills"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

goal_status = postgresql.ENUM(
    "active", "completed", "paused", name="goalstatus", create_type=False
)
debt_strategy = postgresql.ENUM(
    "snowball", "avalanche", name="debtstrategy", create_type=False
)


def upgrade() -> None:
    bind = op.get_bind()
    goal_status.create(bind, checkfirst=True)
    debt_strategy.create(bind, checkfirst=True)

    # Extend notificationtype enum with bill_due (Postgres ALTER TYPE)
    op.execute("ALTER TYPE notificationtype ADD VALUE IF NOT EXISTS 'bill_due'")

    op.add_column(
        "accounts",
        sa.Column("apr", sa.Numeric(5, 2), nullable=True),
    )
    op.add_column(
        "accounts",
        sa.Column("minimum_payment", sa.Numeric(12, 2), nullable=True),
    )

    op.create_table(
        "savings_goals",
        sa.Column("id", sa.UUID(as_uuid=False), primary_key=True),
        sa.Column(
            "user_id",
            sa.UUID(as_uuid=False),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("target_amount", sa.Numeric(12, 2), nullable=False),
        sa.Column(
            "current_amount",
            sa.Numeric(12, 2),
            nullable=False,
            server_default="0",
        ),
        sa.Column("target_date", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "linked_account_id",
            sa.UUID(as_uuid=False),
            sa.ForeignKey("accounts.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("icon", sa.String(50), nullable=True),
        sa.Column("color", sa.String(7), nullable=True),
        sa.Column("status", goal_status, nullable=False),
        sa.Column("ai_suggestion", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
        ),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index(
        "ix_savings_goals_user_status",
        "savings_goals",
        ["user_id", "status"],
    )

    op.create_table(
        "debt_plans",
        sa.Column("id", sa.UUID(as_uuid=False), primary_key=True),
        sa.Column(
            "user_id",
            sa.UUID(as_uuid=False),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        sa.Column("strategy", debt_strategy, nullable=False),
        sa.Column(
            "monthly_extra_payment",
            sa.Numeric(12, 2),
            nullable=False,
            server_default="0",
        ),
        sa.Column("content", sa.JSON(), nullable=False),
        sa.Column(
            "generated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
        ),
    )
    op.create_index(
        "ix_debt_plans_user_generated",
        "debt_plans",
        ["user_id", "generated_at"],
    )


def downgrade() -> None:
    op.drop_index("ix_debt_plans_user_generated", table_name="debt_plans")
    op.drop_table("debt_plans")
    op.drop_index("ix_savings_goals_user_status", table_name="savings_goals")
    op.drop_table("savings_goals")
    op.drop_column("accounts", "minimum_payment")
    op.drop_column("accounts", "apr")
    # Postgres cannot easily remove enum values; leave bill_due / types in place
    debt_strategy.drop(op.get_bind(), checkfirst=True)
    goal_status.drop(op.get_bind(), checkfirst=True)
