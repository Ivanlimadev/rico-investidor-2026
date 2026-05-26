import 'package:rico_investidor/models/fii_models.dart';

class FiiSimulationResult {
  const FiiSimulationResult({
    required this.requestedYears,
    required this.effectiveYears,
    required this.startDate,
    required this.entryPrice,
    required this.shares,
    required this.finalShares,
    required this.initialAmount,
    required this.currentPrice,
    required this.currentValue,
    required this.dividendsReceived,
    required this.totalValue,
    required this.profit,
    required this.returnPct,
    required this.priceReturnPct,
    required this.dividendReturnPct,
    required this.paymentCount,
    required this.usedPartialHistory,
    required this.reinvestDividends,
  });

  final int requestedYears;
  final double effectiveYears;
  final DateTime startDate;
  final double entryPrice;
  final double shares;
  final double finalShares;
  final double initialAmount;
  final double currentPrice;
  final double currentValue;
  final double dividendsReceived;
  final double totalValue;
  final double profit;
  final double returnPct;
  final double priceReturnPct;
  final double dividendReturnPct;
  final int paymentCount;
  final bool usedPartialHistory;
  final bool reinvestDividends;
}

DateTime? parseFiiDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

int maxSimulatableYears(List<FiiHistoryPoint> history) {
  if (history.isEmpty) return 0;

  final dates = history
      .map((p) => parseFiiDate(p.referenceDate))
      .whereType<DateTime>()
      .toList()
    ..sort();

  if (dates.isEmpty) return 0;

  final months = _monthsBetween(dates.first, DateTime.now());
  return (months / 12).floor().clamp(0, 15);
}

double? priceAtDate(List<FiiHistoryPoint> history, DateTime target) {
  final sorted = history
      .map((p) => (date: parseFiiDate(p.referenceDate), price: p.closePrice))
      .where((e) => e.date != null && e.price != null && e.price! > 0)
      .toList()
    ..sort((a, b) => a.date!.compareTo(b.date!));

  double? last;
  for (final item in sorted) {
    if (item.date!.isAfter(target)) break;
    last = item.price;
  }
  return last;
}

FiiSimulationResult? simulateFiiInvestment({
  required double amount,
  required int years,
  required FiiDetail detail,
  required List<FiiHistoryPoint> history,
  required List<FiiDistributionPayment> payments,
  bool reinvestDividends = false,
}) {
  if (amount <= 0 || years <= 0) return null;

  final currentPrice = detail.closePrice;
  if (currentPrice == null || currentPrice <= 0) return null;

  final historyDates = history
      .map((p) => (date: parseFiiDate(p.referenceDate), point: p))
      .where((e) => e.date != null && e.point.closePrice != null && e.point.closePrice! > 0)
      .toList()
    ..sort((a, b) => a.date!.compareTo(b.date!));

  if (historyDates.isEmpty) return null;

  final earliest = historyDates.first.date!;
  final now = DateTime.now();
  final requestedStart = DateTime(now.year - years, now.month, now.day);

  final startDate = requestedStart.isBefore(earliest) ? earliest : requestedStart;
  final usedPartialHistory = startDate.isAfter(requestedStart);

  FiiHistoryPoint? entryPoint;
  for (final item in historyDates) {
    if (!item.date!.isAfter(startDate)) {
      entryPoint = item.point;
    } else {
      break;
    }
  }
  entryPoint ??= historyDates.first.point;

  final entryPrice = entryPoint.closePrice!;
  var shares = amount / entryPrice;
  final initialShares = shares;

  var totalDividends = 0.0;
  var paymentCount = 0;

  final sortedPayments = List<FiiDistributionPayment>.from(payments)
    ..sort((a, b) {
      final da = parseFiiDate(a.paymentDate ?? a.referenceDate);
      final db = parseFiiDate(b.paymentDate ?? b.referenceDate);
      if (da == null && db == null) return 0;
      if (da == null) return -1;
      if (db == null) return 1;
      return da.compareTo(db);
    });

  for (final payment in sortedPayments) {
    final date = parseFiiDate(payment.paymentDate ?? payment.referenceDate);
    final value = payment.valuePerShare;
    if (date == null || value == null || value <= 0) continue;
    if (date.isBefore(startDate)) continue;

    final dividend = value * shares;
    totalDividends += dividend;
    paymentCount++;

    if (reinvestDividends) {
      final buyPrice = priceAtDate(history, date) ?? currentPrice;
      if (buyPrice > 0) {
        shares += dividend / buyPrice;
      }
    }
  }

  final finalShares = shares;
  final currentValue = finalShares * currentPrice;
  final totalValue = reinvestDividends ? currentValue : currentValue + totalDividends;
  final profit = totalValue - amount;
  final returnPct = amount == 0 ? 0.0 : (profit / amount) * 100;

  final priceOnlyValue = initialShares * currentPrice;
  final priceReturnPct = amount == 0 ? 0.0 : ((priceOnlyValue - amount) / amount) * 100;
  final dividendReturnPct = amount == 0 ? 0.0 : (totalDividends / amount) * 100;
  final effectiveYears = _monthsBetween(startDate, now) / 12.0;

  return FiiSimulationResult(
    requestedYears: years,
    effectiveYears: effectiveYears,
    startDate: startDate,
    entryPrice: entryPrice,
    shares: initialShares,
    finalShares: finalShares,
    initialAmount: amount,
    currentPrice: currentPrice,
    currentValue: currentValue,
    dividendsReceived: totalDividends,
    totalValue: totalValue,
    profit: profit,
    returnPct: returnPct,
    priceReturnPct: priceReturnPct,
    dividendReturnPct: dividendReturnPct,
    paymentCount: paymentCount,
    usedPartialHistory: usedPartialHistory,
    reinvestDividends: reinvestDividends,
  );
}

int _monthsBetween(DateTime start, DateTime end) {
  return (end.year - start.year) * 12 + (end.month - start.month);
}
