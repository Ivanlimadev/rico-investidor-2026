import 'package:rico_investidor/core/utils/asset_returns.dart';
import 'package:rico_investidor/features/fii/utils/fii_simulation.dart';
import 'package:rico_investidor/models/fii_models.dart';

/// Períodos anuais (legado / grid).
const whatIfInvestmentPeriodYears = [1, 2, 3, 5, 10, 15];

/// Períodos do card — inclui meses para histórico curto (ex.: Marketstack 365d).
const whatIfInvestmentPeriodOptions = <WhatIfInvestmentPeriod>[
  WhatIfInvestmentPeriod.months(1),
  WhatIfInvestmentPeriod.months(3),
  WhatIfInvestmentPeriod.months(6),
  WhatIfInvestmentPeriod.years(1),
  WhatIfInvestmentPeriod.years(2),
  WhatIfInvestmentPeriod.years(3),
  WhatIfInvestmentPeriod.years(5),
  WhatIfInvestmentPeriod.years(10),
  WhatIfInvestmentPeriod.years(15),
];

class WhatIfInvestmentPeriod {
  const WhatIfInvestmentPeriod._({required this.years, required this.months});

  const WhatIfInvestmentPeriod.years(int years) : this._(years: years, months: 0);

  const WhatIfInvestmentPeriod.months(int months) : this._(years: 0, months: months);

  final int years;
  final int months;

  bool get isYearBased => years > 0;

  bool get isMonthBased => months > 0;

  String get label {
    if (isMonthBased) {
      return months == 1 ? '1 mês' : '$months meses';
    }
    return years == 1 ? '1 ano' : '$years anos';
  }

  @override
  bool operator ==(Object other) {
    return other is WhatIfInvestmentPeriod && other.years == years && other.months == months;
  }

  @override
  int get hashCode => Object.hash(years, months);
}

class AssetInvestmentSimulationResult {
  const AssetInvestmentSimulationResult({
    required this.requestedYears,
    required this.requestedMonths,
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
  final int requestedMonths;
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

  String get periodDisplayLabel {
    if (requestedMonths > 0) {
      return requestedMonths == 1 ? '1 mês' : '$requestedMonths meses';
    }
    return requestedYears == 1 ? '1 ano' : '$requestedYears anos';
  }
}

int maxSimulatableYearsFromSeries({
  List<FiiCandleBar> candles = const [],
  List<FiiHistoryPoint> history = const [],
}) {
  DateTime? earliest;

  for (final bar in candles) {
    if (bar.close <= 0) continue;
    final date = parseFiiDate(bar.tradeDate);
    if (date == null) continue;
    if (earliest == null || date.isBefore(earliest)) earliest = date;
  }

  for (final point in history) {
    final date = parseFiiDate(point.referenceDate);
    final price = point.closePrice;
    if (date == null || price == null || price <= 0) continue;
    if (earliest == null || date.isBefore(earliest)) earliest = date;
  }

  if (earliest == null) return 0;
  final months = _monthsBetween(earliest, DateTime.now());
  return (months / 12).floor().clamp(0, 15);
}

bool hasDividendPayments(List<FiiDistributionPayment> payments) {
  return payments.any((payment) => (payment.valuePerShare ?? 0) > 0);
}

AssetInvestmentSimulationResult? simulateAssetInvestment({
  required double initialAmount,
  int years = 0,
  int months = 0,
  required double currentPrice,
  List<FiiCandleBar> candles = const [],
  List<FiiHistoryPoint> history = const [],
  List<FiiDistributionPayment> payments = const [],
  bool reinvestDividends = false,
}) {
  if (initialAmount <= 0 || currentPrice <= 0) return null;
  if (years <= 0 && months <= 0) return null;
  if (candles.isEmpty && history.isEmpty) return null;

  final now = DateTime.now();
  final requestedStart = months > 0
      ? DateTime(now.year, now.month - months, now.day)
      : DateTime(now.year - years, now.month, now.day);
  final earliestPoint = _earliestPricePoint(candles: candles, history: history);
  if (earliestPoint == null) return null;

  final startDate =
      requestedStart.isBefore(earliestPoint.date) ? earliestPoint.date : requestedStart;
  final usedPartialHistory = startDate.isAfter(requestedStart);

  final entryPoint = pricePointAtDate(
    target: startDate,
    candles: candles,
    history: history,
  );
  if (entryPoint == null || entryPoint.price <= 0) return null;

  final entryPrice = entryPoint.price;
  var shares = initialAmount / entryPrice;
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
      final buyPoint = pricePointAtDate(
        target: date,
        candles: candles,
        history: history,
      );
      final buyPrice = buyPoint?.price ?? currentPrice;
      if (buyPrice > 0) {
        shares += dividend / buyPrice;
      }
    }
  }

  final finalShares = shares;
  final currentValue = finalShares * currentPrice;
  final totalValue = reinvestDividends ? currentValue : currentValue + totalDividends;
  final profit = totalValue - initialAmount;
  final returnPct = initialAmount == 0 ? 0.0 : (profit / initialAmount) * 100;

