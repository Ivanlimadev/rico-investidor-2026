import 'package:rico_investidor/core/utils/asset_returns.dart';
import 'package:rico_investidor/core/utils/parse_market_date.dart';
import 'package:rico_investidor/models/market_series_models.dart';

/// Períodos anuais do card "Se você tivesse investido".
const whatIfInvestmentPeriodYears = [1, 2, 5, 10];

const whatIfInvestmentPeriodOptions = <WhatIfInvestmentPeriod>[
  WhatIfInvestmentPeriod.years(1),
  WhatIfInvestmentPeriod.years(2),
  WhatIfInvestmentPeriod.years(5),
  WhatIfInvestmentPeriod.years(10),
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

  /// Rótulo para o hero — deixa claro quando o histórico é menor que o período pedido.
  String get heroPeriodLabel {
    if (!usedPartialHistory) return periodDisplayLabel;
    final since =
        '${startDate.day.toString().padLeft(2, '0')}/${startDate.month.toString().padLeft(2, '0')}/${startDate.year}';
    if (effectiveYears < 1.05) {
      final months = (effectiveYears * 12).round().clamp(1, 11);
      return months == 1 ? '1 mês (desde $since)' : '$months meses (desde $since)';
    }
    final yearsLabel = effectiveYears.round() == 1
        ? '1 ano'
        : '${effectiveYears.toStringAsFixed(1)} anos';
    return '$yearsLabel (desde $since)';
  }
}

int maxSimulatableYearsFromSeries({
  List<QuoteCandleBar> candles = const [],
  List<HistoryPricePoint> history = const [],
}) {
  final timeline = AssetPriceTimeline.from(candles: candles, history: history);
  final earliest = timeline.earliest;
  if (earliest == null) return 0;
  final months = _monthsBetween(earliest.date, DateTime.now());
  return (months / 12).floor().clamp(0, 10);
}

bool hasDividendPayments(List<DistributionPayment> payments) {
  return payments.any((payment) => (payment.valuePerShare ?? 0) > 0);
}

AssetInvestmentSimulationResult? simulateAssetInvestment({
  required double initialAmount,
  int years = 0,
  int months = 0,
  required double currentPrice,
  List<QuoteCandleBar> candles = const [],
  List<HistoryPricePoint> history = const [],
  List<DistributionPayment> payments = const [],
  bool reinvestDividends = false,
  AssetPriceTimeline? timeline,
}) {
  if (initialAmount <= 0 || currentPrice <= 0) return null;
  if (years <= 0 && months <= 0) return null;
  if (candles.isEmpty && history.isEmpty) return null;

  final series = timeline ?? AssetPriceTimeline.from(candles: candles, history: history);
  if (series.isEmpty) return null;

  final now = DateTime.now();
  final requestedStart = months > 0
      ? DateTime(now.year, now.month - months, now.day)
      : DateTime(now.year - years, now.month, now.day);
  final earliestPoint = series.earliest;
  if (earliestPoint == null) return null;

  final startDate =
      requestedStart.isBefore(earliestPoint.date) ? earliestPoint.date : requestedStart;
  final usedPartialHistory = startDate.isAfter(requestedStart);

  final entryPoint = series.atOrBefore(startDate);
  if (entryPoint == null || entryPoint.price <= 0) return null;

  final entryPrice = entryPoint.price;
  var shares = initialAmount / entryPrice;
  final initialShares = shares;

  var totalDividends = 0.0;
  var paymentCount = 0;

  final sortedPayments = List<DistributionPayment>.from(payments)
    ..sort((a, b) {
      final da = parseMarketDate(a.paymentDate ?? a.referenceDate);
      final db = parseMarketDate(b.paymentDate ?? b.referenceDate);
      if (da == null && db == null) return 0;
      if (da == null) return -1;
      if (db == null) return 1;
      return da.compareTo(db);
    });

  for (final payment in sortedPayments) {
    final date = parseMarketDate(payment.paymentDate ?? payment.referenceDate);
    final value = payment.valuePerShare;
    if (date == null || value == null || value <= 0) continue;
    if (date.isBefore(startDate)) continue;

    final dividend = value * shares;
    totalDividends += dividend;
    paymentCount++;

    if (reinvestDividends) {
      final buyPoint = series.atOrBefore(date);
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
  List<QuoteCandleBar> candles = const [],
  List<HistoryPricePoint> history = const [],
  List<DistributionPayment> payments = const [],
  bool reinvestDividends = false,
  AssetPriceTimeline? timeline,
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
    timeline: timeline,
  );
}

/// Períodos simuláveis — omite opções que dariam o mesmo ponto de compra.
List<WhatIfInvestmentPeriod> simulatableWhatIfPeriods({
  required double initialAmount,
  required double currentPrice,
  List<QuoteCandleBar> candles = const [],
  List<HistoryPricePoint> history = const [],
  List<DistributionPayment> payments = const [],
  bool reinvestDividends = false,
  List<WhatIfInvestmentPeriod> candidates = whatIfInvestmentPeriodOptions,
}) {
  final timeline = AssetPriceTimeline.from(candles: candles, history: history);
  if (timeline.isEmpty) return const [];

  final periods = <WhatIfInvestmentPeriod>[];
  final seenStartDates = <int>{};
  for (final period in candidates) {
    final result = simulateAssetInvestmentForPeriod(
      period: period,
      initialAmount: initialAmount,
      currentPrice: currentPrice,
      candles: candles,
      history: history,
      payments: payments,
      reinvestDividends: reinvestDividends,
      timeline: timeline,
    );
    if (result == null) continue;
    final startKey = result.startDate.millisecondsSinceEpoch;
    if (!seenStartDates.add(startKey)) continue;
    periods.add(period);
  }
  return periods;
}

List<int> simulatableWhatIfPeriodYears({
  required double initialAmount,
  required double currentPrice,
  List<QuoteCandleBar> candles = const [],
  List<HistoryPricePoint> history = const [],
  List<DistributionPayment> payments = const [],
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
    WhatIfInvestmentPeriod.years(10),
    WhatIfInvestmentPeriod.years(2),
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
  List<QuoteCandleBar> candles = const [],
  List<HistoryPricePoint> history = const [],
  List<DistributionPayment> payments = const [],
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

int _monthsBetween(DateTime start, DateTime end) {
  return (end.year - start.year) * 12 + (end.month - start.month);
}
