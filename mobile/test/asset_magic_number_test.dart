import 'package:flutter_test/flutter_test.dart';
import 'package:rico_investidor/core/utils/asset_magic_number.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/market_series_models.dart';
import 'package:rico_investidor/models/market_category.dart';

void main() {
  group('computeAssetMagicNumber', () {
    test('uses average of recent payments', () {
      final result = computeAssetMagicNumber(
        price: 100,
        payments: [
          const DistributionPayment(
            referenceDate: '2025-01',
            valuePerShare: 1,
          ),
          const DistributionPayment(
            referenceDate: '2025-02',
            valuePerShare: 1.5,
          ),
        ],
      );

      expect(result, isNotNull);
      expect(result!.monthlyDividendPerShare, closeTo(1.25, 0.001));
      expect(result.magicNumber, 80);
      expect(result.source, 'média dos últimos pagamentos');
    });

    test('falls back to ttm per share', () {
      final result = computeAssetMagicNumber(
        price: 120,
        ttmPerShare: 12,
      );

      expect(result, isNotNull);
      expect(result!.monthlyDividendPerShare, 1);
      expect(result.magicNumber, 120);
      expect(result.source, 'provento 12m ÷ 12');
    });

    test('falls back to dividend yield', () {
      final result = computeAssetMagicNumber(
        price: 50,
        dividendYieldPercent: 6,
      );

      expect(result, isNotNull);
      expect(result!.monthlyDividendPerShare, closeTo(0.25, 0.001));
      expect(result.magicNumber, 200);
      expect(result.source, 'DY 12m estimado');
    });

    test('returns null when price is zero', () {
      expect(
        computeAssetMagicNumber(price: 0, dividendYieldPercent: 5),
        isNull,
      );
    });
  });

  group('magicNumberFromAssetItem', () {
    test('computes from dividend yield on asset item', () {
      const asset = AssetItem(
        symbol: 'AAPL',
        name: 'Apple',
        category: MarketCategory.stocks,
        price: 100,
        changePercent: 1,
        dividendYield12m: 12,
      );

      final result = magicNumberFromAssetItem(asset);

      expect(result, isNotNull);
      expect(result!.magicNumber, 100);
    });
  });

  group('magicNumberUnitLabel', () {
    test('uses cota for reits and ação for stocks', () {
      expect(magicNumberUnitLabel(MarketCategory.reits), 'cota');
      expect(magicNumberUnitLabel(MarketCategory.stocks), 'ação');
      expect(magicNumberUnitPlural(MarketCategory.stocks), 'ações');
    });
  });
}
