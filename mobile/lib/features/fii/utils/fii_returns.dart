import 'package:rico_investidor/features/fii/utils/fii_ohlc.dart';
import 'package:rico_investidor/features/fii/utils/fii_simulation.dart';
import 'package:rico_investidor/models/fii_models.dart';

class FiiReturnItem {
  const FiiReturnItem({
    required this.label,
    required this.monthsBack,
    this.returnPct,
    this.priceReturnPct,
    this.dividendReturnPct,
  });

  final String label;
  final int monthsBack;
  final double? returnPct;
  final double? priceReturnPct;
  final double? dividendReturnPct;

  bool get hasData => returnPct != null;
}

const fiiReturnPeriods = [
  ('1M', 1),
  ('3M', 3),
  ('1A', 12),
  ('2A', 24),
  ('3A', 36),
  ('5A', 60),
  ('10A', 120),
];

String fiiReturnPeriodDisplayLabel(String code) {
  return switch (code) {
    '1M' => '1 mês',
    '3M' => '3 meses',
    '1A' => '1 ano',
    '2A' => '2 anos',
    '3A' => '3 anos',
    '5A' => '5 anos',
    '10A' => '10 anos',
    _ => code,
  };
}

/// Variação da cotação — melhor proxy disponível com dados mensais Bolsai.
double? dailyReturnPct(List<FiiHistoryPoint> history, double? currentPrice) {
  if (currentPrice == null || currentPrice <= 0) return null;

  final sorted = sortHistoryPoints(history).where((p) => p.closePrice != null && p.closePrice! > 0).toList();
  if (sorted.length < 2) return null;

  final previous = sorted[sorted.length - 2].closePrice!;
  return ((currentPrice - previous) / previous) * 100;
}

List<FiiReturnItem> computeFiiReturns({
  required List<FiiHistoryPoint> history,
  required double? currentPrice,
  List<FiiDistributionPayment> payments = const [],
}) {
  return fiiReturnPeriods.map((entry) {
    final (label, months) = entry;
    final result = _returnForMonths(
      history: history,
      currentPrice: currentPrice,
      payments: payments,
      monthsBack: months,
    );
    return FiiReturnItem(
      label: label,
      monthsBack: months,
      returnPct: result?.totalPct,
      priceReturnPct: result?.pricePct,
      dividendReturnPct: result?.dividendPct,
    );
  }).toList();
}

({double totalPct, double pricePct, double dividendPct})? _returnForMonths({
  required List<FiiHistoryPoint> history,
  required double? currentPrice,
  required List<FiiDistributionPayment> payments,
  required int monthsBack,
}) {
  if (currentPrice == null || currentPrice <= 0) return null;

  final sorted = sortHistoryPoints(history).where((p) => p.closePrice != null && p.closePrice! > 0).toList();
  if (sorted.length < 2) return null;

  final pastIndex = sorted.length - 1 - monthsBack;
  if (pastIndex < 0) return null;

  final pastPoint = sorted[pastIndex];
  final pastPrice = pastPoint.closePrice!;
  final pastDate = parseFiiDate(pastPoint.referenceDate);
  if (pastDate == null) return null;

  var dividendsPerShare = 0.0;
  for (final payment in payments) {
    final date = parseFiiDate(payment.paymentDate ?? payment.referenceDate);
    final value = payment.valuePerShare;
    if (date == null || value == null || value <= 0) continue;
    if (date.isBefore(pastDate)) continue;
    dividendsPerShare += value;
  }

  final pricePct = ((currentPrice - pastPrice) / pastPrice) * 100;
  final dividendPct = (dividendsPerShare / pastPrice) * 100;
  final totalPct = pricePct + dividendPct;

  return (totalPct: totalPct, pricePct: pricePct, dividendPct: dividendPct);
}
