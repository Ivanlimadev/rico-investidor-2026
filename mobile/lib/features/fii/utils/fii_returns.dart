import 'package:rico_investidor/core/utils/asset_returns.dart';
import 'package:rico_investidor/features/fii/utils/fii_ohlc.dart';
import 'package:rico_investidor/models/fii_models.dart';

typedef FiiReturnItem = AssetReturnItem;

const fiiReturnPeriods = assetReturnPeriods;

String fiiReturnPeriodDisplayLabel(String code) => assetReturnPeriodDisplayLabel(code);

/// Variação diária — candles diários quando disponíveis; senão histórico mensal.
double? dailyReturnPct(
  List<FiiHistoryPoint> history,
  double? currentPrice, {
  List<FiiCandleBar> candles = const [],
}) {
  if (currentPrice == null || currentPrice <= 0) return null;

  if (candles.length >= 2) {
    final sorted = List<FiiCandleBar>.from(candles)
      ..sort((a, b) => a.tradeDate.compareTo(b.tradeDate));
    final valid = sorted.where((b) => b.close > 0).toList();
    if (valid.length >= 2) {
      final previous = valid[valid.length - 2].close;
      return ((currentPrice - previous) / previous) * 100;
    }
  }

  final sorted = sortHistoryPoints(history).where((p) => p.closePrice != null && p.closePrice! > 0).toList();
  if (sorted.length < 2) return null;

  final previous = sorted[sorted.length - 2].closePrice!;
  return ((currentPrice - previous) / previous) * 100;
}

List<FiiReturnItem> computeFiiReturns({
  required List<FiiHistoryPoint> history,
  required double? currentPrice,
  List<FiiDistributionPayment> payments = const [],
  List<FiiCandleBar> candles = const [],
}) {
  return computeAssetReturns(
    currentPrice: currentPrice,
    history: history,
    candles: candles,
    payments: payments,
  );
}
