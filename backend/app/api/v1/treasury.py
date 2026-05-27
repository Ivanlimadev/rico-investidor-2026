from fastapi import APIRouter, Query

from app.services.treasury_service import treasury_service

router = APIRouter(prefix="/treasury", tags=["treasury"])


@router.get("")
async def list_featured_treasury_bonds():
    """Principais títulos do Tesouro — fonte: Brapi."""
    bonds = await treasury_service.list_featured()
    return {"items": bonds, "count": len(bonds), "provider": "brapi"}


@router.get("/explore")
async def explore_treasury_bonds(
    search: str | None = Query(default=None, min_length=1, max_length=64),
    group: str = Query(default="all", pattern=r"^[a-z_]+$"),
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=30, ge=1, le=50),
):
    """Títulos paginados com taxas e preços — para tela Explorar."""
    return await treasury_service.explore(search=search, group=group, page=page, limit=limit)


@router.get("/count")
async def count_treasury_bonds():
    return {"total": await treasury_service.count_bonds(), "provider": "brapi"}


@router.get("/{symbol}")
async def get_treasury_bond(symbol: str):
    """Indicadores atuais de um título (ex.: tesouro-selic-01032031)."""
    return await treasury_service.get_bond(symbol)


@router.get("/{symbol}/history")
async def get_treasury_history(
    symbol: str,
    limit: int = Query(default=252, ge=1, le=5000),
    start: str | None = Query(default=None, pattern=r"^\d{4}-\d{2}-\d{2}$"),
    end: str | None = Query(default=None, pattern=r"^\d{4}-\d{2}-\d{2}$"),
):
    """Histórico diário de taxas e preços — fonte: Brapi."""
    return await treasury_service.get_history(symbol, limit=limit, start=start, end=end)
