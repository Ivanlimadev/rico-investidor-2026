import 'package:flutter_test/flutter_test.dart';
import 'package:rico_investidor/models/dividend_payment.dart';
import 'package:rico_investidor/models/holding_currency.dart';
import 'package:rico_investidor/models/portfolio_holding.dart';
import 'package:rico_investidor/services/portfolio_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PortfolioStorage', () {
    test('save and load roundtrip in secure storage', () async {
      final memoryStore = <String, String>{};
      final storage = PortfolioStorage(memoryStore: memoryStore);

      final holdings = [
        const PortfolioHolding(
          id: '1',
          symbol: 'PETR4',
          name: 'Petrobras',
          quantity: 100,
          averagePrice: 30,
          currentPrice: 35,
        ),
      ];
      final dividends = [
        DividendPayment(
          id: 'd1',
          symbol: 'PETR4',
          name: 'Petrobras',
          amount: 120,
          date: DateTime.utc(2026, 1, 15),
        ),
      ];

      await storage.save(holdings: holdings, dividends: dividends);
      final loaded = await storage.load();

      expect(loaded, isNotNull);
      expect(loaded!.holdings.single.symbol, 'PETR4');
      expect(loaded.dividends.single.amount, 120);
      expect(memoryStore.containsKey('portfolio_holdings_v1'), isTrue);
      expect(memoryStore.containsKey('portfolio_dividends_v1'), isTrue);
    });

    test('migrates legacy SharedPreferences data to secure storage', () async {
      SharedPreferences.setMockInitialValues({
        'portfolio_holdings_v1':
            '[{"id":"1","symbol":"VALE3","name":"Vale","quantity":10,"average_price":60,"current_price":65,"change_percent":0,"currency":"brl"}]',
        'portfolio_dividends_v1':
            '[{"id":"d1","symbol":"VALE3","name":"Vale","amount":50,"date":"2026-02-01T00:00:00.000Z"}]',
      });

      final memoryStore = <String, String>{};
      final storage = PortfolioStorage(memoryStore: memoryStore);
      final loaded = await storage.load();

      expect(loaded, isNotNull);
      expect(loaded!.holdings.single.symbol, 'VALE3');
      expect(loaded.holdings.single.currency, HoldingCurrency.brl);
      expect(loaded.dividends.single.amount, 50);
      expect(memoryStore['portfolio_holdings_v1'], isNotNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('portfolio_holdings_v1'), isNull);
      expect(prefs.getString('portfolio_dividends_v1'), isNull);
    });
  });
}
