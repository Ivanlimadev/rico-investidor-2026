import 'package:flutter_test/flutter_test.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/services/recent_searched_assets_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

AssetItem _asset(String symbol) => AssetItem(
      symbol: symbol,
      name: symbol,
      category: MarketCategory.stocks,
      price: 10,
      changePercent: 0,
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('record keeps newest first and caps at 12', () async {
    final storage = RecentSearchedAssetsStorage.instance;

    for (var i = 0; i < 14; i++) {
      await storage.record(_asset('SYM$i'));
    }

    final items = await storage.load();
    expect(items.length, 12);
    expect(items.first.symbol, 'SYM13');
    expect(items.last.symbol, 'SYM2');
  });

  test('record moves duplicate symbol to top', () async {
    final storage = RecentSearchedAssetsStorage.instance;

    await storage.record(_asset('PETR4'));
    await storage.record(_asset('VALE3'));
    await storage.record(_asset('PETR4'));

    final items = await storage.load();
    expect(items.map((a) => a.symbol).toList(), ['PETR4', 'VALE3']);
  });
}
