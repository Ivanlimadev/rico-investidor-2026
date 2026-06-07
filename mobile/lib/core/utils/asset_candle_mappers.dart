import 'package:rico_investidor/features/crypto/models/crypto_models.dart';
import 'package:rico_investidor/models/market_series_models.dart';

List<QuoteCandleBar> candleBarsFromCrypto(List<CryptoCandleDto> candles) {
  return candles
      .map((candle) {
        if (candle.close <= 0) return null;
        return QuoteCandleBar(
          tradeDate: candle.date,
          open: candle.open,
          high: candle.high,
          low: candle.low,
          close: candle.close,
          volume: candle.volume,
        );
      })
      .whereType<QuoteCandleBar>()
      .toList();
}
