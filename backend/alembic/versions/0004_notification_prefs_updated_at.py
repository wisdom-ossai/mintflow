"""add notification_preferences.updated_at

Revision ID: 0004_notif_prefs_updated_at
Revises: 0003_budgets_updated_at
Create Date: 2026-08-18
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0004_notif_prefs_updated_at"
down_revision: Union[str, None] = "0003_budgets_updated_at"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Idempotent for environments created from a corrected baseline.
    op.execute(
        sa.text(
            "ALTER TABLE notification_preferences ADD COLUMN IF NOT EXISTS "
            "updated_at TIMESTAMP WITH TIME ZONE"
        )
    )


def downgrade() -> None:
    op.drop_column("notification_preferences", "updated_at")
