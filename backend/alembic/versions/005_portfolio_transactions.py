"""portfolio transactions

Revision ID: 005_portfolio_transactions
Revises: 004_users_photo_url
Create Date: 2026-06-09

"""
from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "005_portfolio_transactions"
down_revision: Union[str, Sequence[str], None] = "004_users_photo_url"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "portfolio_transactions",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("user_id", sa.String(length=64), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("symbol", sa.String(length=32), nullable=False),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("transaction_type", sa.String(length=8), nullable=False),
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column("quantity", sa.Float(), nullable=False),
        sa.Column("price_per_unit", sa.Float(), nullable=False),
        sa.Column("fees", sa.Float(), nullable=False, server_default="0"),
        sa.Column("broker", sa.String(length=80), nullable=True),
        sa.Column("currency", sa.String(length=8), nullable=False, server_default="usd"),
        sa.Column("category", sa.String(length=32), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_portfolio_transactions_user_id", "portfolio_transactions", ["user_id"])
    op.create_index("ix_portfolio_transactions_symbol", "portfolio_transactions", ["symbol"])
    op.create_index("ix_portfolio_transactions_date", "portfolio_transactions", ["date"])


def downgrade() -> None:
    op.drop_index("ix_portfolio_transactions_date", table_name="portfolio_transactions")
    op.drop_index("ix_portfolio_transactions_symbol", table_name="portfolio_transactions")
    op.drop_index("ix_portfolio_transactions_user_id", table_name="portfolio_transactions")
    op.drop_table("portfolio_transactions")
