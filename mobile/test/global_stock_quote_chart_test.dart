import 'package:flutter_test/flutter_test.dart';
import 'package:rico_investidor/core/utils/dividend_payment_mappers.dart';
import 'package:rico_investidor/features/global_markets/models/global_market_models.dart';
import 'package:rico_investidor/features/global_markets/utils/global_stock_chart_prices.dart';
import 'package:rico_investidor/features/global_markets/utils/us_quote_enrichment.dart';

void main() {
  const preSplit = GlobalStockCandleDto(
    date: '2021-06-10',
    close: 600,
    adjClose: 15,
  );
  const postSplit = GlobalStockCandleDto(
    date: '2024-06-11',
    close: 120,
    adjClose: 120,
  );
  const flat = GlobalStockCandleDto(
    date: '2026-06-01',
    close: 140,
    adjClose: 140,
  );

  final splitSeries = List<GlobalStockCandleDto>.generate(
    300,
    (i) => GlobalStockCandleDto(
      date: '2024-01-${(i % 28 + 1).toString().padLeft(2, '0')}',
      close: i < 150 ? 600 : 120,
      adjClose: i < 150 ? 15 : 120,
    ),
  )..add(postSplit);

  test('chartCloseForGlobalStockCandle uses adj_close when adjusted', () {
    expect(chartCloseForGlobalStockCandle(preSplit, useAdjusted: true), 15);
    expect(chartCloseForGlobalStockCandle(preSplit, useAdjusted: false), 600);
    expect(chartCloseForGlobalStockCandle(postSplit, useAdjusted: true), 120);
    expect(chartCloseForGlobalStockCandle(postSplit, useAdjusted: false), 120);
  });

  test('globalStockCandleHasSplitAdjustment detects material difference', () {
    expect(globalStockCandleHasSplitAdjustment(preSplit), isTrue);
    expect(globalStockCandleHasSplitAdjustment(postSplit), isFalse);
    expect(globalStockCandleHasSplitAdjustment(flat), isFalse);
  });

  test('effectiveGlobalStockChartAdjusted respects user toggle', () {
    final candles = [preSplit, postSplit];

    expect(
      effectiveGlobalStockChartAdjusted(useAdjusted: true, candles: candles),
      isTrue,
    );
    expect(
      effectiveGlobalStockChartAdjusted(useAdjusted: false, candles: candles),
      isFalse,
    );
  });

  test('returnCloseForGlobalStockCandle uses adjusted across split series', () {
    expect(returnCloseForGlobalStockCandle(preSplit, splitSeries), 15);
    expect(returnCloseForGlobalStockCandle(postSplit, splitSeries), 120);
    expect(returnCloseForGlobalStockCandle(flat, [flat]), 140);
  });

  test('candleBarsFromGlobal keeps adjusted continuity for simulation', () {
    final bars = candleBarsFromGlobal([preSplit, postSplit]);
    expect(bars.first.close, 15);
    expect(bars.last.close, 120);
  });

  test('returnsFrom uses adjusted prices when series has splits', () {
    const length = 1301;
    const startIndex = length - 1 - 1260;
    final candles = List<GlobalStockCandleDto>.generate(
      length,
      (i) => GlobalStockCandleDto(
        date: DateTime(2020, 1, 1).add(Duration(days: i)).toIso8601String().substring(0, 10),
        close: i == startIndex ? 600 : 120,
        adjClose: i == startIndex ? 15 : 120,
      ),
    );

    final returns = UsQuoteEnrichment.returnsFrom(candles, currentPrice: 120);
    final fiveYears = returns.where((row) => row.label == '5A').toList();

    expect(fiveYears, isNotEmpty);
    expect(fiveYears.first.returnPct, closeTo(700, 1));
  });
}
