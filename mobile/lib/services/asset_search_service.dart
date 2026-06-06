import 'package:rico_investidor/core/search/asset_search_config.dart';
import 'package:rico_investidor/core/search/asset_search_ranking.dart';
import 'package:rico_investidor/features/crypto/data/crypto_repository.dart';
import 'package:rico_investidor/features/crypto/models/crypto_models.dart';
import 'package:rico_investidor/features/currency/data/currency_repository.dart';
import 'package:rico_investidor/features/global_markets/data/global_market_repository.dart'
    as global_markets;
import 'package:rico_investidor/features/global_markets/models/global_market_models.dart';
import 'package:rico_investidor/features/indices/data/indices_repository.dart';
import 'package:rico_investidor/features/indices/models/indices_models.dart';
import 'package:rico_investidor/features/treasury/data/treasury_repository.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/fii/utils/fii_ticker.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/services/market_preference_storage.dart';

class AssetSearchService {
  AssetSearchService({
    FiiRepository? fiiRepository,
    QuoteRepository? quoteRepository,
    global_markets.GlobalMarketRepository? globalMarketRepository,
  })  : fiiRepository = fiiRepository ?? FiiRepository(),
        quoteRepository = quoteRepository ?? QuoteRepository(),
        globalMarketRepository =
            globalMarketRepository ?? global_markets.globalMarketRepository;

  final FiiRepository fiiRepository;
  final QuoteRepository quoteRepository;
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

    final tasks = <Future<void>>[];

    tasks.add(_appendCryptoSearch(q, seen, results, limit: 8));

    if (shouldRunB3QuoteSearch(normalized)) {
      tasks.add(_appendQuoteSearch(q, seen, results, limit: 8));
    }

    if (looksLikeB3TickerQuery(normalized) ||
        normalized.endsWith('11') ||
        q.length >= 3 ||
        b3TickerRoot(normalized) != null) {
      tasks.add(_appendFiiSearch(q, seen, results, limit: 8));
    }

    if (b3TickerRoot(normalized) != null) {
      tasks.add(_appendB3RootQuoteSearch(q, seen, results, limit: 8));
    }

    if (_looksLikeUsTicker(normalized) || q.length >= 2) {
      tasks.add(_appendUsMarketResults(q, seen, results, limit: 6));
    }

    if (looksLikeCurrencySearchQuery(q)) {
      tasks.add(_appendCurrencySearch(q, seen, results, limit: 4));
    }

    if (looksLikeTreasurySearchQuery(q)) {
      tasks.add(_appendTreasurySearch(q, seen, results, limit: 4));
    }

    if (looksLikeIndexSearchQuery(normalized)) {
      tasks.add(_appendIndicesSearch(q, seen, results, limit: 4));
    }

    await Future.wait(tasks);

