import 'package:flutter_test/flutter_test.dart';
import 'package:rico_investidor/core/utils/asset_investment_simulation.dart';
import 'package:rico_investidor/models/fii_models.dart';

void main() {
  test('simulateAssetInvestment compounds price and dividends without reinvest', () {
    final history = [
      FiiHistoryPoint(referenceDate: '2024-01-15', closePrice: 100),
      FiiHistoryPoint(referenceDate: '2025-06-15', closePrice: 110),
    ];
    final payments = [
      FiiDistributionPayment(
        referenceDate: '2024-06-01',
        paymentDate: '2024-06-10',
        valuePerShare: 2,
      ),
    ];

    final result = simulateAssetInvestment(
      initialAmount: 1000,
      years: 2,
      currentPrice: 120,
      history: history,
      payments: payments,
      reinvestDividends: false,
    );

    expect(result, isNotNull);
    expect(result!.initialAmount, 1000);
    expect(result.shares, 10);
    expect(result.dividendsReceived, 20);
    expect(result.totalValue, closeTo(1220, 0.01));
    expect(result.returnPct, closeTo(22, 0.1));
  });

  test('simulateAssetInvestment supports month-based periods', () {
    final history = [
      FiiHistoryPoint(referenceDate: '2025-12-01', closePrice: 500),
      FiiHistoryPoint(referenceDate: '2026-05-01', closePrice: 620),
    ];

    final result = simulateAssetInvestment(
      initialAmount: 1000,
      months: 3,
      currentPrice: 650,
      history: history,
      reinvestDividends: false,
    );

    expect(result, isNotNull);
    expect(result!.requestedMonths, 3);
    expect(result.totalValue, greaterThan(1000));
    expect(result.usedPartialHistory, isFalse);
  });

  test('simulatableWhatIfPeriodYears excludes partial history periods', () {
    final candles = [
      FiiCandleBar(tradeDate: '2021-06-10', open: 50, high: 52, low: 49, close: 50, volume: 1000),
      FiiCandleBar(tradeDate: '2026-01-10', open: 80, high: 82, low: 79, close: 80, volume: 1000),
    ];

    final periods = simulatableWhatIfPeriodYears(
      initialAmount: 1000,
      currentPrice: 80,
      candles: candles,
      reinvestDividends: false,
    );

    expect(periods, isNot(contains(10)));
    expect(periods, isNot(contains(15)));
    expect(periods, isNotEmpty);
  });

  test('simulateWhatIfGrid returns entries per period', () {
    final candles = [
      FiiCandleBar(tradeDate: '2023-01-10', open: 50, high: 52, low: 49, close: 50, volume: 1000),
      FiiCandleBar(tradeDate: '2026-01-10', open: 80, high: 82, low: 79, close: 80, volume: 1000),
    ];

    final grid = simulateWhatIfGrid(
      initialAmount: 1000,
      currentPrice: 80,
      candles: candles,
      reinvestDividends: false,
    );

    expect(grid[1], isNotNull);
    expect(grid[1]!.totalValue, greaterThan(1000));
  });

  test('simulatableWhatIfPeriods includes months when year periods are partial', () {
    final history = <FiiHistoryPoint>[];
    final now = DateTime.now();
    for (var i = 300; i >= 0; i -= 7) {
      final date = now.subtract(Duration(days: i));
      final iso =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      history.add(FiiHistoryPoint(referenceDate: iso, closePrice: 500.0 + (300 - i)));
    }

    final periods = simulatableWhatIfPeriods(
      initialAmount: 1000,
      currentPrice: 800,
      history: history,
      reinvestDividends: false,
    );

    expect(periods, isNot(contains(const WhatIfInvestmentPeriod.years(5))));
    expect(periods, contains(const WhatIfInvestmentPeriod.months(6)));
  });
}
