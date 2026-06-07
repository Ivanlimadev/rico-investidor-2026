from __future__ import annotations

import uuid

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.exceptions import AppError
from app.db.models import PortfolioHoldingRow
from app.db.session import get_session_factory
from app.domain.portfolio.models import (
    PortfolioHoldingCreateRequest,
    PortfolioHoldingResponse,
    PortfolioHoldingUpdateRequest,
    PortfolioHoldingsListResponse,
    PortfolioSyncRequest,
)


class PortfolioService:
    def __init__(self, session_factory=None) -> None:
        self._session_factory = session_factory or get_session_factory()

    def list_holdings(self, user_id: str) -> PortfolioHoldingsListResponse:
        with self._session_factory() as session:
            rows = session.scalars(
                select(PortfolioHoldingRow)
                .where(PortfolioHoldingRow.user_id == user_id)
                .order_by(PortfolioHoldingRow.symbol)
            ).all()
            items = [self._to_response(row) for row in rows]
            return PortfolioHoldingsListResponse(items=items, count=len(items))

    def create_holding(
        self,
        user_id: str,
        body: PortfolioHoldingCreateRequest,
    ) -> PortfolioHoldingResponse:
        symbol = body.symbol.upper().strip()
        with self._session_factory() as session:
            existing = session.scalar(
                select(PortfolioHoldingRow).where(
                    PortfolioHoldingRow.user_id == user_id,
                    PortfolioHoldingRow.symbol == symbol,
                )
            )
            if existing is not None:
                raise AppError(f"Posição já existe: {symbol}", status_code=409)

            row = PortfolioHoldingRow(
                id=body.id or str(uuid.uuid4()),
                user_id=user_id,
                symbol=symbol,
                name=body.name.strip(),
                quantity=body.quantity,
                average_price=body.average_price,
                current_price=body.current_price,
                change_percent=body.change_percent,
                currency=body.currency.lower(),
                category=body.category,
            )
            session.add(row)
            session.commit()
            session.refresh(row)
            return self._to_response(row)

    def update_holding(
        self,
        user_id: str,
        holding_id: str,
        body: PortfolioHoldingUpdateRequest,
    ) -> PortfolioHoldingResponse:
        with self._session_factory() as session:
            row = self._get_owned_row(session, user_id, holding_id)
            if body.name is not None:
                row.name = body.name.strip()
            if body.quantity is not None:
                row.quantity = body.quantity
            if body.average_price is not None:
                row.average_price = body.average_price
            if body.current_price is not None:
                row.current_price = body.current_price
            if body.change_percent is not None:
                row.change_percent = body.change_percent
            if body.currency is not None:
                row.currency = body.currency.lower()
            if body.category is not None:
                row.category = body.category
            session.commit()
            session.refresh(row)
            return self._to_response(row)

    def delete_holding(self, user_id: str, holding_id: str) -> None:
        with self._session_factory() as session:
            row = self._get_owned_row(session, user_id, holding_id)
            session.delete(row)
            session.commit()

    def sync_holdings(self, user_id: str, body: PortfolioSyncRequest) -> PortfolioHoldingsListResponse:
        with self._session_factory() as session:
            existing = {
                row.symbol: row
                for row in session.scalars(
                    select(PortfolioHoldingRow).where(PortfolioHoldingRow.user_id == user_id)
                ).all()
            }
            seen_symbols: set[str] = set()
            for item in body.items:
                symbol = item.symbol.upper().strip()
                if not symbol or symbol in seen_symbols:
                    continue
                seen_symbols.add(symbol)
                row = existing.get(symbol)
                if row is None:
                    row = PortfolioHoldingRow(
                        id=item.id or str(uuid.uuid4()),
                        user_id=user_id,
                        symbol=symbol,
                    )
                    session.add(row)
                row.name = item.name.strip()
                row.quantity = item.quantity
                row.average_price = item.average_price
                if item.current_price > 0 or row.current_price == 0:
                    row.current_price = item.current_price
                if item.change_percent != 0 or row.change_percent == 0:
                    row.change_percent = item.change_percent
                row.currency = item.currency.lower()
                row.category = item.category

            for symbol, row in existing.items():
                if symbol not in seen_symbols:
                    session.delete(row)

            session.commit()
            rows = session.scalars(
                select(PortfolioHoldingRow)
                .where(PortfolioHoldingRow.user_id == user_id)
                .order_by(PortfolioHoldingRow.symbol)
            ).all()
            items = [self._to_response(row) for row in rows]
            return PortfolioHoldingsListResponse(items=items, count=len(items))

    @staticmethod
    def _get_owned_row(session: Session, user_id: str, holding_id: str) -> PortfolioHoldingRow:
        row = session.get(PortfolioHoldingRow, holding_id)
        if row is None or row.user_id != user_id:
            raise AppError("Posição não encontrada", status_code=404)
        return row

    @staticmethod
    def _to_response(row: PortfolioHoldingRow) -> PortfolioHoldingResponse:
        return PortfolioHoldingResponse(
            id=row.id,
            symbol=row.symbol,
            name=row.name,
            quantity=row.quantity,
            average_price=row.average_price,
            current_price=row.current_price,
            change_percent=row.change_percent,
            currency=row.currency,
            category=row.category,
        )


portfolio_service = PortfolioService()
