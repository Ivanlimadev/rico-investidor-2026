from fastapi import APIRouter, Query

from app.services.dividend_calendar_service import dividend_calendar_service

router = APIRouter(prefix="/dividends", tags=["Dividendos"])


@router.get("/calendar")
async def dividend_calendar(
    market: str = Query(default="br", description="br = B3, us = EUA"),
    sort_by: str = Query(
        default="payment",
        description="payment = ordenar por data de pagamento, com = data com",
    ),
    days_ahead: int = Query(default=120, ge=7, le=365),
):
    """Agenda de dividendos no formato Investidor10 (ativo, data com, pagamento, valor)."""
    return await dividend_calendar_service.get_calendar(
        market=market,
        sort_by=sort_by,
        days_ahead=days_ahead,
    )
