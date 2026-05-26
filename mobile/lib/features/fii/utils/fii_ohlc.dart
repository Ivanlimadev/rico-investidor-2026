import 'package:rico_investidor/models/fii_models.dart';

List<FiiHistoryPoint> sortHistoryPoints(List<FiiHistoryPoint> history) {
  return List<FiiHistoryPoint>.from(history)
    ..sort((a, b) => (a.referenceDate ?? '').compareTo(b.referenceDate ?? ''));
}

double? priceChangePct(List<FiiHistoryPoint> history, double? currentPrice) {
  if (currentPrice == null || history.length < 2) return null;

  final sorted = sortHistoryPoints(history);
  final previous = sorted[sorted.length - 2].closePrice;
  if (previous == null || previous == 0) return null;

  return ((currentPrice - previous) / previous) * 100;
}
