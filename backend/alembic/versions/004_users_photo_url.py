"""users photo_url

Revision ID: 004_users_photo_url
Revises: 003_auth_password_reset
Create Date: 2026-06-09

"""
from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "004_users_photo_url"
down_revision: Union[str, Sequence[str], None] = "003_auth_password_reset"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("users", sa.Column("photo_url", sa.String(length=512), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "photo_url")
