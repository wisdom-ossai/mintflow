"""bills + bill_payments for manual due-date tracking

Revision ID: 0007_bills
Revises: 0006_recurring_subs
Create Date: 2026-09-21
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "0007_bills"
down_revision: Union[str, None] = "0006_recurring_subs"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# create_type=False: create enum once below; create_table must not re-emit CREATE TYPE
bill_payment_status = postgresql.ENUM(
    "unpaid", "paid", "overdue", name="billpaymentstatus", create_type=False
)


def upgrade() -> None:
    bind = op.get_bind()
    bill_payment_status.create(bind, checkfirst=True)

    op.create_table(
        "bills",
        sa.Column("id", sa.UUID(as_uuid=False), primary_key=True),
        sa.Column(
            "user_id",
            sa.UUID(as_uuid=False),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("amount", sa.Numeric(12, 2), nullable=True),
        sa.Column("due_day", sa.Integer(), nullable=False),
        sa.Column(
            "category_id",
            sa.UUID(as_uuid=False),
            sa.ForeignKey("categories.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("is_autopay", sa.Boolean(), server_default=sa.text("false")),
        sa.Column("is_active", sa.Boolean(), server_default=sa.text("true")),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
        ),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_bills_user_active", "bills", ["user_id", "is_active"])

    op.create_table(
        "bill_payments",
        sa.Column("id", sa.UUID(as_uuid=False), primary_key=True),
        sa.Column(
            "bill_id",
            sa.UUID(as_uuid=False),
            sa.ForeignKey("bills.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        sa.Column(
            "user_id",
            sa.UUID(as_uuid=False),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        sa.Column("amount_paid", sa.Numeric(12, 2), nullable=True),
        sa.Column("due_date", sa.DateTime(timezone=True), nullable=False),
        sa.Column("paid_date", sa.DateTime(timezone=True), nullable=True),
        sa.Column("status", bill_payment_status, nullable=False),
        sa.Column(
            "transaction_id",
            sa.UUID(as_uuid=False),
            sa.ForeignKey("transactions.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
        ),
        sa.UniqueConstraint("bill_id", "due_date", name="uq_bill_payment_due"),
    )
    op.create_index(
        "ix_bill_payments_user_due",
        "bill_payments",
        ["user_id", "due_date"],
    )


def downgrade() -> None:
    op.drop_index("ix_bill_payments_user_due", table_name="bill_payments")
    op.drop_table("bill_payments")
    op.drop_index("ix_bills_user_active", table_name="bills")
    op.drop_table("bills")
    bill_payment_status.drop(op.get_bind(), checkfirst=True)
