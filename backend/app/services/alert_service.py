from __future__ import annotations

import uuid

from sqlalchemy import delete, select

from app.core.exceptions import AppError
from app.db.models import PriceAlertRow
from app.db.session import get_session_factory
from app.domain.alerts.models import (
    PriceAlertCreateRequest,
    PriceAlertListResponse,
    PriceAlertResponse,
)
from app.domain.auth.models import MessageResponse


class AlertService:
    def __init__(self, session_factory=None) -> None:
        self._session_factory = session_factory or get_session_factory()

    def list_alerts(self, user_id: str) -> PriceAlertListResponse:
        with self._session_factory() as session:
            rows = session.scalars(
                select(PriceAlertRow)
                .where(PriceAlertRow.user_id == user_id)
                .order_by(PriceAlertRow.symbol)
            ).all()
            items = [self._to_response(row) for row in rows]
            return PriceAlertListResponse(items=items, count=len(items))

    def create_alert(self, user_id: str, body: PriceAlertCreateRequest) -> PriceAlertResponse:
        symbol = body.symbol.upper().strip()
        with self._session_factory() as session:
            existing = session.scalar(
                select(PriceAlertRow).where(
                    PriceAlertRow.user_id == user_id,
                    PriceAlertRow.symbol == symbol,
                    PriceAlertRow.direction == body.direction,
                )
            )
            if existing is not None:
                existing.target_price = body.target_price
                existing.category = body.category
                existing.enabled = True
                session.commit()
                session.refresh(existing)
                return self._to_response(existing)

            row = PriceAlertRow(
                id=str(uuid.uuid4()),
                user_id=user_id,
                symbol=symbol,
                category=body.category,
                direction=body.direction,
                target_price=body.target_price,
                enabled=True,
            )
            session.add(row)
            session.commit()
            session.refresh(row)
            return self._to_response(row)

    def delete_alert(self, user_id: str, alert_id: str) -> MessageResponse:
        with self._session_factory() as session:
            row = session.scalar(
                select(PriceAlertRow).where(
                    PriceAlertRow.id == alert_id,
                    PriceAlertRow.user_id == user_id,
                )
            )
            if row is None:
                raise AppError("Alerta não encontrado", status_code=404)
            session.delete(row)
            session.commit()
        return MessageResponse(message="Alert removed.")

    def purge_user_alerts(self, user_id: str) -> None:
        with self._session_factory() as session:
            session.execute(delete(PriceAlertRow).where(PriceAlertRow.user_id == user_id))
            session.commit()

    @staticmethod
    def _to_response(row: PriceAlertRow) -> PriceAlertResponse:
        return PriceAlertResponse(
            id=row.id,
            symbol=row.symbol,
            category=row.category,
            direction=row.direction,
            target_price=row.target_price,
            enabled=row.enabled,
        )


alert_service = AlertService()
