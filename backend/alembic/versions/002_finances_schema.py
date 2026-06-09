"""finances schema

Revision ID: 002_finances_schema
Revises: 001_initial_schema
Create Date: 2026-06-07

"""
from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "002_finances_schema"
down_revision: Union[str, Sequence[str], None] = "001_initial_schema"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "plaid_items",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.String(length=64), nullable=False),
        sa.Column("access_token_enc", sa.Text(), nullable=False),
        sa.Column("item_id", sa.String(length=128), nullable=False),
        sa.Column("institution_id", sa.String(length=64), nullable=True),
        sa.Column("institution_name", sa.String(length=120), nullable=False),
        sa.Column("cursor", sa.Text(), nullable=True),
        sa.Column("last_synced_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "item_id", name="uq_plaid_user_item"),
    )
    op.create_index(op.f("ix_plaid_items_item_id"), "plaid_items", ["item_id"], unique=False)
    op.create_index(op.f("ix_plaid_items_user_id"), "plaid_items", ["user_id"], unique=False)

    op.create_table(
        "plaid_accounts",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("plaid_item_id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.String(length=64), nullable=False),
        sa.Column("account_id", sa.String(length=128), nullable=False),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("mask", sa.String(length=8), nullable=False),
        sa.Column("type", sa.String(length=32), nullable=False),
        sa.Column("subtype", sa.String(length=32), nullable=True),
        sa.Column("current_balance", sa.Float(), nullable=False),
        sa.Column("available_balance", sa.Float(), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["plaid_item_id"], ["plaid_items.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("plaid_item_id", "account_id", name="uq_plaid_item_account"),
    )
    op.create_index(op.f("ix_plaid_accounts_plaid_item_id"), "plaid_accounts", ["plaid_item_id"], unique=False)
    op.create_index(op.f("ix_plaid_accounts_user_id"), "plaid_accounts", ["user_id"], unique=False)

    op.create_table(
        "finance_transactions",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.String(length=64), nullable=False),
        sa.Column("plaid_account_id", sa.String(length=36), nullable=True),
        sa.Column("plaid_transaction_id", sa.String(length=128), nullable=True),
        sa.Column("amount", sa.Float(), nullable=False),
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column("merchant_name", sa.String(length=160), nullable=True),
        sa.Column("name", sa.String(length=200), nullable=False),
        sa.Column("category", sa.String(length=32), nullable=False),
        sa.Column("subcategory", sa.String(length=64), nullable=True),
        sa.Column("is_manual", sa.Boolean(), nullable=False),
        sa.Column("is_pending", sa.Boolean(), nullable=False),
        sa.Column("is_transfer", sa.Boolean(), nullable=False),
        sa.Column("note", sa.String(length=500), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["plaid_account_id"], ["plaid_accounts.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_finance_transactions_category"), "finance_transactions", ["category"], unique=False)
    op.create_index(op.f("ix_finance_transactions_date"), "finance_transactions", ["date"], unique=False)
    op.create_index(op.f("ix_finance_transactions_plaid_account_id"), "finance_transactions", ["plaid_account_id"], unique=False)
    op.create_index(op.f("ix_finance_transactions_plaid_transaction_id"), "finance_transactions", ["plaid_transaction_id"], unique=False)
    op.create_index(op.f("ix_finance_transactions_user_id"), "finance_transactions", ["user_id"], unique=False)

    op.create_table(
        "finance_budgets",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.String(length=64), nullable=False),
        sa.Column("category", sa.String(length=32), nullable=False),
        sa.Column("month", sa.String(length=7), nullable=False),
        sa.Column("limit_amount", sa.Float(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "category", "month", name="uq_budget_user_cat_month"),
    )
    op.create_index(op.f("ix_finance_budgets_month"), "finance_budgets", ["month"], unique=False)
    op.create_index(op.f("ix_finance_budgets_user_id"), "finance_budgets", ["user_id"], unique=False)

    op.create_table(
        "finance_recurring",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.String(length=64), nullable=False),
        sa.Column("merchant_name", sa.String(length=160), nullable=False),
        sa.Column("amount", sa.Float(), nullable=False),
        sa.Column("frequency", sa.String(length=16), nullable=False),
        sa.Column("next_date", sa.Date(), nullable=True),
        sa.Column("category", sa.String(length=32), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_finance_recurring_user_id"), "finance_recurring", ["user_id"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_finance_recurring_user_id"), table_name="finance_recurring")
    op.drop_table("finance_recurring")
    op.drop_index(op.f("ix_finance_budgets_user_id"), table_name="finance_budgets")
    op.drop_index(op.f("ix_finance_budgets_month"), table_name="finance_budgets")
    op.drop_table("finance_budgets")
    op.drop_index(op.f("ix_finance_transactions_user_id"), table_name="finance_transactions")
    op.drop_index(op.f("ix_finance_transactions_plaid_transaction_id"), table_name="finance_transactions")
    op.drop_index(op.f("ix_finance_transactions_plaid_account_id"), table_name="finance_transactions")
    op.drop_index(op.f("ix_finance_transactions_date"), table_name="finance_transactions")
    op.drop_index(op.f("ix_finance_transactions_category"), table_name="finance_transactions")
    op.drop_table("finance_transactions")
    op.drop_index(op.f("ix_plaid_accounts_user_id"), table_name="plaid_accounts")
    op.drop_index(op.f("ix_plaid_accounts_plaid_item_id"), table_name="plaid_accounts")
    op.drop_table("plaid_accounts")
    op.drop_index(op.f("ix_plaid_items_user_id"), table_name="plaid_items")
    op.drop_index(op.f("ix_plaid_items_item_id"), table_name="plaid_items")
    op.drop_table("plaid_items")
