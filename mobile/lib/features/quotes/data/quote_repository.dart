import 'package:rico_investidor/core/cache/session_cache.dart';
import 'package:rico_investidor/features/fii/utils/fii_quote_chart.dart';
import 'package:rico_investidor/features/fii/utils/fii_ticker.dart';
import 'package:rico_investidor/features/quotes/data/quote_api_client.dart';
import 'package:rico_investidor/features/quotes/models/stock_catalog.dart';
import 'package:rico_investidor/features/quotes/models/stock_compare.dart';
import 'package:rico_investidor/features/quotes/models/stock_fundamental_history.dart';
import 'package:rico_investidor/features/quotes/models/stock_financials.dart';
import 'package:rico_investidor/features/quotes/models/stock_quote_detail.dart';
import 'package:rico_investidor/features/quotes/models/stock_macro.dart';
import 'package:rico_investidor/features/quotes/models/stock_performance.dart';
import 'package:rico_investidor/features/quotes/models/stock_screener.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/fii_models.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/state/portfolio_state.dart';

class QuoteRepository {
  QuoteRepository({QuoteApiClient? api}) : _api = api ?? QuoteApiClient();

  final QuoteApiClient _api;
  final Map<MarketCategory, List<StockCatalogItemDto>> _catalogByCategory = {};
  final _featuredCache = SessionCache<List<AssetItem>>(ttl: const Duration(minutes: 5));
  final _heatmapCache = SessionCache<QuoteListResponse>(ttl: const Duration(minutes: 5));
  final _macroCache = SessionCache<BrazilMacroDto>(ttl: const Duration(minutes: 30));
  final Map<String, SessionCache<StockQuoteDetailDto>> _detailCache = {};
  final Map<String, Future<StockQuoteDetailDto>> _detailInFlight = {};
  Future<QuoteListResponse>? _heatmapFuture;
  Future<List<AssetItem>>? _featuredFuture;

  String _detailCacheKey(String symbol, int candleLimit, int dividendLimit) =>
      '${symbol.toUpperCase()}:$candleLimit:$dividendLimit';

  SessionCache<StockQuoteDetailDto> _detailCacheFor(String key) {
    return _detailCache.putIfAbsent(
      key,
      () => SessionCache<StockQuoteDetailDto>(ttl: const Duration(minutes: 10)),
    );
  }

  bool supportsCategory(MarketCategory category) {
    return switch (category) {
      MarketCategory.acoesBr ||
      MarketCategory.bdr ||
      MarketCategory.etf ||
      MarketCategory.etfInternacional =>
        true,
      _ => false,
    };
  }

  Future<List<AssetItem>> featuredStocks() {
    final cached = _featuredCache.get();
    if (cached != null) return Future.value(cached);
    return _featuredFuture ??= _loadFeaturedStocks();
  }

  void invalidateFeaturedCache() {
    _featuredCache.clear();
    _featuredFuture = null;
  }

  Future<List<AssetItem>> _loadFeaturedStocks() async {
    final response = await _api.featured();
    final items = response.items.map((e) => e.toAssetItem()).toList();
    _featuredCache.set(items);
    return items;
  }

  Future<List<AssetItem>> search(String query, {int limit = 12}) async {
    final q = query.trim();
    if (q.length < 2) return const [];

    try {
      final response = await _api.search(q, limit: limit);
      if (response.items.isNotEmpty) {
        return response.items.map((e) => e.toAssetItem()).toList();
      }
    } catch (_) {}

    return _searchCatalog(q, limit: limit);
  }

  Future<List<StockCatalogItemDto>> loadCatalog(MarketCategory category) async {
    final cached = _catalogByCategory[category];
    if (cached != null) return cached;

    final slug = _categorySlug(category);
    final response = await _api.getCatalog(slug);
    _catalogByCategory[category] = response.items;
    return response.items;
  }

  Future<List<AssetItem>> _searchCatalog(String query, {required int limit}) async {
    final lower = query.toLowerCase();
    final results = <AssetItem>[];
    final seen = <String>{};

    for (final category in [MarketCategory.acoesBr, MarketCategory.bdr, MarketCategory.etf]) {
      if (!supportsCategory(category)) continue;
      final catalog = await loadCatalog(category);
      for (final item in catalog) {
        if (!seen.add(item.symbol)) continue;
        final haystack = '${item.symbol} ${item.name}'.toLowerCase();
        if (haystack.contains(lower)) {
          results.add(item.toAssetItem());
          if (results.length >= limit) return results;
        }
      }
    }

    return results;
  }

  String _categorySlug(MarketCategory category) {
    return switch (category) {
      MarketCategory.bdr => 'bdr',
      MarketCategory.etf => 'etf',
      MarketCategory.etfInternacional => 'etf_intl',
      _ => 'acoes_br',
    };
  }

  Future<List<AssetItem>> listByCategory(MarketCategory category, {int limit = 30}) async {
    if (!supportsCategory(category)) return const [];
    final response = await _api.listByCategory(category, limit: limit);
    return response.items.map((e) => e.toAssetItem()).toList();
  }

