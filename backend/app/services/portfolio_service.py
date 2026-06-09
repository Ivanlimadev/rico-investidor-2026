from __future__ import annotations

import uuid

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.exceptions import AppError
from app.db.models import PortfolioHoldingRow, PortfolioTransactionRow
from app.db.session import get_session_factory
from app.domain.portfolio.models import (
    PortfolioHoldingCreateRequest,
    PortfolioHoldingResponse,
    PortfolioHoldingUpdateRequest,
    PortfolioHoldingsListResponse,
    PortfolioSyncRequest,
    TransactionCreateRequest,
    TransactionListResponse,
    TransactionResponse,
)


class PortfolioService:
    def __init__(self, session_factory=None) -> None:
        self._session_factory = session_factory

    def _open_session(self) -> Session:
        factory = self._session_factory or get_session_factory()
        return factory()

    def list_holdings(self, user_id: str) -> PortfolioHoldingsListResponse:
        with self._open_session() as session:
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
        with self._open_session() as session:
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
        with self._open_session() as session:
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
        with self._open_session() as session:
            row = self._get_owned_row(session, user_id, holding_id)
            session.delete(row)
            session.commit()

    def sync_holdings(self, user_id: str, body: PortfolioSyncRequest) -> PortfolioHoldingsListResponse:
        with self._open_session() as session:
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

    def add_transaction(
        self,
        user_id: str,
        body: TransactionCreateRequest,
    ) -> TransactionResponse:
        symbol = body.symbol.upper().strip()
        with self._open_session() as session:
            existing = session.scalars(
                select(PortfolioTransactionRow)
                .where(
                    PortfolioTransactionRow.user_id == user_id,
                    PortfolioTransactionRow.symbol == symbol,
                )
                .order_by(
                    PortfolioTransactionRow.date.asc(),
                    PortfolioTransactionRow.created_at.asc(),
                )
            ).all()
            quantity, _ = self._compute_position_from_transactions(existing)
            if body.transaction_type == "sell" and body.quantity > quantity + 1e-9:
                raise AppError("Quantidade de venda maior que a posição", status_code=400)

            row = PortfolioTransactionRow(
                id=str(uuid.uuid4()),
                user_id=user_id,
                symbol=symbol,
                name=body.name.strip(),
                transaction_type=body.transaction_type,
                date=body.date,
                quantity=body.quantity,
                price_per_unit=body.price_per_unit,
                fees=body.fees,
                broker=body.broker.strip() if body.broker else None,
                currency=body.currency.lower(),
                category=body.category,
            )
            session.add(row)
            session.flush()
            self._recalculate_holding(session, user_id, symbol)
            session.commit()
            session.refresh(row)
            return self._to_transaction_response(row)

    def list_transactions(
        self,
        user_id: str,
        symbol: str | None = None,
    ) -> TransactionListResponse:
        with self._open_session() as session:
            stmt = select(PortfolioTransactionRow).where(PortfolioTransactionRow.user_id == user_id)
            if symbol:
                stmt = stmt.where(PortfolioTransactionRow.symbol == symbol.upper().strip())
            rows = session.scalars(
                stmt.order_by(
                    PortfolioTransactionRow.date.desc(),
                    PortfolioTransactionRow.created_at.desc(),
                )
            ).all()
            items = [self._to_transaction_response(row) for row in rows]
            return TransactionListResponse(items=items, count=len(items))

    def delete_transaction(
        self,
        user_id: str,
        transaction_id: str,
    ) -> PortfolioHoldingsListResponse:
        with self._open_session() as session:
            row = session.get(PortfolioTransactionRow, transaction_id)
            if row is None or row.user_id != user_id:
                raise AppError("Transação não encontrada", status_code=404)
            symbol = row.symbol
            session.delete(row)
            session.flush()
            self._recalculate_holding(session, user_id, symbol)
            session.commit()
            rows = session.scalars(
                select(PortfolioHoldingRow)
                .where(PortfolioHoldingRow.user_id == user_id)
                .order_by(PortfolioHoldingRow.symbol)
            ).all()
            items = [self._to_response(item) for item in rows]
            return PortfolioHoldingsListResponse(items=items, count=len(items))

    def _recalculate_holding(self, session: Session, user_id: str, symbol: str) -> None:
        symbol = symbol.upper().strip()
        txs = session.scalars(
            select(PortfolioTransactionRow)
            .where(
                PortfolioTransactionRow.user_id == user_id,
                PortfolioTransactionRow.symbol == symbol,
            )
            .order_by(
                PortfolioTransactionRow.date.asc(),
                PortfolioTransactionRow.created_at.asc(),
            )
        ).all()
        quantity, average_price = self._compute_position_from_transactions(txs)
        holding = session.scalar(
            select(PortfolioHoldingRow).where(
                PortfolioHoldingRow.user_id == user_id,
                PortfolioHoldingRow.symbol == symbol,
            )
        )
        if quantity <= 1e-9:
            if holding is not None:
                session.delete(holding)
            return

        meta = txs[-1]
        if holding is None:
            holding = PortfolioHoldingRow(
                id=str(uuid.uuid4()),
                user_id=user_id,
                symbol=symbol,
            )
            session.add(holding)
        holding.name = meta.name.strip()
        holding.quantity = quantity
        holding.average_price = average_price
        holding.currency = meta.currency.lower()
        holding.category = meta.category

    @staticmethod
    def _compute_position_from_transactions(
        txs: list[PortfolioTransactionRow],
    ) -> tuple[float, float]:
        quantity = 0.0
        average_price = 0.0
        for tx in txs:
            if tx.transaction_type == "buy":
                buy_cost = tx.quantity * tx.price_per_unit + tx.fees
                total_cost = quantity * average_price + buy_cost
                quantity += tx.quantity
                average_price = total_cost / quantity if quantity > 0 else 0.0
            elif tx.transaction_type == "sell":
                quantity -= tx.quantity
        return quantity, average_price

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

    @staticmethod
    def _to_transaction_response(row: PortfolioTransactionRow) -> TransactionResponse:
        return TransactionResponse(
            id=row.id,
            symbol=row.symbol,
            name=row.name,
            transaction_type=row.transaction_type,
            date=row.date,
            quantity=row.quantity,
            price_per_unit=row.price_per_unit,
            fees=row.fees,
            broker=row.broker,
            total_cost=(row.quantity * row.price_per_unit) + row.fees,
            currency=row.currency,
            category=row.category,
            created_at=row.created_at,
        )


portfolio_service = PortfolioService()
