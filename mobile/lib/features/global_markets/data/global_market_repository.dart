import 'package:rico_investidor/core/cache/bounded_session_cache_map.dart';
import 'package:rico_investidor/core/cache/session_cache.dart';
import 'package:rico_investidor/core/network/api_exception.dart';
import 'package:rico_investidor/features/global_markets/data/global_market_api_client.dart';
import 'package:rico_investidor/features/global_markets/models/global_market_models.dart';
import 'package:rico_investidor/features/global_markets/utils/us_quote_enrichment.dart';
import 'package:rico_investidor/features/global_markets/utils/marketstack_errors.dart';
import 'package:rico_investidor/features/quotes/models/stock_compare.dart';
import 'package:rico_investidor/features/quotes/models/stock_quote_detail.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/features/quotes/models/market_quote_dto.dart';

class GlobalMarketRepository {
  GlobalMarketRepository({GlobalMarketApiClient? api}) : _api = api ?? GlobalMarketApiClient();

  final GlobalMarketApiClient _api;
  final _capabilitiesCache = SessionCache<GlobalMarketCapabilitiesDto>(ttl: const Duration(hours: 1));
  final _featuredCache = SessionCache<List<AssetItem>>(ttl: const Duration(minutes: 5));
  final _heatmapCache = SessionCache<QuoteListResponse>(ttl: const Duration(minutes: 5));
  final _exchangesCache = SessionCache<WorldExchangesResponseDto>(ttl: const Duration(hours: 6));
  final _detailCache = BoundedSessionCacheMap<GlobalStockDetailDto>();
  final Map<String, Future<GlobalStockDetailDto>> _detailInFlight = {};
  Future<List<AssetItem>>? _featuredFuture;
  Future<QuoteListResponse>? _heatmapFuture;

  String _detailCacheKey(
    String symbol,
    String? exchange,
    int candleLimit,
    int dividendLimit,
    int splitLimit,
  ) =>
      '${symbol.toUpperCase()}:${exchange ?? ''}:$candleLimit:$dividendLimit:$splitLimit';

  SessionCache<GlobalStockDetailDto> _detailCacheFor(String key) {
    return _detailCache.cacheFor(key);
  }

  Future<GlobalMarketCapabilitiesDto> getCapabilities({bool force = false}) async {
    if (!force) {
      final cached = _capabilitiesCache.get();
      if (cached != null) return cached;
    }
    final caps = await _api.getCapabilities();
    _capabilitiesCache.set(caps);
    return caps;
  }

  Duration get quoteRefreshDuration {
    final secs = _capabilitiesCache.get()?.refreshSeconds;
    if (secs != null && secs > 0) {
      return Duration(seconds: secs.clamp(30, 600));
    }
    return const Duration(minutes: 5);
  }

  Duration get _quoteRefreshTtl => quoteRefreshDuration;

  Future<GlobalStockIntradayCandlesResponseDto> getIntradayCandles(
    String symbol, {
    String? exchange,
    int limit = 500,
  }) {
    return _api.getIntradayCandles(symbol, exchange: exchange, limit: limit);
  }

  Future<MarketQuoteDto> refreshQuote(String symbol, {String? exchange}) {
    return _api.getQuote(symbol, exchange: exchange);
  }

  Future<List<AssetItem>> listFeaturedUsAssets() {
    final cached = _featuredCache.get();
    if (cached != null) return Future.value(cached);
    return _featuredFuture ??= _loadFeaturedUs();
  }

  void invalidateFeaturedCache() {
    _featuredCache.clear();
    _featuredFuture = null;
  }

  Future<List<AssetItem>> _loadFeaturedUs() async {
    await getCapabilities();
    final response = await _withRetry(
      () => _api.listFeaturedUs(),
      fallbackMessage: 'Não foi possível carregar destaques do mercado americano.',
    );
    final items = response.items.map((e) => e.toUsAssetItem()).toList();
    _featuredCache.set(items, ttlOverride: _quoteRefreshTtl);
    return items;
  }

  Future<List<AssetItem>> listByCategory(MarketCategory category) async {
    final slug = switch (category) {
      MarketCategory.reits => 'reits',
      MarketCategory.stocks => 'stocks',
      _ => 'stocks',
    };
    final response = await listUsMarketWithRetry(category: slug, page: 1, limit: 30);
    final mappedCategory = category == MarketCategory.reits ? MarketCategory.reits : MarketCategory.stocks;
    return response.items.map((e) => e.toUsAssetItem(category: mappedCategory)).toList();
  }

  Future<QuoteListResponse> getUsHeatmap({int limit = 18, String exchange = 'XNAS'}) {
    final cached = _heatmapCache.get();
    if (cached != null) return Future.value(cached);

    return _heatmapFuture ??= _loadUsHeatmap(limit: limit, exchange: exchange);
  }

  void invalidateHeatmapCache() {
    _heatmapCache.clear();
    _heatmapFuture = null;
  }

