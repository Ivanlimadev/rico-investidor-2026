from __future__ import annotations

import logging
import uuid
from collections import defaultdict
from datetime import UTC, date, datetime
from typing import Any

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.clients.plaid.client import PlaidGateway, plaid_is_configured
from app.core.exceptions import AppError
from app.core.token_encryption import decrypt_secret, encrypt_secret
from app.db.models import (
    FinanceBudgetRow,
    FinanceRecurringRow,
    FinanceTransactionRow,
    PlaidAccountRow,
    PlaidItemRow,
)
from app.db.session import get_session_factory
from app.domain.auth.models import MessageResponse
from app.domain.finances.categories import normalize_plaid_category
from app.domain.finances.models import (
    BudgetCategoryResponse,
    ExchangeTokenRequest,
    FinanceBudgetResponse,
    FinanceBudgetUpsertRequest,
    FinanceBillsResponse,
    FinanceSummaryResponse,
    FinanceTransactionCreateRequest,
    FinanceTransactionResponse,
    FinanceTransactionsListResponse,
    FinanceTransactionUpdateRequest,
    LinkTokenResponse,
    PlaidAccountResponse,
    PlaidAccountsListResponse,
    RecurringBillResponse,
)

logger = logging.getLogger(__name__)


def _month_key(value: date | None = None) -> str:
    ref = value or date.today()
    return f"{ref.year:04d}-{ref.month:02d}"


def _normalize_plaid_amount(amount: float) -> float:
    return -float(amount)


def _is_transfer_category(primary: str | None, category: str) -> bool:
    if category == "transfers":
        return True
    if primary and "TRANSFER" in primary.upper():
        return True
    return False


