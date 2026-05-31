import 'package:flutter_test/flutter_test.dart';
import 'package:rico_investidor/core/search/asset_search_ranking.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/market_category.dart';

AssetItem _asset(String symbol, {String? name, MarketCategory category = MarketCategory.cripto}) {
  return AssetItem(
    symbol: symbol,
    name: name ?? symbol,
    category: category,
    price: 1,
    changePercent: 0,
  );
}

void main() {
  test('exact symbol ranks first for BTC', () {
    final items = [
      _asset('WBTC', name: 'Wrapped Bitcoin'),
      _asset('BTC', name: 'Bitcoin'),
      _asset('BTCDOM', name: 'BTC Dominance'),
    ];

    final ranked = rankAndDedupeSearchResults(items, 'BTC');

    expect(ranked.first.symbol, 'BTC');
  });

  test('prefix symbol ranks before substring match', () {
    final items = [
      _asset('PETR3', category: MarketCategory.acoesBr),
      _asset('PETR4', category: MarketCategory.acoesBr),
    ];

    final ranked = rankAndDedupeSearchResults(items, 'PETR');

    expect(ranked.first.symbol, 'PETR3');
    expect(ranked.last.symbol, 'PETR4');
  });

  test('looksLikeObviousCryptoTicker accepts BTC', () {
    expect(looksLikeObviousCryptoTicker('BTC'), isTrue);
    expect(looksLikeObviousCryptoTicker('PETR4'), isFalse);
    expect(looksLikeObviousCryptoTicker('KLBN'), isTrue);
  });

  test('B3 prefix enables quote search and root extraction', () {
    expect(looksLikeB3FourLetterPrefix('KLBN'), isTrue);
    expect(b3TickerRoot('KLBN4'), 'KLBN');
    expect(b3TickerRoot('KLBN11'), 'KLBN');
    expect(shouldRunB3QuoteSearch('KLBN'), isTrue);
    expect(shouldTryExactSymbolLookup('KLBN'), isTrue);
  });

  test('same B3 root ranks related tickers for KLBN4', () {
    final items = [
      _asset('KLBN11', category: MarketCategory.fiis),
      _asset('KLBN4', category: MarketCategory.acoesBr),
      _asset('KLBN3', category: MarketCategory.acoesBr),
    ];

    final ranked = rankAndDedupeSearchResults(items, 'KLBN4');

    expect(ranked.map((a) => a.symbol), containsAll(['KLBN4', 'KLBN11', 'KLBN3']));
    expect(ranked.first.symbol, 'KLBN4');
  });
}
