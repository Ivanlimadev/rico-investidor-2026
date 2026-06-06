import 'package:rico_investidor/core/cache/bounded_session_cache_map.dart';
import 'package:rico_investidor/core/cache/session_cache.dart';
import 'package:rico_investidor/core/utils/asset_logo_url.dart';
import 'package:rico_investidor/features/fii/data/fii_api_client.dart';
import 'package:rico_investidor/features/fii/utils/fii_related.dart';
import 'package:rico_investidor/features/fii/utils/fii_screener_presets.dart';
import 'package:rico_investidor/features/fii/utils/fii_ticker.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/fii_models.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/state/portfolio_state.dart';

class FiiRepository {
  FiiRepository({FiiApiClient? api}) : _api = api ?? FiiApiClient();

  static const defaultDistributionYears = 5;
  static const extendedDistributionYears = 15;
  static const defaultHistoryLimit = 24;
  static const extendedHistoryLimit = 120;
  static const defaultCandleLimit = 252;
  static const extendedCandleLimit = 1260;

  final FiiApiClient _api;

  List<FiiSummary>? _catalog;
  Future<List<FiiSummary>>? _catalogFuture;
  int? _totalCount;
  Future<int>? _totalCountFuture;
  final _featuredCache = SessionCache<List<FiiScreenerItem>>(ttl: const Duration(minutes: 5));
  Future<List<FiiScreenerItem>>? _featuredFuture;
  final _detailCache = BoundedSessionCacheMap<FiiDetail>();
  final _distributionsCache = BoundedSessionCacheMap<FiiDistributions>();
  final _historyCache = BoundedSessionCacheMap<FiiHistoryResponse>();
  final _candlesCache = BoundedSessionCacheMap<FiiCandlesResponse>();
  final _relatedCache = BoundedSessionCacheMap<List<FiiScreenerItem>>();
  final Map<String, Future<FiiDetail>> _detailInFlight = {};

  SessionCache<T> _cacheFor<T>(BoundedSessionCacheMap<T> store, String key) {
    return store.cacheFor(key);
  }

  Future<int> totalCount() {
    if (_totalCount != null) return Future.value(_totalCount!);
    return _totalCountFuture ??= _fetchTotalCount();
  }

  Future<int> _fetchTotalCount() async {
    try {
      final response = await _api.countFiis();
      _totalCount = response.total;
      return response.total;
    } catch (_) {
      final catalog = await loadCatalog();
      _totalCount = catalog.length;
      return catalog.length;
    }
  }

  Future<List<FiiSummary>> loadCatalog() {
    if (_catalog != null) return Future.value(_catalog!);
    return _catalogFuture ??= _fetchCatalog().whenComplete(() => _catalogFuture = null);
  }

  Future<List<FiiSummary>> _fetchCatalog() async {
    final items = <FiiSummary>[];
    var offset = 0;
    const pageSize = 500;

    while (true) {
      final page = await _api.listFiis(limit: pageSize, offset: offset);
      items.addAll(page.fiis);
      offset += page.count;
      if (offset >= page.total || page.count == 0) break;
    }

    _catalog = items;
    _totalCount = items.length;
    return items;
  }

  Future<List<FiiSummary>> search(String query, {int limit = 20}) async {
    final q = query.trim();
    if (q.isEmpty) {
      final catalog = await loadCatalog();
      return catalog.take(limit).toList();
    }

    try {
      final response = await _api.searchFiis(q, limit: limit);
      return response.fiis;
    } catch (_) {
      final catalog = await loadCatalog();
      final lower = q.toLowerCase();
      return catalog
          .where((f) => _matchesFiiSearchQuery(f, lower))
          .take(limit)
          .toList();
    }
  }

  bool _matchesFiiSearchQuery(FiiSummary fii, String lowerQuery) {
    final ticker = fii.ticker.toLowerCase();
    final name = fii.name.toLowerCase();
    if (ticker.contains(lowerQuery) || name.contains(lowerQuery)) return true;

    final root = _fourLetterRoot(lowerQuery.toUpperCase());
    if (root != null && ticker.startsWith(root.toLowerCase())) return true;

    return false;
  }

