import 'package:flutter_test/flutter_test.dart';
import 'package:rico_investidor/core/utils/asset_returns.dart';
import 'package:rico_investidor/models/fii_models.dart';

void main() {
  group('computeAssetReturns', () {
    test('calcula retorno por data com histórico mensal irregular', () {
      final history = [
        FiiHistoryPoint(referenceDate: '2020-01-31', closePrice: 100),
        FiiHistoryPoint(referenceDate: '2020-06-30', closePrice: 105),
        FiiHistoryPoint(referenceDate: '2021-03-31', closePrice: 110),
        FiiHistoryPoint(referenceDate: '2024-12-31', closePrice: 120),
        FiiHistoryPoint(referenceDate: '2025-04-30', closePrice: 130),
      ];

      final now = DateTime(2025, 5, 25);
      final items = _computeAt(now, history: history, currentPrice: 150);

      final oneYear = items.firstWhere((item) => item.label == '1A');
      expect(oneYear.priceReturnPct, closeTo(36.36, 0.1));
      expect(oneYear.returnPct, closeTo(36.36, 0.1));
    });

    test('usa candles quando histórico mensal está vazio', () {
      final candles = [
        FiiCandleBar(tradeDate: '2024-05-01', open: 10, high: 10, low: 10, close: 10),
        FiiCandleBar(tradeDate: '2025-04-01', open: 11, high: 11, low: 11, close: 11),
        FiiCandleBar(tradeDate: '2025-05-24', open: 12, high: 12, low: 12, close: 12),
      ];

      final now = DateTime(2025, 5, 25);
      final items = _computeAt(
        now,
        candles: candles,
        currentPrice: 12,
      );

      final oneYear = items.firstWhere((item) => item.label == '1A');
      expect(oneYear.priceReturnPct, closeTo(20, 0.01));
    });

    test('inclui proventos no retorno total', () {
      final history = [
        FiiHistoryPoint(referenceDate: '2024-05-01', closePrice: 100),
        FiiHistoryPoint(referenceDate: '2025-05-01', closePrice: 100),
      ];
      final payments = [
        FiiDistributionPayment(
          paymentDate: '2024-11-01',
          valuePerShare: 5,
        ),
      ];

      final now = DateTime(2025, 5, 25);
      final items = _computeAt(
        now,
        history: history,
        currentPrice: 110,
        payments: payments,
      );

      final oneYear = items.firstWhere((item) => item.label == '1A');
      expect(oneYear.priceReturnPct, closeTo(10, 0.01));
      expect(oneYear.dividendReturnPct, closeTo(5, 0.01));
      expect(oneYear.returnPct, closeTo(15, 0.01));
    });

    test('retorna null para período maior que o histórico disponível', () {
      final history = [
        FiiHistoryPoint(referenceDate: '2023-01-31', closePrice: 100),
        FiiHistoryPoint(referenceDate: '2025-05-01', closePrice: 120),
      ];

      final now = DateTime(2025, 5, 25);
      final items = _computeAt(now, history: history, currentPrice: 130);

      expect(items.firstWhere((item) => item.label == '10A').returnPct, isNull);
      expect(items.firstWhere((item) => item.label == '1A').returnPct, isNotNull);
    });
  });
}

List<AssetReturnItem> _computeAt(
  DateTime now, {
  List<FiiHistoryPoint> history = const [],
  List<FiiCandleBar> candles = const [],
  List<FiiDistributionPayment> payments = const [],
  double? currentPrice = 100,
}) {
  return assetReturnPeriods.map((entry) {
    final (label, months) = entry;
    final targetDate = subtractMonths(now, months);
    final point = pricePointAtDate(
      target: targetDate,
      history: history,
      candles: candles,
    );
    if (point == null || currentPrice == null || currentPrice <= 0) {
      return AssetReturnItem(label: label, monthsBack: months);
    }

    final spanMonths = (now.year - point.date.year) * 12 + (now.month - point.date.month);
    if (spanMonths + 1 < months) {
      return AssetReturnItem(label: label, monthsBack: months);
    }

    final dividendsPerShare = dividendsPerShareSince(payments, point.date);
    final pricePct = ((currentPrice - point.price) / point.price) * 100;
    final dividendPct = (dividendsPerShare / point.price) * 100;

    return AssetReturnItem(
      label: label,
      monthsBack: months,
      returnPct: pricePct + dividendPct,
      priceReturnPct: pricePct,
      dividendReturnPct: dividendPct,
    );
  }).toList();
}