  Future<QuoteListResponse> _loadUsHeatmap({
    required int limit,
    required String exchange,
  }) async {
    try {
      final response = await _withRetry(
        () => _api.getUsHeatmap(limit: limit, exchange: exchange),
        fallbackMessage: 'Não foi possível carregar o mapa de calor americano.',
      );
      await getCapabilities();
      _heatmapCache.set(response, ttlOverride: _quoteRefreshTtl);
      return response;
    } finally {
      _heatmapFuture = null;
    }
  }

  Future<WorldExchangesResponseDto> listWorldExchanges() async {
    final cached = _exchangesCache.get();
    if (cached != null) return cached;
    final response = await _api.listWorldExchanges();
    _exchangesCache.set(response);
    return response;
  }

  Future<ExchangeMarketListResponseDto> listCountryMarket(
    String countryCode, {
    int page = 1,
    int limit = 25,
    String? search,
  }) {
    return listCountryMarketWithRetry(
      countryCode,
      page: page,
      limit: limit,
      search: search,
    );
  }

  Future<ExchangeMarketListResponseDto> listCountryMarketWithRetry(
    String countryCode, {
    int page = 1,
    int limit = 25,
    String? search,
  }) {
    return _withRetry(
      () => _api.listCountryMarket(
        countryCode,
        page: page,
        limit: limit,
        search: search,
      ),
      fallbackMessage: 'Não foi possível carregar o mercado deste país.',
    );
  }

  Future<CountryHubResponseDto> getCountryHub(String countryCode) {
    return _withRetry(
      () => _api.getCountryHub(countryCode),
      fallbackMessage: 'Não foi possível carregar o hub deste país.',
    );
  }

  Future<ExchangeMarketListResponseDto> listExchangeMarket(
    String mic, {
    String? exchangeName,
    String? countryCode,
    int page = 1,
    int limit = 25,
    String? search,
  }) {
    return listExchangeMarketWithRetry(
      mic,
      exchangeName: exchangeName,
      countryCode: countryCode,
      page: page,
      limit: limit,
      search: search,
    );
  }

  Future<ExchangeMarketListResponseDto> listExchangeMarketWithRetry(
    String mic, {
    String? exchangeName,
    String? countryCode,
    int page = 1,
    int limit = 25,
    String? search,
  }) {
    return _withRetry(
      () => _api.listExchangeMarket(
        mic,
        exchangeName: exchangeName,
        countryCode: countryCode,
        page: page,
        limit: limit,
        search: search,
      ),
      fallbackMessage: 'Não foi possível carregar os ativos desta bolsa.',
    );
  }

  Future<ExchangeMarketListResponseDto> listUsMarket({
    required String category,
    int page = 1,
    int limit = 25,
    String? search,
  }) {
    return _api.listUsMarket(
      category: category,
      page: page,
      limit: limit,
      search: search,
    );
  }

  Future<ExchangeMarketListResponseDto> listUsMarketWithRetry({
    required String category,
    int page = 1,
    int limit = 25,
    String? search,
  }) {
    return _withRetry(
      () => listUsMarket(
        category: category,
        page: page,
        limit: limit,
        search: search,
      ),
      fallbackMessage: 'Não foi possível carregar o mercado.',
    );
  }

  /// ~252 pregões no 1A; extended pede teto da API para planos com mais histórico.
  static const defaultCandleLimit = 280;
  static const extendedCandleLimit = 1000;
  static const defaultDividendLimit = 24;
  static const extendedDividendLimit = 100;

