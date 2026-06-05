import 'package:rico_investidor/features/global_markets/models/global_market_models.dart';
import 'package:rico_investidor/models/fii_models.dart';

List<FiiCandleBar> candleBarsFromGlobal(List<GlobalStockCandleDto> candles) {
  return candles
      .map((candle) {
        final close = candle.chartClose;
        if (close <= 0) return null;
        return FiiCandleBar(
          tradeDate: candle.date,
          open: candle.open ?? close,
          high: candle.high ?? close,
          low: candle.low ?? close,
          close: close,
          volume: candle.volume,
        );
      })
      .whereType<FiiCandleBar>()
      .toList();
}

List<FiiDistributionPayment> paymentsFromGlobalDividends(
  List<GlobalStockDividendDto> dividends,
) {
  return dividends
      .where((item) => !item.isProjected && item.amount > 0)
      .map(
        (item) => FiiDistributionPayment(
          referenceDate: item.effectiveComDate ?? item.effectiveExDate,
          paymentDate: item.effectivePaymentDate ?? item.effectiveExDate,
          valuePerShare: item.amount,
          label: item.dividendType,
        ),
      )
      .toList();
}
