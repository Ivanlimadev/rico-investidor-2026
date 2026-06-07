import 'package:flutter_test/flutter_test.dart';
import 'package:rico_investidor/core/utils/portfolio_balance.dart';
import 'package:rico_investidor/models/holding_currency.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/models/portfolio_holding.dart';
import 'package:rico_investidor/services/market_preference_storage.dart';

void main() {
  const usPreference = MarketPreference(code: 'US', name: 'Mercado Americano');

  PortfolioHolding holding({
    required String symbol,
    required HoldingCurrency currency,
    double qty = 10,
    double price = 100,
    double avg = 90,
  }) {
    return PortfolioHolding(
      id: symbol,
      symbol: symbol,
      name: symbol,
      quantity: qty,
      averagePrice: avg,
      currentPrice: price,
      currency: currency,
    );
  }

  test('patrimônio total exibido em dólares', () {
    final breakdown = computePortfolioBalanceBreakdown(
      holdings: [
        holding(symbol: 'AAPL', currency: HoldingCurrency.usd, qty: 2, price: 100, avg: 90),
      ],
      categoryResolver: (_) => MarketCategory.stocks,
      usdBrlRate: 5.0,
    );

    expect(breakdown.displayTotal, 200);
    expect(breakdown.displayCurrency, HoldingCurrency.usd);
    expect(breakdown.internationalMarketValueUsd, 200);
  });

  test('carteira legada BRL converte para o total em dólares quando categoria é US', () {
    final breakdown = computePortfolioBalanceBreakdown(
      holdings: [
        holding(symbol: 'MSFT', currency: HoldingCurrency.brl, price: 50, avg: 40),
        holding(symbol: 'AAPL', currency: HoldingCurrency.usd, price: 100, avg: 90),
      ],
      categoryResolver: (_) => MarketCategory.stocks,
      usdBrlRate: 5.0,
    );

    expect(breakdown.displayTotal, 1500);
    expect(breakdown.internationalMarketValueUsd, 1500);
  });

  test('AAPL com categoria stocks vai para bucket internacional', () {
    final h = holding(symbol: 'AAPL', currency: HoldingCurrency.usd, price: 100);
    expect(
      isInternationalUsdHolding(h, category: MarketCategory.stocks),
      isTrue,
    );
  });

  test('ativos US resolvem moeda em dólares', () {
    final h = holding(symbol: 'NVDA', currency: HoldingCurrency.brl, price: 9.8);
    expect(isInternationalUsdHolding(h, category: MarketCategory.stocks), isTrue);
    expect(
      resolvedHoldingCurrency(h, category: MarketCategory.stocks),
      HoldingCurrency.usd,
    );
  });

  test('primaryTotal usa bucket internacional em dólares', () {
    final breakdown = computePortfolioBalanceBreakdown(
      holdings: [
        holding(symbol: 'AAPL', currency: HoldingCurrency.usd, price: 200, avg: 180),
      ],
      categoryResolver: (_) => MarketCategory.stocks,
      usdBrlRate: 5.0,
    );

    expect(breakdown.primaryTotal(usPreference), 2000);
  });
}
