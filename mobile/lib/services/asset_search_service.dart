import 'package:rico_investidor/core/markets/market_visibility.dart';
import 'package:rico_investidor/core/search/asset_search_config.dart';
import 'package:rico_investidor/core/search/asset_search_ranking.dart';
import 'package:rico_investidor/core/utils/crypto_ticker_utils.dart';
import 'package:rico_investidor/features/crypto/data/crypto_repository.dart';
import 'package:rico_investidor/features/crypto/models/crypto_models.dart';
import 'package:rico_investidor/features/global_markets/data/global_market_repository.dart'
    as global_markets;
import 'package:rico_investidor/features/global_markets/models/global_market_models.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/services/market_preference_storage.dart';

/// Busca unificada — mercado americano (ações/REITs) + cripto.
class AssetSearchService {
  AssetSearchService({
    global_markets.GlobalMarketRepository? globalMarketRepository,
  }) : globalMarketRepository =
            globalMarketRepository ?? global_markets.globalMarketRepository;

  final global_markets.GlobalMarketRepository globalMarketRepository;

  Future<List<AssetItem>> searchAsync(
    String query, {
    MarketPreference? preferredMarket,
  }) async {
    final q = query.trim();
    if (q.length < kMinAssetSearchLength) return const [];

    final normalized = q.toUpperCase();
    final preferredCountryCode = preferredMarket?.code;
    final seen = <String>{};
    final results = <AssetItem>[];

    if (shouldTryExactSymbolLookup(normalized)) {
      final exact = await findBySymbolAsync(
        normalized,
        preferredMarket: preferredMarket,
      );
      if (exact != null && seen.add(exact.symbol)) {
        results.add(exact);
      }
    }

    await Future.wait([
      _appendCryptoSearch(q, seen, results, limit: 8),
      if (_looksLikeUsTicker(normalized) || q.length >= 2)
        _appendUsMarketResults(q, seen, results, limit: 6),
    ]);

    final ranked = rankAndDedupeSearchResults(
      results,
      q,
      preferredCountryCode: preferredCountryCode,
    );
    return ranked.take(kMaxSearchResults).toList();
  }

  Future<void> _appendCryptoSearch(
    String q,
    Set<String> seen,
    List<AssetItem> results, {
    required int limit,
  }) async {
    try {
      final crypto = await cryptoRepository.searchQuotes(q, limit: limit);
      for (final quote in crypto) {
        if (seen.add(quote.symbol)) {
          results.add(quote.toAssetItem());
        }
      }
    } catch (_) {}
  }

  Future<AssetItem?> findBySymbolAsync(
    String symbol, {
    MarketPreference? preferredMarket,
  }) async {
    final normalizedCrypto = normalizeCryptoSymbol(symbol);
    if (categoryForSymbol(symbol) == MarketCategory.cripto ||
        looksLikeObviousCryptoTicker(symbol)) {
      try {
        final detail = await cryptoRepository.getDetail(normalizedCrypto);
        return detail.quote.toAssetItem();
      } catch (_) {
        return null;
      }
    }

    if (_looksLikeUsTicker(symbol)) {
      try {
        final detail = await globalMarketRepository.getDetail(symbol.trim());
        return detail.quote;
      } catch (_) {}
    }

    return null;
  }

  MarketCategory? categoryForSymbol(String symbol) {
    if (looksLikeObviousCryptoTicker(symbol)) return MarketCategory.cripto;
    if (_looksLikeUsTicker(symbol)) return MarketCategory.stocks;
    return MarketCategory.stocks;
  }

  Future<void> _appendUsMarketResults(
    String query,
    Set<String> seen,
    List<AssetItem> results, {
    required int limit,
  }) async {
    try {
      final response = await globalMarketRepository.listUsMarketWithRetry(
        category: 'stocks',
        page: 1,
        limit: limit,
        search: query,
      );
      for (final quote in response.items) {
        final asset = quote.toUsAssetItem();
        if (seen.add(asset.symbol)) {
          results.add(asset);
        }
      }
    } catch (_) {}

    try {
      final response = await globalMarketRepository.listUsMarketWithRetry(
        category: 'reits',
        page: 1,
        limit: (limit / 2).ceil().clamp(2, limit),
        search: query,
      );
      for (final quote in response.items) {
        final asset = quote.toUsAssetItem(category: MarketCategory.reits);
        if (seen.add(asset.symbol)) {
          results.add(asset);
        }
      }
    } catch (_) {}
  }
}

final assetSearchService = AssetSearchService();

bool _looksLikeUsTicker(String symbol) {
  final normalized = symbol.trim().toUpperCase();
  if (normalized.endsWith('.SA')) return false;
  if (RegExp(r'^[A-Z]{4}\d{1,2}$').hasMatch(normalized)) return false;
  if (normalized.endsWith('11')) return false;
  return RegExp(r'^[A-Z]{1,5}([.-][A-Z])?$').hasMatch(normalized);
}