class FinanceService:
    def __init__(self, session_factory=None, plaid: PlaidGateway | None = None) -> None:
        self._session_factory = session_factory
        self._plaid = plaid or PlaidGateway()

    def _open_session(self) -> Session:
        factory = self._session_factory or get_session_factory()
        return factory()

    def create_link_token(self, user_id: str) -> LinkTokenResponse:
        if not plaid_is_configured():
            raise AppError("Plaid não configurado", status_code=503)
        token = self._plaid.create_link_token(user_id=user_id)
        return LinkTokenResponse(link_token=token)

    def exchange_public_token(
        self,
        user_id: str,
        body: ExchangeTokenRequest,
    ) -> dict[str, Any]:
        if not plaid_is_configured():
            raise AppError("Plaid não configurado", status_code=503)

        access_token, item_id = self._plaid.exchange_public_token(body.public_token.strip())
        payload = self._plaid.fetch_item(access_token)
        institution_name = self._resolve_institution_name(payload)
        accounts_payload = self._plaid.fetch_accounts(access_token)

        with self._open_session() as session:
            existing = session.scalar(
                select(PlaidItemRow).where(
                    PlaidItemRow.user_id == user_id,
                    PlaidItemRow.item_id == item_id,
                )
            )
            if existing is None:
                item_row = PlaidItemRow(
                    id=str(uuid.uuid4()),
                    user_id=user_id,
                    access_token_enc=encrypt_secret(access_token),
                    item_id=item_id,
                    institution_id=self._institution_id(payload),
                    institution_name=institution_name,
                )
                session.add(item_row)
            else:
                item_row = existing
                item_row.access_token_enc = encrypt_secret(access_token)
                item_row.institution_name = institution_name
                item_row.institution_id = self._institution_id(payload)

            self._upsert_accounts(session, item_row, accounts_payload)
            session.commit()
            account_count = len(accounts_payload.get("accounts") or [])

        synced = self.sync_user_items(user_id)
        return {
            "success": True,
            "institution_name": institution_name,
            "account_count": account_count,
            "transactions_synced": synced,
        }

    def sync_user_items(self, user_id: str) -> int:
        if not plaid_is_configured():
            return 0

        total = 0
        with self._open_session() as session:
            items = session.scalars(
                select(PlaidItemRow).where(PlaidItemRow.user_id == user_id)
            ).all()
            for item in items:
                total += self._sync_item_transactions(session, item)
            session.commit()
        return total

    def handle_webhook(self, payload: dict[str, Any]) -> dict[str, str]:
        webhook_type = str(payload.get("webhook_type") or "")
        webhook_code = str(payload.get("webhook_code") or "")
        item_id = str(payload.get("item_id") or "")

        if webhook_type == "TRANSACTIONS" and webhook_code in {
            "SYNC_UPDATES_AVAILABLE",
            "DEFAULT_UPDATE",
            "INITIAL_UPDATE",
            "HISTORICAL_UPDATE",
        }:
            if item_id:
                self._sync_item_by_plaid_id(item_id)
        return {"status": "ok"}

    def list_accounts(self, user_id: str) -> PlaidAccountsListResponse:
        with self._open_session() as session:
            rows = session.scalars(
                select(PlaidAccountRow)
                .where(PlaidAccountRow.user_id == user_id)
                .order_by(PlaidAccountRow.name)
            ).all()
            item_names = {
                item.id: item.institution_name
                for item in session.scalars(select(PlaidItemRow).where(PlaidItemRow.user_id == user_id)).all()
            }
            items = [
                PlaidAccountResponse(
                    id=row.id,
                    name=row.name,
                    mask=row.mask,
                    type=row.type,
                    subtype=row.subtype,
                    current_balance=row.current_balance,
                    available_balance=row.available_balance,
                    institution_name=item_names.get(row.plaid_item_id, "Banco"),
                )
                for row in rows
            ]
            return PlaidAccountsListResponse(items=items, count=len(items))

    def delete_account(self, user_id: str, account_id: str) -> MessageResponse:
        with self._open_session() as session:
            row = session.scalar(
                select(PlaidAccountRow).where(
                    PlaidAccountRow.id == account_id,
                    PlaidAccountRow.user_id == user_id,
                )
            )
            if row is None:
                raise AppError("Conta não encontrada", status_code=404)

            plaid_item_id = row.plaid_item_id
            session.execute(
                delete(FinanceTransactionRow).where(
                    FinanceTransactionRow.plaid_account_id == row.id,
                    FinanceTransactionRow.user_id == user_id,
                )
            )
            session.delete(row)
            session.flush()

            remaining = session.scalars(
                select(PlaidAccountRow).where(PlaidAccountRow.plaid_item_id == plaid_item_id)
            ).all()
            if not remaining:
                item = session.scalar(select(PlaidItemRow).where(PlaidItemRow.id == plaid_item_id))
                if item is not None:
                    session.delete(item)

            session.commit()
            return MessageResponse(message="Conta removida")

    def list_transactions(
        self,
        user_id: str,
        *,
        month: str | None = None,
        category: str | None = None,
        limit: int = 100,
    ) -> FinanceTransactionsListResponse:
        with self._open_session() as session:
            query = select(FinanceTransactionRow).where(FinanceTransactionRow.user_id == user_id)
            if month:
                year, mon = month.split("-", 1)
                start = date(int(year), int(mon), 1)
                if int(mon) == 12:
                    end = date(int(year) + 1, 1, 1)
                else:
                    end = date(int(year), int(mon) + 1, 1)
                query = query.where(
                    FinanceTransactionRow.date >= start,
                    FinanceTransactionRow.date < end,
                )
            if category:
                query = query.where(FinanceTransactionRow.category == category.strip().lower())
            rows = session.scalars(
                query.order_by(FinanceTransactionRow.date.desc(), FinanceTransactionRow.created_at.desc()).limit(
                    max(1, min(limit, 500))
                )
            ).all()
            account_names = self._account_name_map(session, user_id)
            items = [
                self._transaction_response(row, account_names.get(row.plaid_account_id))
                for row in rows
            ]
            return FinanceTransactionsListResponse(items=items, count=len(items))

    def create_manual_transaction(
        self,
        user_id: str,
        body: FinanceTransactionCreateRequest,
    ) -> FinanceTransactionResponse:
        tx_date = body.date or date.today()
        with self._open_session() as session:
            row = FinanceTransactionRow(
                id=str(uuid.uuid4()),
                user_id=user_id,
                amount=float(body.amount),
                date=tx_date,
                merchant_name=body.merchant_name,
                name=body.name.strip(),
                category=body.category.strip().lower(),
                subcategory=body.subcategory,
                is_manual=True,
                note=body.note,
                is_transfer=body.category.strip().lower() == "transfers",
            )
            session.add(row)
            session.commit()
            session.refresh(row)
            return self._transaction_response(row, None)

    def update_transaction(
        self,
        user_id: str,
        transaction_id: str,
        body: FinanceTransactionUpdateRequest,
    ) -> FinanceTransactionResponse:
        with self._open_session() as session:
            row = session.scalar(
                select(FinanceTransactionRow).where(
                    FinanceTransactionRow.id == transaction_id,
                    FinanceTransactionRow.user_id == user_id,
                )
            )
            if row is None:
                raise AppError("Transação não encontrada", status_code=404)
            if body.category is not None:
                row.category = body.category.strip().lower()
                row.is_transfer = row.category == "transfers"
            if body.subcategory is not None:
                row.subcategory = body.subcategory
            if body.note is not None:
                row.note = body.note
            session.commit()
            session.refresh(row)
            account_names = self._account_name_map(session, user_id)
            return self._transaction_response(row, account_names.get(row.plaid_account_id))

    def get_summary(self, user_id: str, month: str | None = None) -> FinanceSummaryResponse:
        month_key = month or _month_key()
        year, mon = month_key.split("-", 1)
        start = date(int(year), int(mon), 1)
        if int(mon) == 12:
            end = date(int(year) + 1, 1, 1)
        else:
            end = date(int(year), int(mon) + 1, 1)

        prev_start, prev_end = self._previous_month_range(start)

        with self._open_session() as session:
            current = self._aggregate_period(session, user_id, start, end)
            previous = self._aggregate_period(session, user_id, prev_start, prev_end)
            vs_last = current["expenses"] - previous["expenses"]
            return FinanceSummaryResponse(
                income_mtd=current["income"],
                expenses_mtd=current["expenses"],
                balance=current["income"] - current["expenses"],
                vs_last_month=vs_last,
                month=month_key,
                updated_at=datetime.now(UTC),
            )

    def get_budget(self, user_id: str, month: str | None = None) -> FinanceBudgetResponse:
        month_key = month or _month_key()
        with self._open_session() as session:
            budget_rows = session.scalars(
                select(FinanceBudgetRow).where(
                    FinanceBudgetRow.user_id == user_id,
                    FinanceBudgetRow.month == month_key,
                )
            ).all()
            spent_by_category = self._spent_by_category(session, user_id, month_key)
            categories = [
                BudgetCategoryResponse(
                    category=row.category,
                    limit=row.limit_amount,
                    spent=spent_by_category.get(row.category, 0.0),
                )
                for row in budget_rows
            ]
            return FinanceBudgetResponse(month=month_key, categories=categories)

    def upsert_budget(self, user_id: str, body: FinanceBudgetUpsertRequest) -> FinanceBudgetResponse:
        month_key = body.month.strip()
        with self._open_session() as session:
            session.execute(
                delete(FinanceBudgetRow).where(
                    FinanceBudgetRow.user_id == user_id,
                    FinanceBudgetRow.month == month_key,
                )
            )
            for item in body.categories:
                session.add(
                    FinanceBudgetRow(
                        id=str(uuid.uuid4()),
                        user_id=user_id,
                        category=item.category.strip().lower(),
                        month=month_key,
                        limit_amount=float(item.limit),
                    )
                )
            session.commit()
        return self.get_budget(user_id, month_key)

    def list_bills(self, user_id: str) -> FinanceBillsResponse:
        with self._open_session() as session:
            stored = session.scalars(
                select(FinanceRecurringRow)
                .where(FinanceRecurringRow.user_id == user_id, FinanceRecurringRow.is_active.is_(True))
                .order_by(FinanceRecurringRow.merchant_name)
            ).all()
            if stored:
                items = [
                    RecurringBillResponse(
                        id=row.id,
                        merchant_name=row.merchant_name,
                        amount=row.amount,
                        frequency=row.frequency,
                        next_date=row.next_date,
                        category=row.category,
                        is_active=row.is_active,
                    )
                    for row in stored
                ]
                monthly_total = sum(row.amount for row in stored if row.frequency == "monthly")
                return FinanceBillsResponse(items=items, monthly_total=monthly_total, count=len(items))

            detected = self._detect_recurring_bills(session, user_id)
            return FinanceBillsResponse(
                items=detected,
                monthly_total=sum(item.amount for item in detected),
                count=len(detected),
            )

    def _sync_item_by_plaid_id(self, plaid_item_id: str) -> None:
        with self._open_session() as session:
            item = session.scalar(select(PlaidItemRow).where(PlaidItemRow.item_id == plaid_item_id))
            if item is None:
                logger.info("Webhook Plaid para item desconhecido: %s", plaid_item_id)
                return
            self._sync_item_transactions(session, item)
            session.commit()

    def _sync_item_transactions(self, session: Session, item: PlaidItemRow) -> int:
        access_token = decrypt_secret(item.access_token_enc)
        cursor = item.cursor
        added = 0

        while True:
            payload = self._plaid.sync_transactions(access_token, cursor)
            account_map = self._plaid_account_map(session, item.id)
            for raw in payload.get("added") or []:
                self._upsert_plaid_transaction(session, item.user_id, account_map, raw)
                added += 1
            for raw in payload.get("modified") or []:
                self._upsert_plaid_transaction(session, item.user_id, account_map, raw)
            for raw in payload.get("removed") or []:
                tx_id = str(raw.get("transaction_id") or "")
                if tx_id:
                    session.execute(
                        delete(FinanceTransactionRow).where(
                            FinanceTransactionRow.plaid_transaction_id == tx_id,
                            FinanceTransactionRow.user_id == item.user_id,
                        )
                    )
            cursor = payload.get("next_cursor") or cursor
            if not payload.get("has_more"):
                break

        item.cursor = cursor
        item.last_synced_at = datetime.now(UTC)
        return added

    def _upsert_plaid_transaction(
        self,
        session: Session,
        user_id: str,
        account_map: dict[str, str],
        raw: dict[str, Any],
    ) -> None:
        tx_id = str(raw.get("transaction_id") or "")
        if not tx_id:
            return

        pfc = raw.get("personal_finance_category") or {}
        primary = pfc.get("primary") or (raw.get("category") or [None])[0]
        detailed = pfc.get("detailed")
        category, subcategory = normalize_plaid_category(
            str(primary) if primary else None,
            str(detailed) if detailed else None,
        )
        is_transfer = _is_transfer_category(str(primary) if primary else None, category)
        amount = _normalize_plaid_amount(float(raw.get("amount") or 0))
        plaid_account_id = account_map.get(str(raw.get("account_id") or ""))

        existing = session.scalar(
            select(FinanceTransactionRow).where(
                FinanceTransactionRow.plaid_transaction_id == tx_id,
                FinanceTransactionRow.user_id == user_id,
            )
        )
        tx_date = self._parse_date(raw.get("date"))
        merchant = raw.get("merchant_name") or raw.get("name")
        name = str(raw.get("name") or merchant or "Transação")

        if existing is None:
            session.add(
                FinanceTransactionRow(
                    id=str(uuid.uuid4()),
                    user_id=user_id,
                    plaid_account_id=plaid_account_id,
                    plaid_transaction_id=tx_id,
                    amount=amount,
                    date=tx_date,
                    merchant_name=str(merchant) if merchant else None,
                    name=name,
                    category=category,
                    subcategory=subcategory,
                    is_pending=bool(raw.get("pending")),
                    is_transfer=is_transfer,
                )
            )
        else:
            existing.amount = amount
            existing.date = tx_date
            existing.merchant_name = str(merchant) if merchant else None
            existing.name = name
            existing.category = category
            existing.subcategory = subcategory
            existing.is_pending = bool(raw.get("pending"))
            existing.is_transfer = is_transfer
            existing.plaid_account_id = plaid_account_id

    def _upsert_accounts(
        self,
        session: Session,
        item: PlaidItemRow,
        payload: dict[str, Any],
    ) -> None:
        for raw in payload.get("accounts") or []:
            account_id = str(raw.get("account_id") or "")
            if not account_id:
                continue
            balances = raw.get("balances") or {}
            existing = session.scalar(
                select(PlaidAccountRow).where(
                    PlaidAccountRow.plaid_item_id == item.id,
                    PlaidAccountRow.account_id == account_id,
                )
            )
            current = float(balances.get("current") or 0)
            available = balances.get("available")
            if existing is None:
                session.add(
                    PlaidAccountRow(
                        id=str(uuid.uuid4()),
                        plaid_item_id=item.id,
                        user_id=item.user_id,
                        account_id=account_id,
                        name=str(raw.get("name") or "Conta"),
                        mask=str(raw.get("mask") or ""),
                        type=str(raw.get("type") or "depository"),
                        subtype=str(raw.get("subtype") or "") or None,
                        current_balance=current,
                        available_balance=float(available) if available is not None else None,
                    )
                )
            else:
                existing.name = str(raw.get("name") or existing.name)
                existing.mask = str(raw.get("mask") or existing.mask)
                existing.type = str(raw.get("type") or existing.type)
                existing.subtype = str(raw.get("subtype") or "") or None
                existing.current_balance = current
                existing.available_balance = float(available) if available is not None else None

    @staticmethod
    def _institution_id(payload: dict[str, Any]) -> str | None:
        item = payload.get("item") or {}
        inst = item.get("institution_id")
        return str(inst) if inst else None

    def _resolve_institution_name(self, payload: dict[str, Any]) -> str:
        item = payload.get("item") or {}
        institution_id = item.get("institution_id")
        if institution_id:
            try:
                inst = self._plaid.fetch_institution(str(institution_id))
                return str(inst.get("institution", {}).get("name") or "Banco conectado")
            except Exception as exc:
                logger.warning("Falha ao buscar instituição Plaid: %s", exc)
        return "Banco conectado"

    @staticmethod
    def _parse_date(value: Any) -> date:
        if isinstance(value, date):
            return value
        if isinstance(value, str) and value:
            return date.fromisoformat(value[:10])
        return date.today()

    @staticmethod
    def _plaid_account_map(session: Session, plaid_item_id: str) -> dict[str, str]:
        rows = session.scalars(
            select(PlaidAccountRow).where(PlaidAccountRow.plaid_item_id == plaid_item_id)
        ).all()
        return {row.account_id: row.id for row in rows}

    @staticmethod
    def _account_name_map(session: Session, user_id: str) -> dict[str | None, str]:
        rows = session.scalars(
            select(PlaidAccountRow).where(PlaidAccountRow.user_id == user_id)
        ).all()
        return {row.id: row.name for row in rows}

    @staticmethod
    def _transaction_response(
        row: FinanceTransactionRow,
        account_name: str | None,
    ) -> FinanceTransactionResponse:
        return FinanceTransactionResponse(
            id=row.id,
            amount=row.amount,
            date=row.date,
            merchant_name=row.merchant_name,
            name=row.name,
            category=row.category,
            subcategory=row.subcategory,
            is_pending=row.is_pending,
            is_manual=row.is_manual,
            note=row.note,
            account_id=row.plaid_account_id,
            account_name=account_name,
        )

    @staticmethod
    def _previous_month_range(start: date) -> tuple[date, date]:
        if start.month == 1:
            prev_start = date(start.year - 1, 12, 1)
            prev_end = date(start.year, 1, 1)
        else:
            prev_start = date(start.year, start.month - 1, 1)
            prev_end = start
        return prev_start, prev_end

    @staticmethod
    def _aggregate_period(
        session: Session,
        user_id: str,
        start: date,
        end: date,
    ) -> dict[str, float]:
        rows = session.scalars(
            select(FinanceTransactionRow).where(
                FinanceTransactionRow.user_id == user_id,
                FinanceTransactionRow.date >= start,
                FinanceTransactionRow.date < end,
                FinanceTransactionRow.is_transfer.is_(False),
            )
        ).all()
        income = sum(row.amount for row in rows if row.amount > 0)
        expenses = sum(-row.amount for row in rows if row.amount < 0)
        return {"income": income, "expenses": expenses}

    @staticmethod
    def _spent_by_category(session: Session, user_id: str, month_key: str) -> dict[str, float]:
        year, mon = month_key.split("-", 1)
        start = date(int(year), int(mon), 1)
        if int(mon) == 12:
            end = date(int(year) + 1, 1, 1)
        else:
            end = date(int(year), int(mon) + 1, 1)
        rows = session.scalars(
            select(FinanceTransactionRow).where(
                FinanceTransactionRow.user_id == user_id,
                FinanceTransactionRow.date >= start,
                FinanceTransactionRow.date < end,
                FinanceTransactionRow.is_transfer.is_(False),
                FinanceTransactionRow.amount < 0,
            )
        ).all()
        totals: dict[str, float] = defaultdict(float)
        for row in rows:
            totals[row.category] += -row.amount
        return dict(totals)

    @staticmethod
    def _detect_recurring_bills(session: Session, user_id: str) -> list[RecurringBillResponse]:
        cutoff = date.today().replace(day=1)
        rows = session.scalars(
            select(FinanceTransactionRow).where(
                FinanceTransactionRow.user_id == user_id,
                FinanceTransactionRow.is_transfer.is_(False),
                FinanceTransactionRow.amount < 0,
                FinanceTransactionRow.merchant_name.is_not(None),
            )
            .order_by(FinanceTransactionRow.date.desc())
            .limit(500)
        ).all()

        grouped: dict[str, list[FinanceTransactionRow]] = defaultdict(list)
        for row in rows:
            key = (row.merchant_name or row.name).strip().lower()
            if key:
                grouped[key].append(row)

        bills: list[RecurringBillResponse] = []
        for merchant_key, items in grouped.items():
            if len(items) < 2:
                continue
            amounts = [-item.amount for item in items]
            avg = sum(amounts) / len(amounts)
            if avg <= 0:
                continue
            if any(abs(amount - avg) / avg > 0.1 for amount in amounts):
                continue
            latest = max(items, key=lambda item: item.date)
            bills.append(
                RecurringBillResponse(
                    id=str(uuid.uuid5(uuid.NAMESPACE_DNS, f"{user_id}:{merchant_key}")),
                    merchant_name=latest.merchant_name or latest.name,
                    amount=round(avg, 2),
                    frequency="monthly",
                    next_date=None,
                    category=latest.category,
                )
            )
        bills.sort(key=lambda item: item.amount, reverse=True)
        return bills[:12]


finance_service = FinanceService()
