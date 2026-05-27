from fastapi import APIRouter, Query

from app.services.currency_service import currency_service

router = APIRouter(prefix="/currency", tags=["currency"])


@router.get("")
async def list_featured_currencies():
    """Principais pares contra BRL — fonte: Brapi."""
    return await currency_service.list_featured()


@router.get("/explore")
async def explore_currencies(
    search: str | None = Query(default=None, min_length=1, max_length=32),
    group: str = Query(default="all", pattern=r"^[a-z_]+$"),
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=30, ge=1, le=50),
):
    """Pares BRL paginados com cotação — para tela Explorar."""
    return await currency_service.explore(search=search, group=group, page=page, limit=limit)


@router.get("/pairs")
async def list_currency_pairs(
    search: str | None = Query(default=None, min_length=1, max_length=32),
    brl_only: bool = Query(default=True),
):
    """Pares disponíveis na Brapi."""
    return await currency_service.list_pairs(search=search, brl_only=brl_only)


@router.get("/count")
async def count_currency_pairs():
    return {"total": await currency_service.count_brl_pairs(), "provider": "brapi"}


@router.get("/{pair}")
async def get_currency_rate(pair: str):
    """Cotação atual de um par (ex.: USD-BRL)."""
    return await currency_service.get_rate(pair)


@router.get("/{pair}/history")
async def get_currency_history(
    pair: str,
    limit: int = Query(default=252, ge=1, le=5000),
    start: str | None = Query(default=None, pattern=r"^\d{4}-\d{2}-\d{2}$"),
    end: str | None = Query(default=None, pattern=r"^\d{4}-\d{2}-\d{2}$"),
):
    """Histórico PTAX diário — fonte: Brapi."""
    return await currency_service.get_history(pair, limit=limit, start=start, end=end)