  Future<List<FiiSummary>> searchByRoot(String query, {int limit = 12}) async {
    final root = _fourLetterRoot(query);
    if (root == null) return const [];

    final catalog = await loadCatalog();
    return catalog
        .where((f) => f.ticker.toUpperCase().startsWith(root))
        .take(limit)
        .toList();
  }

  String? _fourLetterRoot(String query) {
    final normalized = query.trim().toUpperCase().replaceAll('.SA', '');
    final match = RegExp(r'^([A-Z]{4})').firstMatch(normalized);
    return match?.group(1);
  }

  /// Ativo leve para listas/busca — sem fetch de detalhe; logo via proxy local.
  AssetItem summaryToSearchAsset(FiiSummary summary) {
    return AssetItem(
      symbol: summary.ticker,
      name: summary.name,
      category: MarketCategory.fiis,
      price: 0,
      changePercent: 0,
      logoUrl: assetLogoApiUrl(summary.ticker, isFii: true),
    );
  }

  Future<FiiDetail> getDetail(String ticker) {
    final normalized = normalizeFiiTicker(ticker);
    final cache = _detailCache.cacheFor(normalized);
    final cached = cache.get();
    if (cached != null) return Future.value(cached);

    final inFlight = _detailInFlight[normalized];
    if (inFlight != null) return inFlight;

    final future = _api.getFii(normalized).then((detail) {
      cache.set(detail);
      _detailInFlight.remove(normalized);
      return detail;
    }).catchError((Object error, StackTrace stack) {
      _detailInFlight.remove(normalized);
      Error.throwWithStackTrace(error, stack);
    });
    _detailInFlight[normalized] = future;
    return future;
  }

  Future<FiiDistributions> getDistributions(String ticker, {int years = 5}) async {
    final key = '${normalizeFiiTicker(ticker)}:$years';
    final cache = _cacheFor(_distributionsCache, key);
    final cached = cache.get();
    if (cached != null) return cached;

    final result = await _api.getDistributions(ticker, years: years);
    cache.set(result);
    return result;
  }

  Future<FiiHistoryResponse> getHistory(String ticker, {int limit = 24}) async {
    final key = '${normalizeFiiTicker(ticker)}:$limit';
    final cache = _cacheFor(_historyCache, key);
    final cached = cache.get();
    if (cached != null) return cached;

    final result = await _api.getHistory(ticker, limit: limit);
    cache.set(result);
    return result;
  }

  Future<FiiCandlesResponse> getCandles(
    String ticker, {
    int limit = 252,
    String? start,
    String? end,
  }) async {
    final key = '${normalizeFiiTicker(ticker)}:$limit:${start ?? ''}:${end ?? ''}';
    final cache = _cacheFor(_candlesCache, key);
    final cached = cache.get();
    if (cached != null) return cached;

    final result = await _api.getCandles(ticker, limit: limit, start: start, end: end);
    cache.set(result);
    return result;
  }

  Future<FiiTenantsResponse> getTenants(String ticker) {
    return _api.getTenants(ticker);
  }

  Future<FiiScreenerResponse> screener(Map<String, String> params) {
    return _api.screener(params);
  }

  Future<List<FiiScreenerItem>> featuredFiis() {
    final cached = _featuredCache.get();
    if (cached != null) return Future.value(cached);
    return _featuredFuture ??= _loadFeaturedFiis();
  }

  Future<List<FiiScreenerItem>> _loadFeaturedFiis() async {
    final response = await screener(fiiFeaturedScreenerParams);
    if (response.data.isEmpty) {
      throw StateError('Nenhum FII em destaque');
    }
    _featuredCache.set(response.data);
    return response.data;
  }

