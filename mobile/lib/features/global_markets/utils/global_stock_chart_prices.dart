import 'package:rico_investidor/features/global_markets/models/global_market_models.dart';

/// Há diferença material entre fechamento nominal e ajustado (ex.: antes de splits).
bool globalStockCandleHasSplitAdjustment(GlobalStockCandleDto candle) {
  final adj = candle.adjClose;
  if (adj == null || adj <= 0) return false;
  return (adj - candle.close).abs() > 0.001;
}

/// Série possui `adj_close` utilizável.
bool hasGlobalStockAdjustedChartData(List<GlobalStockCandleDto> candles) =>
    candles.any((c) => c.adjClose != null && c.adjClose! > 0);

/// Série precisa de preço ajustado em gráficos/rentabilidade de longo prazo.
bool globalStockSeriesNeedsAdjustedPrices(List<GlobalStockCandleDto> candles) =>
    candles.any(globalStockCandleHasSplitAdjustment);

/// Preço para gráfico ou analytics — `adj_close` evita “despenques” após splits.
double chartCloseForGlobalStockCandle(
  GlobalStockCandleDto candle, {
  required bool useAdjusted,
}) {
  if (useAdjusted) {
    final adj = candle.adjClose;
    if (adj != null && adj > 0) return adj;
  }
  return candle.chartClose;
}

/// Estado efetivo do modo ajustado (respeita preferência do usuário).
bool effectiveGlobalStockChartAdjusted({
  required bool useAdjusted,
  required List<GlobalStockCandleDto> candles,
}) => useAdjusted && hasGlobalStockAdjustedChartData(candles);

/// Fechamento consistente para rentabilidade/simulação em toda a série.
double returnCloseForGlobalStockCandle(
  GlobalStockCandleDto candle,
  List<GlobalStockCandleDto> series,
) =>
    chartCloseForGlobalStockCandle(
      candle,
      useAdjusted: globalStockSeriesNeedsAdjustedPrices(series),
    );
