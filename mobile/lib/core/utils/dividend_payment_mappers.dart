import 'package:rico_investidor/features/global_markets/models/global_market_models.dart';
import 'package:rico_investidor/features/global_markets/utils/global_stock_chart_prices.dart';
import 'package:rico_investidor/models/market_series_models.dart';

List<QuoteCandleBar> candleBarsFromGlobal(List<GlobalStockCandleDto> candles) {
  return candles
      .map((candle) {
        final close = returnCloseForGlobalStockCandle(candle, candles);
        if (close <= 0) return null;
        return QuoteCandleBar(
          tradeDate: candle.date,
          open: candle.open ?? close,
          high: candle.high ?? close,
          low: candle.low ?? close,
          close: close,
          volume: candle.volume,
        );
      })
      .whereType<QuoteCandleBar>()
      .toList();
}

List<DistributionPayment> paymentsFromGlobalDividends(
  List<GlobalStockDividendDto> dividends, {
  bool includeProjected = false,
}) {
  return dividends
      .where((item) => item.amount > 0 && (includeProjected || !item.isProjected))
      .map(
        (item) => DistributionPayment(
          referenceDate: item.effectiveComDate ?? item.effectiveExDate,
          paymentDate: item.effectivePaymentDate ?? item.effectiveExDate,
          valuePerShare: item.amount,
          label: item.dividendType,
        ),
      )
      .toList();
}