  final priceOnlyValue = initialShares * currentPrice;
  final priceReturnPct =
      initialAmount == 0 ? 0.0 : ((priceOnlyValue - initialAmount) / initialAmount) * 100;
  final dividendReturnPct = initialAmount == 0 ? 0.0 : (totalDividends / initialAmount) * 100;
  final effectiveYears = _monthsBetween(startDate, now) / 12.0;

  return AssetInvestmentSimulationResult(
    requestedYears: years,
    requestedMonths: months,
    effectiveYears: effectiveYears,
    startDate: startDate,
    entryPrice: entryPrice,
    shares: initialShares,
    finalShares: finalShares,
    initialAmount: initialAmount,
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

AssetInvestmentSimulationResult? simulateAssetInvestmentForPeriod({
  required WhatIfInvestmentPeriod period,
  required double initialAmount,
  required double currentPrice,
  List<FiiCandleBar> candles = const [],
  List<FiiHistoryPoint> history = const [],
  List<FiiDistributionPayment> payments = const [],
  bool reinvestDividends = false,
}) {
  return simulateAssetInvestment(
    initialAmount: initialAmount,
    years: period.years,
    months: period.months,
    currentPrice: currentPrice,
    candles: candles,
    history: history,
    payments: payments,
    reinvestDividends: reinvestDividends,
  );
}

/// Períodos com histórico completo (sem recorte no início da série).
List<WhatIfInvestmentPeriod> simulatableWhatIfPeriods({
  required double initialAmount,
  required double currentPrice,
  List<FiiCandleBar> candles = const [],
  List<FiiHistoryPoint> history = const [],
  List<FiiDistributionPayment> payments = const [],
  bool reinvestDividends = false,
  List<WhatIfInvestmentPeriod> candidates = whatIfInvestmentPeriodOptions,
}) {
  final periods = <WhatIfInvestmentPeriod>[];
  for (final period in candidates) {
    final result = simulateAssetInvestmentForPeriod(
      period: period,
      initialAmount: initialAmount,
      currentPrice: currentPrice,
      candles: candles,
      history: history,
      payments: payments,
      reinvestDividends: reinvestDividends,
    );
    if (result != null && !result.usedPartialHistory) {
      periods.add(period);
    }
  }
  return periods;
}

List<int> simulatableWhatIfPeriodYears({
  required double initialAmount,
  required double currentPrice,
  List<FiiCandleBar> candles = const [],
  List<FiiHistoryPoint> history = const [],
  List<FiiDistributionPayment> payments = const [],
  bool reinvestDividends = false,
  List<int> candidates = whatIfInvestmentPeriodYears,
}) {
  return simulatableWhatIfPeriods(
    initialAmount: initialAmount,
    currentPrice: currentPrice,
    candles: candles,
    history: history,
    payments: payments,
    reinvestDividends: reinvestDividends,
    candidates: candidates.map(WhatIfInvestmentPeriod.years).toList(),
  ).map((period) => period.years).toList();
}

WhatIfInvestmentPeriod defaultWhatIfPeriodOption(List<WhatIfInvestmentPeriod> periods) {
  if (periods.isEmpty) return whatIfInvestmentPeriodOptions.first;
  for (final preferred in [
    WhatIfInvestmentPeriod.years(5),
    WhatIfInvestmentPeriod.years(1),
    WhatIfInvestmentPeriod.months(6),
    WhatIfInvestmentPeriod.months(3),
  ]) {
    if (periods.contains(preferred)) return preferred;
  }
  return periods.last;
}

int defaultWhatIfPeriod(List<int> periods) {
  if (periods.isEmpty) return whatIfInvestmentPeriodYears.first;
  if (periods.contains(5)) return 5;
  return periods.last;
}

Map<int, AssetInvestmentSimulationResult?> simulateWhatIfGrid({
  required double initialAmount,
  required double currentPrice,
  List<FiiCandleBar> candles = const [],
  List<FiiHistoryPoint> history = const [],
  List<FiiDistributionPayment> payments = const [],
  required bool reinvestDividends,
  List<int> years = whatIfInvestmentPeriodYears,
}) {
  final results = <int, AssetInvestmentSimulationResult?>{};
  for (final year in years) {
    results[year] = simulateAssetInvestment(
      initialAmount: initialAmount,
      years: year,
      currentPrice: currentPrice,
      candles: candles,
      history: history,
      payments: payments,
      reinvestDividends: reinvestDividends,
    );
  }
  return results;
}

({DateTime date, double price})? _earliestPricePoint({
  required List<FiiCandleBar> candles,
  required List<FiiHistoryPoint> history,
}) {
  ({DateTime date, double price})? earliest;

  void consider(({DateTime date, double price})? point) {
    if (point == null) return;
    if (earliest == null || point.date.isBefore(earliest!.date)) {
      earliest = point;
    }
  }

  for (final bar in candles) {
    if (bar.close <= 0) continue;
    final date = parseFiiDate(bar.tradeDate);
    if (date == null) continue;
    consider((date: date, price: bar.close));
  }

  for (final point in history) {
    final date = parseFiiDate(point.referenceDate);
    final price = point.closePrice;
    if (date == null || price == null || price <= 0) continue;
    consider((date: date, price: price));
  }

  return earliest;
}

int _monthsBetween(DateTime start, DateTime end) {
  return (end.year - start.year) * 12 + (end.month - start.month);
}
