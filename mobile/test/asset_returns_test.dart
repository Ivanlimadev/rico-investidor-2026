import 'package:flutter_test/flutter_test.dart';
import 'package:rico_investidor/core/utils/asset_returns.dart';
import 'package:rico_investidor/models/fii_models.dart';

List<FiiCandleBar> _dailySeries({
  required int count,
  required double startPrice,
  required double endPrice,
  required DateTime startDate,
}) {
  return List<FiiCandleBar>.generate(count, (index) {
    final day = startDate.add(Duration(days: index));
    final price = startPrice + ((endPrice - startPrice) * index / (count - 1));
    return FiiCandleBar(
      tradeDate: day.toIso8601String().substring(0, 10),
      open: price,
      high: price,
      low: price,
      close: price,
    );
  });
}

void main() {
  group('computeAssetReturns', () {
    test('calcula retorno 1A por pregões', () {
      final candles = _dailySeries(
        count: 300,
        startPrice: 100,
        endPrice: 120,
        startDate: DateTime(2024, 1, 2),
      );

      final items = computeAssetReturns(
        currentPrice: 132,
        candles: candles,
      );

      final oneYear = items.firstWhere((item) => item.label == '1A');
      // 252 pregões atrás: preço ~103,15 → 132 ≈ +28%
      expect(oneYear.returnPct, closeTo(28, 0.5));
      expect(oneYear.priceReturnPct, closeTo(28, 0.5));
    });

    test('inclui proventos no retorno total', () {
      final candles = _dailySeries(
        count: 300,
        startPrice: 100,
        endPrice: 100,
        startDate: DateTime(2024, 1, 2),
      );
      final payments = [
        FiiDistributionPayment(
          paymentDate: '2025-06-01',
          valuePerShare: 5,
        ),
      ];

      final items = computeAssetReturns(
        currentPrice: 110,
        candles: candles,
        payments: payments,
      );

      final oneYear = items.firstWhere((item) => item.label == '1A');
      expect(oneYear.priceReturnPct, closeTo(10, 0.1));
      expect(oneYear.dividendReturnPct, closeTo(5, 0.1));
      expect(oneYear.returnPct, closeTo(15, 0.1));
    });

    test('retorna null para período maior que o histórico disponível', () {
      final candles = _dailySeries(
        count: 120,
        startPrice: 100,
        endPrice: 120,
        startDate: DateTime(2025, 1, 2),
      );

      final items = computeAssetReturns(
        currentPrice: 130,
        candles: candles,
      );

      expect(items.firstWhere((item) => item.label == '5A').returnPct, isNull);
      expect(items.firstWhere((item) => item.label == '1A').returnPct, isNull);
      expect(items.firstWhere((item) => item.label == '3M').returnPct, isNotNull);
    });
  });
}
