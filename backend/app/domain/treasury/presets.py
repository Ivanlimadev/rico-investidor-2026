"""Títulos do Tesouro exibidos por padrão e filtros da tela Explorar."""

FEATURED_TREASURY_SYMBOLS: tuple[str, ...] = (
    "tesouro-selic-01032031",
    "tesouro-prefixado-com-juros-semestrais-01012037",
    "tesouro-ipca-com-juros-semestrais-15082060",
    "tesouro-prefixado-01012028",
    "tesouro-ipca-15082030",
    "tesouro-selic-01092029",
)

TREASURY_EXPLORE_GROUPS: dict[str, str | None] = {
    "all": None,
    "selic": "selic",
    "prefixado": "prefixado",
    "ipca": "ipca",
    "igpm": "igpm",
}
