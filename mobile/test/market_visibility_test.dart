import 'package:flutter_test/flutter_test.dart';
import 'package:rico_investidor/core/markets/market_visibility.dart';
import 'package:rico_investidor/core/utils/market_category_storage.dart';
import 'package:rico_investidor/models/market_category.dart';

void main() {
  test('categoria legada ETF vira stocks via storage', () {
    expect(marketCategoryFromStorage('etf'), MarketCategory.stocks);
  });

  test('categoria EUA visível é preservada', () {
    expect(
      resolveMarketCategory(
        symbol: 'O',
        stored: MarketCategory.reits,
        inferred: MarketCategory.stocks,
      ),
      MarketCategory.reits,
    );
  });

  test('BTC sem categoria salva vira cripto', () {
    expect(
      resolveMarketCategory(
        symbol: 'BTC',
        stored: null,
        inferred: MarketCategory.cripto,
      ),
      MarketCategory.cripto,
    );
  });
}
