"""add budgets.updated_at

Revision ID: 0003_budgets_updated_at
Revises: 0002_auth
Create Date: 2026-08-16
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0003_budgets_updated_at"
down_revision: Union[str, None] = "0002_auth"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Idempotent: 0001_baseline may already include this on fresh installs.
    op.execute(
        sa.text(
            "ALTER TABLE budgets ADD COLUMN IF NOT EXISTS "
            "updated_at TIMESTAMP WITH TIME ZONE"
        )
    )


def downgrade() -> None:
    op.drop_column("budgets", "updated_at")
