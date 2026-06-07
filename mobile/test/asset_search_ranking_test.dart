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
      _asset('AAP', category: MarketCategory.stocks),
      _asset('AAPL', category: MarketCategory.stocks),
    ];

    final ranked = rankAndDedupeSearchResults(items, 'AAP');

    expect(ranked.first.symbol, 'AAP');
    expect(ranked.last.symbol, 'AAPL');
  });

  test('looksLikeObviousCryptoTicker accepts BTC', () {
    expect(looksLikeObviousCryptoTicker('BTC'), isTrue);
    expect(looksLikeObviousCryptoTicker('AAPL'), isFalse);
    expect(looksLikeObviousCryptoTicker('MSFT'), isFalse);
  });

  test('preferred market country ranks before foreign match for AAPL', () {
    final items = [
      _asset('AAP', name: 'Other AAP', category: MarketCategory.stocks),
      _asset('AAPL', name: 'Apple', category: MarketCategory.stocks),
      _asset('AAPLW', name: 'Apple Warrant', category: MarketCategory.stocks),
    ];

    final rankedUs = rankAndDedupeSearchResults(items, 'AAPL', preferredCountryCode: 'US');
    expect(rankedUs.first.symbol, 'AAPL');
  });

  test('exact query ranks first among related tickers', () {
    final items = [
      _asset('O', category: MarketCategory.reits),
      _asset('ORCL', category: MarketCategory.stocks),
      _asset('ON', category: MarketCategory.stocks),
    ];

    final ranked = rankAndDedupeSearchResults(items, 'O');

    expect(ranked.first.symbol, 'O');
  });
}