  void invalidateFeatured() {
    _featuredCache.clear();
    _featuredFuture = null;
  }

  Future<List<FiiScreenerItem>> relatedFiis(FiiDetail detail, {int limit = relatedFiisLimit}) async {
    final cacheKey = '${detail.ticker}:${detail.segment ?? ''}:${detail.fundType ?? ''}:$limit';
    final cache = _relatedCache.cacheFor(
      cacheKey,
      ttl: const Duration(minutes: 15),
    );
    final cached = cache.get();
    if (cached != null) return cached;

    final candidates = <FiiScreenerItem>[];
    final seen = <String>{};

    void addItems(Iterable<FiiScreenerItem> items) {
      for (final item in items) {
        if (seen.add(item.ticker)) candidates.add(item);
      }
    }

    Future<void> tryScreener(Map<String, String> params) async {
      try {
        final response = await screener({...params, 'limit': '40'});
        addItems(response.data);
      } catch (_) {}
    }

    if (detail.segment != null && detail.fundType != null) {
      await tryScreener({'segment': detail.segment!, 'fund_type': detail.fundType!});
    }
    if (candidates.length < limit * 2 && detail.segment != null) {
      await tryScreener({'segment': detail.segment!});
    }
    if (candidates.length < limit * 2 && detail.fundType != null) {
      await tryScreener({'fund_type': detail.fundType!});
    }

    var picked = pickRelatedFiis(detail: detail, candidates: candidates, limit: limit);
    if (picked.length >= limit) {
      cache.set(picked);
      return picked;
    }

    try {
      final catalog = await loadCatalog();
      final screenerLike = catalog.map(
        (s) => FiiScreenerItem(
          ticker: s.ticker,
          name: s.name,
          segment: s.segment,
          managementType: s.managementType,
        ),
      );
      addItems(screenerLike);
      picked = pickRelatedFiis(detail: detail, candidates: candidates, limit: limit);
    } catch (_) {}

    if (picked.isNotEmpty) {
      cache.set(picked);
      return picked;
    }

    try {
      final fallback = await screener({'limit': '40', 'sort': 'dividend_yield_ttm', 'order': 'desc'});
      picked = pickRelatedFiis(detail: detail, candidates: fallback.data, limit: limit);
    } catch (_) {}

    cache.set(picked);
    return picked;
  }

  Future<void> refreshPortfolioFiiPrices(PortfolioState portfolio) async {
    // Preços de FIIs são atualizados via batch em QuoteRepository.refreshPortfolioPrices.
  }

  Future<AssetItem?> resolveAsset(String symbol) async {
    if (!isFiiTicker(symbol)) return null;

    try {
      final detail = await getDetail(symbol);
      return AssetItem(
        symbol: detail.ticker,
        name: detail.name,
        category: MarketCategory.fiis,
        price: detail.closePrice ?? 0,
        changePercent: 0,
        logoUrl: assetLogoApiUrl(detail.ticker, isFii: true),
      );
    } catch (_) {
      return null;
    }
  }

  Future<AssetItem> summaryToAsset(FiiSummary summary) async {
    try {
      final detail = await getDetail(summary.ticker);
      final asset = summaryToSearchAsset(summary);
      return AssetItem(
        symbol: detail.ticker,
        name: detail.name,
        category: asset.category,
        price: detail.closePrice ?? 0,
        changePercent: asset.changePercent,
        logoUrl: asset.logoUrl,
      );
    } catch (_) {
      return summaryToSearchAsset(summary);
    }
  }

  void invalidateDetail(String ticker) {
    final normalized = normalizeFiiTicker(ticker);
    _detailCache.remove(normalized);
    _detailInFlight.remove(normalized);
  }

  void invalidate() {
    _catalog = null;
    _catalogFuture = null;
    _totalCount = null;
    _totalCountFuture = null;
    invalidateFeatured();
    _detailCache.clear();
    _detailInFlight.clear();
  }
}

final fiiRepository = FiiRepository();
