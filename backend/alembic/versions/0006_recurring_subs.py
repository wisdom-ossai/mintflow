"""recurring_subscriptions table for Plaid-detected merchant subscriptions

Revision ID: 0006_recurring_subs
Revises: 0005_apple_sub
Create Date: 2026-09-20
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "0006_recurring_subs"
down_revision: Union[str, None] = "0005_apple_sub"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# create_type=False: create enums once below; create_table must not re-emit CREATE TYPE
recurring_frequency = postgresql.ENUM(
    "weekly", "monthly", "yearly", name="recurringfrequency", create_type=False
)
recurring_status = postgresql.ENUM(
    "active", "dismissed", "cancelled", name="recurringstatus", create_type=False
)


def upgrade() -> None:
    bind = op.get_bind()
    recurring_frequency.create(bind, checkfirst=True)
    recurring_status.create(bind, checkfirst=True)

    op.create_table(
        "recurring_subscriptions",
        sa.Column("id", sa.UUID(as_uuid=False), primary_key=True),
        sa.Column(
            "user_id",
            sa.UUID(as_uuid=False),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        sa.Column("merchant_key", sa.String(255), nullable=False),
        sa.Column("display_name", sa.String(255), nullable=False),
        sa.Column("typical_amount", sa.Numeric(12, 2), nullable=False),
        sa.Column("currency", sa.String(3), server_default="USD"),
        sa.Column("frequency", recurring_frequency, nullable=False),
        sa.Column("status", recurring_status, nullable=False),
        sa.Column("occurrence_count", sa.Integer(), server_default="0"),
        sa.Column("last_charged_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("next_expected_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
        ),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint(
            "user_id", "merchant_key", name="uq_recurring_user_merchant"
        ),
    )
    op.create_index(
        "ix_recurring_user_status",
        "recurring_subscriptions",
        ["user_id", "status"],
    )


def downgrade() -> None:
    op.drop_index("ix_recurring_user_status", table_name="recurring_subscriptions")
    op.drop_table("recurring_subscriptions")
    bind = op.get_bind()
    recurring_status.drop(bind, checkfirst=True)
    recurring_frequency.drop(bind, checkfirst=True)
