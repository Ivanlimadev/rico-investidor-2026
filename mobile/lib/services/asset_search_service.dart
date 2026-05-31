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

import 'package:rico_investidor/core/search/asset_search_config.dart';

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

  Future<List<AssetItem>> searchAsync(String query) async {
    final q = query.trim();
    if (q.length < kMinAssetSearchLength) return const [];

    final seen = <String>{};
    final results = <AssetItem>[];

    await Future.wait([
      _appendQuoteSearch(q, seen, results),
      _appendCurrencySearch(q, seen, results),
      _appendTreasurySearch(q, seen, results),
      _appendIndicesSearch(q, seen, results),
      _appendCryptoSearch(q, seen, results),
      _appendFiiSearch(q, seen, results),
      _appendUsMarketResults(q, seen, results),
    ]);

    return results;
  }

  Future<void> _appendQuoteSearch(String q, Set<String> seen, List<AssetItem> results) async {
    try {
      final stocks = await quoteRepository.search(q, limit: 8);
      for (final asset in stocks) {
        if (seen.add(asset.symbol)) results.add(asset);
      }
    } catch (_) {}
  }

  Future<void> _appendCurrencySearch(String q, Set<String> seen, List<AssetItem> results) async {
    try {
      final currencies = await currencyRepository.searchQuotes(q, limit: 6);
      for (final quote in currencies) {
        if (seen.add(quote.pair)) {
          results.add(quote.toAssetItem());
        }
      }
    } catch (_) {}
  }

  Future<void> _appendTreasurySearch(String q, Set<String> seen, List<AssetItem> results) async {
    try {
      final bonds = await treasuryRepository.searchBonds(q, limit: 6);
      for (final bond in bonds) {
        if (seen.add(bond.symbol)) {
          results.add(bond.toAssetItem());
        }
      }
    } catch (_) {}
  }

  Future<void> _appendIndicesSearch(String q, Set<String> seen, List<AssetItem> results) async {
    try {
      final indices = await indicesRepository.searchIndices(q, limit: 6);
      for (final quote in indices) {
        if (seen.add(quote.symbol)) {
          results.add(quote.toAssetItem());
        }
      }
    } catch (_) {}
  }

  Future<void> _appendCryptoSearch(String q, Set<String> seen, List<AssetItem> results) async {
    try {
      final crypto = await cryptoRepository.searchQuotes(q, limit: 8);
      for (final quote in crypto) {
        if (seen.add(quote.symbol)) {
          results.add(quote.toAssetItem());
        }
      }
    } catch (_) {}
  }

  Future<void> _appendFiiSearch(String q, Set<String> seen, List<AssetItem> results) async {
    try {
      final fiis = await fiiRepository.search(q, limit: 8);
      for (final fii in fiis) {
        if (seen.add(fii.ticker)) {
          results.add(await fiiRepository.summaryToAsset(fii));
        }
      }
    } catch (_) {}
  }

  Future<AssetItem?> findBySymbolAsync(String symbol) async {
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
    if (categoryForSymbol(symbol) == MarketCategory.cripto || _looksLikeCryptoSymbol(symbol)) {
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

    if (_looksLikeUsTicker(symbol)) {
      try {
        final quote = await globalMarketRepository.getDetail(symbol.trim());
        return quote.quote;
      } catch (_) {}
    }

    return quoteRepository.resolveAsset(symbol);
  }

  MarketCategory? categoryForSymbol(String symbol) {
    final normalizedCurrency = symbol.trim().toUpperCase().replaceAll('/', '-');
    if (normalizedCurrency.contains('-BRL')) return MarketCategory.moeda;
    if (symbol.trim().toLowerCase().startsWith('tesouro-')) return MarketCategory.tesouroDireto;
    if (_looksLikeIndexSymbol(symbol)) return MarketCategory.indices;
    if (_looksLikeCryptoSymbol(symbol)) return MarketCategory.cripto;
    if (isFiiTicker(symbol)) return MarketCategory.fiis;
    if (symbol.endsWith('34')) return MarketCategory.bdr;
    if (symbol.endsWith('11')) return MarketCategory.etf;
    if (_looksLikeUsTicker(symbol)) return MarketCategory.stocks;
    return MarketCategory.acoesBr;
  }

  Future<void> _appendUsMarketResults(
    String query,
    Set<String> seen,
    List<AssetItem> results,
  ) async {
    for (final category in ['stocks', 'reits']) {
      try {
        final response = await globalMarketRepository.listUsMarketWithRetry(
          category: category,
          page: 1,
          limit: category == 'stocks' ? 8 : 4,
          search: query,
        );
        final mappedCategory =
            category == 'reits' ? MarketCategory.reits : MarketCategory.stocks;
        for (final quote in response.items) {
          final asset = quote.toUsAssetItem(category: mappedCategory);
          if (seen.add(asset.symbol)) {
            results.add(asset);
          }
        }
      } catch (_) {}
    }
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

bool _looksLikeCryptoSymbol(String symbol) {
  final normalized = symbol.trim().toUpperCase();
  if (normalized.contains('-') || normalized.contains('/')) return false;
  if (normalized.length < 2 || normalized.length > 12) return false;
  if (RegExp(r'\d$').hasMatch(normalized) && normalized.length >= 5) return false;
  return RegExp(r'^[A-Z0-9]+$').hasMatch(normalized);
}