  Future<MarketQuoteDto> getQuote(String symbol) {
    return _api.getQuote(symbol);
  }

  static const defaultCandleLimit = 252;
  static const extendedCandleLimit = 1260;
  static const defaultDividendLimit = 120;
  static const extendedDividendLimit = 500;

  Future<StockQuoteDetailDto> getStockDetail(
    String symbol, {
    int candleLimit = defaultCandleLimit,
    int dividendLimit = defaultDividendLimit,
  }) {
    final key = _detailCacheKey(symbol, candleLimit, dividendLimit);
    final cache = _detailCacheFor(key);
    final cached = cache.get();
    if (cached != null) return Future.value(cached);

    final inFlight = _detailInFlight[key];
    if (inFlight != null) return inFlight;

    final future = _api
        .getDetail(
          symbol,
          candleLimit: candleLimit,
          dividendLimit: dividendLimit,
        )
        .then((detail) {
      cache.set(detail);
      _detailInFlight.remove(key);
      return detail;
    }).catchError((Object error, StackTrace stack) {
      _detailInFlight.remove(key);
      Error.throwWithStackTrace(error, stack);
    });
    _detailInFlight[key] = future;
    return future;
  }

  Future<List<FiiCandleBar>> getStockCandles(String symbol, {FiiQuotePeriod? period}) async {
    final effective = period ?? FiiQuotePeriod.year1;
    final response = await _api.getCandles(
      symbol,
      range: rangeForQuotePeriod(effective),
      limit: limitForQuotePeriod(effective),
      interval: intervalForQuotePeriod(effective),
    );
    return response.candles;
  }

  Future<BrazilMacroDto> getBrazilMacro({bool forceRefresh = false}) async {
    if (forceRefresh) _macroCache.clear();
    final cached = _macroCache.get();
    if (cached != null) return cached;
    final result = await _api.getBrazilMacro();
    _macroCache.set(result);
    return result;
  }

  void invalidateStockDetail(
    String symbol, {
    int candleLimit = extendedCandleLimit,
    int dividendLimit = extendedDividendLimit,
  }) {
    final key = _detailCacheKey(symbol, candleLimit, dividendLimit);
    _detailCache.remove(key);
    _detailInFlight.remove(key);
  }

  Future<DictionaryResponseDto> getFundamentalsDictionary() {
    return _api.getDictionary(category: 'statistics');
  }

  Future<StockFinancialsDto> getStockFinancials(
    String symbol, {
    int limit = 8,
    String period = 'quarterly',
  }) {
    return _api.getFinancials(symbol, limit: limit, period: period);
  }

  Future<StockFundamentalHistoryDto> getFundamentalHistory(String symbol, {int limit = 12}) {
    return _api.getFundamentalHistory(symbol, limit: limit);
  }

  Future<StockPerformanceDto> getStockPerformance(
    String symbol, {
    FiiQuotePeriod? period,
    String benchmark = '^BVSP',
  }) {
    final effective = period ?? FiiQuotePeriod.year1;
    return _api.getPerformance(
      symbol,
      range: rangeForQuotePeriod(effective),
      limit: limitForQuotePeriod(effective),
      benchmark: benchmark,
    );
  }

  Future<StockScreenerResponseDto> screener(Map<String, String> query) {
    return _api.screener(query);
  }

  Future<QuoteListResponse> getHeatmap({int limit = 18}) {
    final cached = _heatmapCache.get();
    if (cached != null) return Future.value(cached);

    return _heatmapFuture ??= _loadHeatmap(limit: limit);
  }

  Future<QuoteListResponse> _loadHeatmap({required int limit}) async {
    try {
      final response = await _api.getHeatmap(limit: limit);
      _heatmapCache.set(response);
      return response;
    } finally {
      _heatmapFuture = null;
    }
  }

  Future<StockCompareResponseDto> compareStocks(List<String> tickers) {
    return _api.compare(tickers);
  }

  Future<AssetItem?> resolveAsset(String symbol) async {
    if (isFiiTicker(symbol)) return null;
    try {
      final quote = await _api.getQuote(symbol);
      return quote.toAssetItem();
    } catch (_) {
      return null;
    }
  }

  Future<bool> refreshPortfolioPrices(PortfolioState portfolio) async {
    final symbols = portfolio.holdings.map((h) => h.symbol).toList();
    if (symbols.isEmpty) return true;

    try {
      final response = await _api.batch(symbols);
      final bySymbol = {
        for (final item in response.items) item.symbol: item.toAssetItem(),
      };
      for (var i = 0; i < portfolio.holdings.length; i++) {
        final holding = portfolio.holdings[i];
        final quote = bySymbol[holding.symbol];
        if (quote != null && quote.price > 0) {
          portfolio.holdings[i] = holding.copyWith(
            currentPrice: quote.price,
            changePercent: quote.changePercent,
          );
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> refreshPortfolioStockPrices(PortfolioState portfolio) async {
    return refreshPortfolioPrices(portfolio);
  }
}

final quoteRepository = QuoteRepository();