    final ranked = rankAndDedupeSearchResults(
      results,
      q,
      preferredCountryCode: preferredCountryCode,
    );
    return ranked.take(kMaxSearchResults).toList();
  }

  Future<void> _appendQuoteSearch(String q, Set<String> seen, List<AssetItem> results, {required int limit}) async {
    try {
      final stocks = await quoteRepository.search(q, limit: limit);
      for (final asset in stocks) {
        if (seen.add(asset.symbol)) results.add(asset);
      }
    } catch (_) {}
  }

  Future<void> _appendCurrencySearch(String q, Set<String> seen, List<AssetItem> results, {required int limit}) async {
    try {
      final currencies = await currencyRepository.searchQuotes(q, limit: limit);
      for (final quote in currencies) {
        if (seen.add(quote.pair)) {
          results.add(quote.toAssetItem());
        }
      }
    } catch (_) {}
  }

  Future<void> _appendTreasurySearch(String q, Set<String> seen, List<AssetItem> results, {required int limit}) async {
    try {
      final bonds = await treasuryRepository.searchBonds(q, limit: limit);
      for (final bond in bonds) {
        if (seen.add(bond.symbol)) {
          results.add(bond.toAssetItem());
        }
      }
    } catch (_) {}
  }

  Future<void> _appendIndicesSearch(String q, Set<String> seen, List<AssetItem> results, {required int limit}) async {
    try {
      final indices = await indicesRepository.searchIndices(q, limit: limit);
      for (final quote in indices) {
        if (seen.add(quote.symbol)) {
          results.add(quote.toAssetItem());
        }
      }
    } catch (_) {}
  }

  Future<void> _appendCryptoSearch(String q, Set<String> seen, List<AssetItem> results, {required int limit}) async {
    try {
      final crypto = await cryptoRepository.searchQuotes(q, limit: limit);
      for (final quote in crypto) {
        if (seen.add(quote.symbol)) {
          results.add(quote.toAssetItem());
        }
      }
    } catch (_) {}
  }

  Future<void> _appendFiiSearch(String q, Set<String> seen, List<AssetItem> results, {required int limit}) async {
    try {
      final fiis = await fiiRepository.search(q, limit: limit);
      for (final summary in fiis) {
        final asset = fiiRepository.summaryToSearchAsset(summary);
        if (seen.add(asset.symbol)) results.add(asset);
      }

      final root = b3TickerRoot(q);
      if (root != null) {
        final related = await fiiRepository.searchByRoot(q, limit: limit);
        for (final summary in related) {
          final asset = fiiRepository.summaryToSearchAsset(summary);
          if (seen.add(asset.symbol)) results.add(asset);
        }
      }
    } catch (_) {}
  }

  Future<void> _appendB3RootQuoteSearch(
    String q,
    Set<String> seen,
    List<AssetItem> results, {
    required int limit,
  }) async {
    final root = b3TickerRoot(q);
    if (root == null) return;

    try {
      final stocks = await quoteRepository.search(root, limit: limit);
      for (final asset in stocks) {
        if (!asset.symbol.toUpperCase().startsWith(root)) continue;
        if (seen.add(asset.symbol)) results.add(asset);
      }
    } catch (_) {}
  }

  Future<AssetItem?> findBySymbolAsync(
    String symbol, {
    MarketPreference? preferredMarket,
  }) async {
    final normalizedCurrency = symbol.trim().toUpperCase().replaceAll('/', '-');
    if (normalizedCurrency.contains('-BRL')) {
      try {
        final detail = await currencyRepository.getDetail(normalizedCurrency);
        return detail.quote.toAssetItem();
      } catch (_) {
        return null;
      }
    }

    final normalizedTreasury = symbol.trim().toLowerCase();
    if (normalizedTreasury.startsWith('tesouro-')) {
      try {
        final detail = await treasuryRepository.getDetail(normalizedTreasury);
        return detail.bond.toAssetItem();
      } catch (_) {
        return null;
      }
    }

    final normalizedIndex = normalizeIndexSymbol(symbol);
    if (categoryForSymbol(symbol) == MarketCategory.indices || normalizedIndex.startsWith('^')) {
      try {
        final detail = await indicesRepository.getDetail(normalizedIndex);
        return detail.quote.toAssetItem();
      } catch (_) {
        return null;
      }
    }

    final normalizedCrypto = normalizeCryptoSymbol(symbol);
    if (categoryForSymbol(symbol) == MarketCategory.cripto || looksLikeObviousCryptoTicker(symbol)) {
      try {
        final detail = await cryptoRepository.getDetail(normalizedCrypto);
        return detail.quote.toAssetItem();
      } catch (_) {
        return null;
      }
    }

    if (isFiiTicker(symbol)) {
      return fiiRepository.resolveAsset(symbol);
    }

    final normalizedUpper = symbol.trim().toUpperCase();
    final isB3FourLetter = looksLikeB3FourLetterPrefix(normalizedUpper);
    final preferBrazil = preferredMarket?.isBrazil ?? true;

    if (isB3FourLetter && preferBrazil) {
      final b3 = await _resolveB3RootSymbol(normalizedUpper);
      if (b3 != null) return b3;
    }

    if (_looksLikeUsTicker(symbol) && (!isB3FourLetter || !preferBrazil)) {
      try {
        final quote = await globalMarketRepository.getDetail(symbol.trim());
        return quote.quote;
      } catch (_) {}
    }

    if (isB3FourLetter) {
      final b3 = await _resolveB3RootSymbol(normalizedUpper);
      if (b3 != null) return b3;
    }

    return quoteRepository.resolveAsset(symbol);
  }

  Future<AssetItem?> _resolveB3RootSymbol(String root) async {
    try {
      final stocks = await quoteRepository.search(root, limit: 8);
      final matches = stocks
          .where((asset) => asset.symbol.toUpperCase().startsWith(root))
          .toList();
      if (matches.isEmpty) return null;
      matches.sort((a, b) => a.symbol.compareTo(b.symbol));
      return matches.first;
    } catch (_) {
      return null;
    }
  }

  MarketCategory? categoryForSymbol(String symbol) {
    final normalizedCurrency = symbol.trim().toUpperCase().replaceAll('/', '-');
    if (normalizedCurrency.contains('-BRL')) return MarketCategory.moeda;
    if (symbol.trim().toLowerCase().startsWith('tesouro-')) return MarketCategory.tesouroDireto;
    if (_looksLikeIndexSymbol(symbol)) return MarketCategory.indices;
    if (looksLikeObviousCryptoTicker(symbol)) return MarketCategory.cripto;
    if (isFiiTicker(symbol)) return MarketCategory.fiis;
    if (symbol.endsWith('34')) return MarketCategory.bdr;
    if (symbol.endsWith('11')) return MarketCategory.etf;
    if (_looksLikeUsTicker(symbol)) return MarketCategory.stocks;
    return MarketCategory.acoesBr;
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
  if (isFiiTicker(normalized)) return false;
  if (normalized.length >= 2) {
    final suffix = normalized.substring(normalized.length - 2);
    if ({'11', '34', '35', '39'}.contains(suffix)) return false;
  }
  return RegExp(r'^[A-Z]{1,5}([.-][A-Z])?$').hasMatch(normalized);
}

bool _looksLikeIndexSymbol(String symbol) {
  final normalized = normalizeIndexSymbol(symbol);
  return normalized.startsWith('^') ||
      {
        'IFIX',
        'IDIV',
        'SMLL',
        'IFNC',
        'IMAT',
        'INDX',
        'IMOB',
        'ICON',
        'IEE',
        'UTIL',
      }.contains(normalized);
}
