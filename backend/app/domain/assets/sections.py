from app.clients.brapi.models import StockFundamentals, StockQuoteDetailResponse
from app.providers.registry import AssetClass


def stock_sections(stock: StockQuoteDetailResponse, asset_class: AssetClass) -> list[str]:
    sections = ["quote"]

    if stock.candles:
        sections.append("chart")

    profile = stock.profile
    if any(
        value is not None
        for value in (
            profile.sector,
            profile.industry,
            profile.summary,
            profile.logo_url,
            profile.website,
        )
    ):
        sections.append("profile")

    if _has_fundamentals(stock.fundamentals):
        sections.append("fundamentals")

    dividends = stock.dividends
    if dividends.count > 0 or dividends.payments or dividends.corporate_actions:
        sections.append("dividends")
        if dividends.corporate_actions:
            sections.append("corporate_actions")

    if asset_class == AssetClass.STOCK_BR and _has_fundamentals(stock.fundamentals):
        sections.append("financials")

    return sections


def stock_notes(stock: StockQuoteDetailResponse, asset_class: AssetClass) -> list[str]:
    notes: list[str] = []
    dividends = stock.dividends

    if dividends.provider == "bolsai":
        notes.append(
            "Proventos, DY 12m e gráfico anual de dividendos: fonte Bolsai (CVM/B3)."
        )
    if stock.provider == "hybrid":
        notes.append(
            "Cotação e perfil: Brapi. Proventos, fundamentos TTM e histórico longo: Bolsai."
        )
    if asset_class == AssetClass.ETF_BR:
        notes.append(
            "ETF: cotação e histórico via Brapi; proventos via Bolsai quando disponíveis."
        )
    elif asset_class == AssetClass.BDR and not _has_fundamentals(stock.fundamentals):
        notes.append(
            "BDR: indicadores fundamentalistas podem estar indisponíveis para este ticker."
        )
    elif asset_class == AssetClass.STOCK_BR and not _has_fundamentals(stock.fundamentals):
        notes.append(
            "Fundamentos indisponíveis no provedor para este ticker no momento."
        )

    if not stock.candles:
        notes.append("Histórico de pregão indisponível no momento.")

    return notes


def _has_fundamentals(fundamentals: StockFundamentals) -> bool:
    return any(
        value is not None
        for key, value in fundamentals.model_dump().items()
        if key != "provider"
    )
