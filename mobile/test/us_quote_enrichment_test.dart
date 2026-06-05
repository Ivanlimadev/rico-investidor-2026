import 'package:flutter_test/flutter_test.dart';
import 'package:rico_investidor/features/global_markets/models/global_market_models.dart';
import 'package:rico_investidor/features/global_markets/utils/us_quote_enrichment.dart';
import 'package:rico_investidor/features/quotes/data/quote_api_client.dart';

void main() {
  test('reconcileQuote skips trailing zero candles from Marketstack', () {
    const quote = MarketQuoteDto(
      symbol: 'META',
      name: 'Meta Platforms',
      price: 0,
      changePercent: 0,
      category: 'stocks',
      provider: 'marketstack',
    );
    final candles = [
      const GlobalStockCandleDto(date: '2026-06-02', close: 597.63),
      const GlobalStockCandleDto(date: '2026-06-03', close: 622.98),
      const GlobalStockCandleDto(date: '2026-06-04', close: 0, adjClose: 0),
    ];

    final reconciled = UsQuoteEnrichment.reconcileQuote(quote, candles);

    expect(reconciled.price, closeTo(622.98, 0.01));
    expect(reconciled.previousClose, closeTo(597.63, 0.01));
    expect(reconciled.sessionDate, '2026-06-03');
  });
}
