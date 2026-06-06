import 'package:rico_investidor/features/fii/utils/fii_quote_chart.dart';
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

/// Períodos por pregões (~21/mês) — alinhado ao backend e ao Investidor10.
const assetReturnSessions = [
  ('1M', 21),
  ('3M', 63),
  ('1A', 252),
  ('2A', 504),
  ('3A', 756),
  ('5A', 1260),
];

@Deprecated('Use assetReturnSessions')
const assetReturnPeriods = assetReturnSessions;

String assetReturnPeriodDisplayLabel(String code) {
  return switch (code) {
    '1M' => '1 mês',
    '3M' => '3 meses',
    'YTD' => 'No ano',
    '1A' => '1 ano',
    '2A' => '2 anos',
    '3A' => '3 anos',
    '5A' => '5 anos',
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

/// Série de preços ordenada — evita re-sort a cada consulta na simulação.
class AssetPriceTimeline {
  AssetPriceTimeline._(this._points);

  final List<({DateTime date, double price})> _points;

  factory AssetPriceTimeline.from({
    List<FiiCandleBar> candles = const [],
    List<FiiHistoryPoint> history = const [],
  }) {
    final byDay = <String, ({DateTime date, double price, bool fromCandle})>{};

    void add(DateTime date, double price, {required bool fromCandle}) {
      final key = '${date.year}-${date.month}-${date.day}';
      final existing = byDay[key];
      if (existing == null) {
        byDay[key] = (date: date, price: price, fromCandle: fromCandle);
        return;
      }
      if (fromCandle) {
        byDay[key] = (date: date, price: price, fromCandle: true);
      }
    }

    for (final bar in candles) {
      if (bar.close <= 0) continue;
      final date = parseFiiDate(bar.tradeDate);
      if (date == null) continue;
      add(date, bar.close, fromCandle: true);
    }

    for (final point in history) {
      final date = parseFiiDate(point.referenceDate);
      final price = point.closePrice;
      if (date == null || price == null || price <= 0) continue;
      add(date, price, fromCandle: false);
    }

    final points = byDay.values
        .map((entry) => (date: entry.date, price: entry.price))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return AssetPriceTimeline._(points);
  }

  bool get isEmpty => _points.isEmpty;

  ({DateTime date, double price})? get earliest =>
      _points.isEmpty ? null : _points.first;

  ({DateTime date, double price})? atOrBefore(DateTime target) {
    if (_points.isEmpty) return null;

    var lo = 0;
    var hi = _points.length - 1;
    var best = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (!_points[mid].date.isAfter(target)) {
        best = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    if (best < 0) return null;
    final point = _points[best];
    return (date: point.date, price: point.price);
  }
}

({DateTime date, double price})? pricePointAtDate({
  required DateTime target,
  List<FiiHistoryPoint> history = const [],
  List<FiiCandleBar> candles = const [],
  AssetPriceTimeline? timeline,
}) {
  if (timeline != null) {
    return timeline.atOrBefore(target);
  }

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
  final sorted = dedupeQuoteBarsByDate([
    ...candles,
    if (history.isNotEmpty)
      for (final point in history)
        if (point.referenceDate != null && (point.closePrice ?? 0) > 0)
          FiiCandleBar(
            tradeDate: point.referenceDate!,
            open: point.closePrice!,
            high: point.closePrice!,
            low: point.closePrice!,
            close: point.closePrice!,
          ),
  ]);

  if (currentPrice == null || currentPrice <= 0 || sorted.isEmpty) {
    return const [];
  }

  final latest = sorted.last.close > 0 ? sorted.last.close : currentPrice;
  final endPrice = currentPrice > 0 ? currentPrice : latest;

  return assetReturnSessions.map((entry) {
    final (label, sessions) = entry;
    final result = _returnForSessions(
      endPrice: endPrice,
      sorted: sorted,
      payments: payments,
      sessionsBack: sessions,
    );
    return AssetReturnItem(
      label: label,
      monthsBack: (sessions / 21).round().clamp(1, 60),
      returnPct: result?.totalPct,
      priceReturnPct: result?.pricePct,
      dividendReturnPct: result?.dividendPct,
    );
  }).toList();
}

({double totalPct, double pricePct, double dividendPct})? _returnForSessions({
  required double endPrice,
  required List<FiiCandleBar> sorted,
  required List<FiiDistributionPayment> payments,
  required int sessionsBack,
}) {
  if (sorted.length <= sessionsBack) return null;

  final startBar = sorted[sorted.length - 1 - sessionsBack];
  final startPrice = startBar.close;
  if (startPrice <= 0) return null;

  final startDate = parseTradeDate(startBar.tradeDate);
  if (startDate == null) return null;

  final dividendsPerShare = dividendsPerShareSince(payments, startDate);
  final pricePct = ((endPrice - startPrice) / startPrice) * 100;
  final dividendPct = (dividendsPerShare / startPrice) * 100;
  final totalPct = pricePct + dividendPct;

  return (totalPct: totalPct, pricePct: pricePct, dividendPct: dividendPct);
}