  Future<GlobalStockDetailDto> getDetail(
    String symbol, {
    String? exchange,
    int candleLimit = defaultCandleLimit,
    int dividendLimit = defaultDividendLimit,
    int splitLimit = 50,
  }) {
    final key = _detailCacheKey(symbol, exchange, candleLimit, dividendLimit, splitLimit);
    final cache = _detailCacheFor(key);
    final cached = cache.get();
    if (cached != null) return Future.value(cached);

    final inFlight = _detailInFlight[key];
    if (inFlight != null) return inFlight;

    final future = _fetchDetail(
      symbol,
      exchange: exchange,
      candleLimit: candleLimit,
      dividendLimit: dividendLimit,
      splitLimit: splitLimit,
    ).then((detail) {
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

  Future<GlobalStockDetailDto> _fetchDetail(
    String symbol, {
    String? exchange,
    required int candleLimit,
    required int dividendLimit,
    required int splitLimit,
  }) async {
    Object? lastError;

    Future<GlobalStockDetailDto> fetch({required bool includeExtras}) async {
      return _mapDetail(
        await _api.getStockDetail(
          symbol,
          exchange: exchange,
          candleLimit: candleLimit,
          dividendLimit: dividendLimit,
          splitLimit: splitLimit,
          includeExtras: includeExtras,
        ),
      );
    }

    // Dividendos, splits e fundamentos só vêm com include_extras=true.
    // Tentar true primeiro; false só como fallback leve se a cota estourar.
    for (final includeExtras in [true, false]) {
      try {
        return await fetch(includeExtras: includeExtras);
      } catch (error) {
        lastError = error;
        if (isMarketstackQuotaError(error)) break;
      }
    }

    try {
      return await _buildLiteDetail(symbol, exchange: exchange);
    } catch (error) {
      lastError = error;
    }

    throw lastError!;
  }

  Future<GlobalStockDetailDto> _buildLiteDetail(String symbol, {String? exchange}) async {
    final quote = await _api.getQuote(symbol, exchange: exchange);
    final resolvedExchange = exchange ?? quote.exchange;
    final candles = await _api.getCandles(
      symbol,
      exchange: resolvedExchange,
      limit: 90,
    );
    final category = quote.category == 'reits' ? MarketCategory.reits : MarketCategory.stocks;

    final reconciled = UsQuoteEnrichment.reconcileQuote(quote, candles.candles);
    final marketStats = UsQuoteEnrichment.marketStatsFrom(reconciled, candles.candles);
    final returns = UsQuoteEnrichment.returnsFrom(
      candles.candles,
      currentPrice: reconciled.price,
    );

    return GlobalStockDetailDto(
      quote: reconciled.toUsAssetItem(category: category),
      quoteMeta: reconciled,
      ticker: GlobalStockTickerInfoDto(
        symbol: quote.symbol,
        name: quote.name,
        exchangeMic: resolvedExchange,
      ),
      company: GlobalStockCompanyProfileDto(symbol: quote.symbol, name: quote.name, exchangeMic: resolvedExchange),
      candles: candles.candles,
      dividends: const [],
      splits: const [],
      dividendsSummary: const GlobalStockDividendsSummaryDto(),
      returns: returns,
      fundamentals: const StockFundamentalsDto(),
      marketStats: marketStats,
      dividendsTotal: 0,
      splitsTotal: 0,
      plan: 'basic',
      dataMode: candles.dataMode,
      historyLimited: candles.historyLimited,
      maxHistoryDays: candles.maxHistoryDays,
      provider: quote.provider,
    );
  }

  Future<T> _withRetry<T>(
    Future<T> Function() action, {
    required String fallbackMessage,
  }) async {
    Object? lastError;
    const delays = [Duration(milliseconds: 250), Duration(milliseconds: 600)];
    for (var attempt = 0; attempt <= delays.length; attempt++) {
      try {
        return await action();
      } catch (error) {
        lastError = error;
        if (isMarketstackQuotaError(error)) break;
        if (attempt < delays.length) {
          await Future<void>.delayed(delays[attempt]);
        }
      }
    }
    if (lastError is ApiException) throw lastError;
    throw lastError ?? Exception(fallbackMessage);
  }

  GlobalStockDetailDto _mapDetail(GlobalStockDetailResponseDto response) {
    final quote = response.quote;
    final category = quote.category == 'reits' ? MarketCategory.reits : MarketCategory.stocks;

    return GlobalStockDetailDto(
      quote: quote.toUsAssetItem(category: category),
      quoteMeta: quote,
      ticker: response.ticker,
      company: response.company,
      candles: response.candles,
      dividends: response.dividends,
      splits: response.splits,
      dividendsSummary: response.dividendsSummary,
      returns: response.returns,
      fundamentals: response.fundamentals,
      marketStats: response.marketStats,
      dividendsTotal: response.dividendsTotal,
      splitsTotal: response.splitsTotal,
      plan: response.plan,
      dataMode: response.dataMode,
      historyLimited: response.historyLimited,
      maxHistoryDays: response.maxHistoryDays,
      realtimeEnabled: response.realtimeEnabled,
      intradayInterval: response.intradayInterval,
      refreshSeconds: response.refreshSeconds,
      provider: response.provider,
    );
  }

  Future<StockCompareResponseDto> compareStocks(List<String> tickers) {
    return _api.compareStocks(tickers);
  }
}

class GlobalStockDetailDto {
  const GlobalStockDetailDto({
    required this.quote,
    required this.quoteMeta,
    required this.ticker,
    required this.company,
    required this.candles,
    required this.dividends,
    required this.splits,
    required this.dividendsSummary,
    required this.returns,
    required this.fundamentals,
    required this.marketStats,
    required this.dividendsTotal,
    required this.splitsTotal,
    required this.plan,
    required this.dataMode,
    required this.historyLimited,
    required this.maxHistoryDays,
    required this.provider,
    this.realtimeEnabled = false,
    this.intradayInterval,
    this.refreshSeconds,
  });

  final AssetItem quote;
  final MarketQuoteDto quoteMeta;
  final GlobalStockTickerInfoDto ticker;
  final GlobalStockCompanyProfileDto company;
  final List<GlobalStockCandleDto> candles;
  final List<GlobalStockDividendDto> dividends;
  final List<GlobalStockSplitDto> splits;
  final GlobalStockDividendsSummaryDto dividendsSummary;
  final List<GlobalStockReturnPeriodDto> returns;
  final StockFundamentalsDto fundamentals;
  final StockMarketStatsDto marketStats;
  final int dividendsTotal;
  final int splitsTotal;
  final String plan;
  final String dataMode;
  final bool historyLimited;
  final int maxHistoryDays;
  final String provider;
  final bool realtimeEnabled;
  final String? intradayInterval;
  final int? refreshSeconds;
}

final globalMarketRepository = GlobalMarketRepository();
