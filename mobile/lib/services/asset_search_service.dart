import 'package:rico_investidor/data/mock_market_data.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/fii/utils/fii_ticker.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/market_category.dart';

class AssetSearchService {
  AssetSearchService({
    FiiRepository? fiiRepository,
    QuoteRepository? quoteRepository,
  })  : fiiRepository = fiiRepository ?? FiiRepository(),
        quoteRepository = quoteRepository ?? QuoteRepository();

  final FiiRepository fiiRepository;
  final QuoteRepository quoteRepository;

  List<AssetItem> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return const [];

    final seen = <String>{};
    final results = <AssetItem>[];

    for (final asset in MockMarketData.allAssets) {
      if (seen.contains(asset.symbol)) continue;
      final matches =
          asset.symbol.toLowerCase().contains(q) || asset.name.toLowerCase().contains(q);
      if (matches) {
        seen.add(asset.symbol);
        results.add(asset);
      }
      if (results.length >= 12) break;
    }
    return results;
  }

  Future<List<AssetItem>> searchAsync(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];

    final seen = <String>{};
    final results = <AssetItem>[];

    try {
      final stocks = await quoteRepository.search(q, limit: 8);
      for (final asset in stocks) {
        if (seen.add(asset.symbol)) results.add(asset);
      }
    } catch (_) {}

    try {
      final fiis = await fiiRepository.search(q, limit: 8);
      for (final fii in fiis) {
        if (seen.add(fii.ticker)) {
          results.add(fiiRepository.summaryToAsset(fii));
        }
      }
    } catch (_) {}

    for (final asset in MockMarketData.allAssets) {
      if (seen.contains(asset.symbol)) continue;
      final lower = q.toLowerCase();
      final matches =
          asset.symbol.toLowerCase().contains(lower) || asset.name.toLowerCase().contains(lower);
      if (matches) {
        seen.add(asset.symbol);
        results.add(asset);
      }
      if (results.length >= 12) break;
    }

    return results;
  }

  AssetItem? findBySymbol(String symbol) {
    for (final asset in MockMarketData.allAssets) {
      if (asset.symbol == symbol) return asset;
    }
    return null;
  }

  Future<AssetItem?> findBySymbolAsync(String symbol) async {
    if (isFiiTicker(symbol)) {
      return fiiRepository.resolveAsset(symbol);
    }

    final quote = await quoteRepository.resolveAsset(symbol);
    if (quote != null) return quote;

    return findBySymbol(symbol);
  }

  MarketCategory? categoryForSymbol(String symbol) {
    if (isFiiTicker(symbol)) return MarketCategory.fiis;
    final mock = findBySymbol(symbol);
    if (mock != null) return mock.category;
    if (symbol.endsWith('34')) return MarketCategory.bdr;
    if (symbol.endsWith('11')) return MarketCategory.etf;
    return MarketCategory.acoesBr;
  }
}
