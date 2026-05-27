import 'package:rico_investidor/features/fii/utils/fii_simulation.dart';
import 'package:rico_investidor/models/fii_models.dart';

class AssetReturnItem {
  const AssetReturnItem({
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

const assetReturnPeriods = [
  ('1M', 1),
  ('3M', 3),
  ('1A', 12),
  ('2A', 24),
  ('3A', 36),
  ('5A', 60),
  ('10A', 120),
];

String assetReturnPeriodDisplayLabel(String code) {
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

DateTime subtractMonths(DateTime date, int months) {
  var year = date.year;
  var month = date.month - months;
  while (month <= 0) {
    month += 12;
    year -= 1;
  }
  final lastDay = DateTime(year, month + 1, 0).day;
  final day = date.day.clamp(1, lastDay);
  return DateTime(year, month, day);
}

({DateTime date, double price})? pricePointAtDate({
  required DateTime target,
  List<FiiHistoryPoint> history = const [],
  List<FiiCandleBar> candles = const [],
}) {
  final fromCandles = _pricePointFromCandles(candles, target);
  final fromHistory = _pricePointFromHistory(history, target);

  if (fromCandles != null && fromHistory != null) {
    final candleGap = target.difference(fromCandles.date).inDays.abs();
    final historyGap = target.difference(fromHistory.date).inDays.abs();
    return candleGap <= historyGap ? fromCandles : fromHistory;
  }

  return fromCandles ?? fromHistory;
}

({DateTime date, double price})? _pricePointFromCandles(
  List<FiiCandleBar> candles,
  DateTime target,
) {
  if (candles.isEmpty) return null;

  final sorted = List<FiiCandleBar>.from(candles)
    ..sort((a, b) => a.tradeDate.compareTo(b.tradeDate));

  ({DateTime date, double price})? last;
  for (final bar in sorted) {
    if (bar.close <= 0) continue;
    final date = parseFiiDate(bar.tradeDate);
    if (date == null) continue;
    if (date.isAfter(target)) break;
    last = (date: date, price: bar.close);
  }
  return last;
}

({DateTime date, double price})? _pricePointFromHistory(
  List<FiiHistoryPoint> history,
  DateTime target,
) {
  if (history.isEmpty) return null;

  final sorted = history
      .map((p) => (date: parseFiiDate(p.referenceDate), price: p.closePrice))
      .where((e) => e.date != null && e.price != null && e.price! > 0)
      .toList()
    ..sort((a, b) => a.date!.compareTo(b.date!));

  ({DateTime date, double price})? last;
  for (final item in sorted) {
    if (item.date!.isAfter(target)) break;
    last = (date: item.date!, price: item.price!);
  }
  return last;
}

double dividendsPerShareSince(
  List<FiiDistributionPayment> payments,
  DateTime since,
) {
  var total = 0.0;
  for (final payment in payments) {
    final date = parseFiiDate(payment.paymentDate ?? payment.referenceDate);
    final value = payment.valuePerShare;
    if (date == null || value == null || value <= 0) continue;
    if (date.isBefore(since)) continue;
    total += value;
  }
  return total;
}

List<AssetReturnItem> computeAssetReturns({
  required double? currentPrice,
  List<FiiHistoryPoint> history = const [],
  List<FiiCandleBar> candles = const [],
  List<FiiDistributionPayment> payments = const [],
}) {
  return assetReturnPeriods.map((entry) {
    final (label, months) = entry;
    final result = _returnForMonths(
      currentPrice: currentPrice,
      history: history,
      candles: candles,
      payments: payments,
      monthsBack: months,
    );
    return AssetReturnItem(
      label: label,
      monthsBack: months,
      returnPct: result?.totalPct,
      priceReturnPct: result?.pricePct,
      dividendReturnPct: result?.dividendPct,
    );
  }).toList();
}

({double totalPct, double pricePct, double dividendPct})? _returnForMonths({
  required double? currentPrice,
  required List<FiiHistoryPoint> history,
  required List<FiiCandleBar> candles,
  required List<FiiDistributionPayment> payments,
  required int monthsBack,
}) {
  if (currentPrice == null || currentPrice <= 0) return null;
  if (history.isEmpty && candles.isEmpty) return null;

  final now = DateTime.now();
  final targetDate = subtractMonths(now, monthsBack);
  final point = pricePointAtDate(
    target: targetDate,
    history: history,
    candles: candles,
  );
  if (point == null) return null;

  final spanMonths = _monthsBetween(point.date, now);
  if (spanMonths + 1 < monthsBack) return null;

  final pastPrice = point.price;
  final dividendsPerShare = dividendsPerShareSince(payments, point.date);

  final pricePct = ((currentPrice - pastPrice) / pastPrice) * 100;
  final dividendPct = (dividendsPerShare / pastPrice) * 100;
  final totalPct = pricePct + dividendPct;

  return (totalPct: totalPct, pricePct: pricePct, dividendPct: dividendPct);
}

int _monthsBetween(DateTime start, DateTime end) {
  return (end.year - start.year) * 12 + (end.month - start.month);
}
