import 'package:rico_investidor/features/crypto/models/crypto_models.dart';
import 'package:rico_investidor/features/currency/models/currency_models.dart';
import 'package:rico_investidor/features/indices/models/indices_models.dart';
import 'package:rico_investidor/features/treasury/models/treasury_models.dart';
import 'package:rico_investidor/models/fii_models.dart';

List<FiiCandleBar> candleBarsFromCrypto(List<CryptoCandleDto> candles) {
  return candles
      .map((candle) {
        if (candle.close <= 0) return null;
        return FiiCandleBar(
          tradeDate: candle.date,
          open: candle.open,
          high: candle.high,
          low: candle.low,
          close: candle.close,
          volume: candle.volume,
        );
      })
      .whereType<FiiCandleBar>()
      .toList();
}

List<FiiHistoryPoint> historyFromCurrency(List<CurrencyHistoryPointDto> history) {
  return history
      .where((point) => point.value > 0)
      .map((point) => FiiHistoryPoint(referenceDate: point.date, closePrice: point.value))
      .toList();
}

List<FiiHistoryPoint> historyFromIndex(List<IndexHistoryPointDto> history) {
  return history
      .where((point) => point.value > 0)
      .map((point) => FiiHistoryPoint(referenceDate: point.date, closePrice: point.value))
      .toList();
}

List<FiiHistoryPoint> historyFromTreasury(List<TreasuryHistoryPointDto> history) {
  return history
      .map((point) {
        final price = point.displayPrice;
        if (price == null || price <= 0) return null;
        return FiiHistoryPoint(referenceDate: point.date, closePrice: price);
      })
      .whereType<FiiHistoryPoint>()
      .toList();
}
