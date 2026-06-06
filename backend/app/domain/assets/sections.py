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

    if asset_class == AssetClass.BDR and not _has_fundamentals(stock.fundamentals):
        notes.append(
            "BDR: indicadores fundamentalistas podem estar indisponíveis para este ticker."
        )
    elif asset_class == AssetClass.STOCK_BR and not _has_fundamentals(stock.fundamentals):
        notes.append(
            "Fundamentos indisponíveis para este ticker no momento."
        )

    if not stock.candles:
        notes.append("Histórico de pregão indisponível no momento.")
    elif len(stock.candles) < 252:
        notes.append(
            f"Histórico parcial: {len(stock.candles)} pregões carregados (menos de 1 ano)."
        )
    elif stock.provider in {"hybrid", "bolsai"}:
        notes.append(
            "Histórico longo ajustado por splits e proventos."
        )

    if stock.returns and not any(row.return_pct is not None for row in stock.returns):
        notes.append("Rentabilidade indisponível para os períodos solicitados.")

    if asset_class == AssetClass.STOCK_BR and stock.provider == "brapi":
        notes.append(
            "Indicadores e proventos podem divergir do Investidor10 — configure BOLSAI_API_KEY no servidor."
        )
    elif asset_class == AssetClass.STOCK_BR and stock.provider in {"hybrid", "bolsai"}:
        notes.append(
            "Cotação, proventos e fundamentos alinhados à Bolsai (metodologia Investidor10)."
        )

    return notes


def _has_fundamentals(fundamentals: StockFundamentals) -> bool:
    return any(
        value is not None
        for key, value in fundamentals.model_dump().items()
        if key != "provider"
    )
