import 'package:flutter_test/flutter_test.dart';
import 'package:rico_investidor/core/utils/portfolio_balance.dart';
import 'package:rico_investidor/models/holding_currency.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/models/portfolio_holding.dart';
import 'package:rico_investidor/services/market_preference_storage.dart';

void main() {
  const brPreference = MarketPreference(code: 'BR', name: 'Brasil');
  const usPreference = MarketPreference(code: 'US', name: 'Estados Unidos');

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

  test('BDR NVDA34 conta no patrimônio brasileiro, não na dolarização', () {
    final breakdown = computePortfolioBalanceBreakdown(
      holdings: [
        holding(symbol: 'PETR4', currency: HoldingCurrency.brl, price: 40, avg: 35),
        holding(symbol: 'NVDA34', currency: HoldingCurrency.brl, price: 50, avg: 45),
        holding(symbol: 'AAPL', currency: HoldingCurrency.usd, price: 200, avg: 180),
      ],
      categoryResolver: (symbol) {
        return switch (symbol) {
          'NVDA34' => MarketCategory.bdr,
          'AAPL' => MarketCategory.stocks,
          _ => MarketCategory.acoesBr,
        };
      },
      usdBrlRate: 5.0,
    );

    expect(breakdown.domesticMarketValueBrl, 900);
    expect(breakdown.internationalMarketValueUsd, 2000);
    expect(breakdown.totalBrl, closeTo(10900, 0.01));
    expect(breakdown.primaryTotal(brPreference), closeTo(10900, 0.01));
    expect(breakdown.internationalSharePercent(brPreference), closeTo(91.74, 0.1));
  });

  test('preferência EUA exibe total em dólar', () {
    final breakdown = computePortfolioBalanceBreakdown(
      holdings: [
        holding(symbol: 'PETR4', currency: HoldingCurrency.brl, price: 50, avg: 40),
      ],
      categoryResolver: (_) => MarketCategory.acoesBr,
      usdBrlRate: 5.0,
    );

    expect(breakdown.primaryTotal(usPreference), 100);
    expect(breakdown.primaryTotal(brPreference), 500);
  });

  test('isBdrSymbol reconhece sufixos B3', () {
    expect(isBdrSymbol('NVDA34', category: MarketCategory.bdr), isTrue);
    expect(isBdrSymbol('AAPL', category: MarketCategory.stocks), isFalse);
  });
}
