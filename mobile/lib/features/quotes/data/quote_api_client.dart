import 'package:rico_investidor/core/network/api_client.dart';
import 'package:rico_investidor/core/utils/asset_logo_url.dart';
import 'package:rico_investidor/features/quotes/models/stock_catalog.dart';
import 'package:rico_investidor/features/quotes/models/stock_compare.dart';
import 'package:rico_investidor/features/quotes/models/stock_financials.dart';
import 'package:rico_investidor/features/quotes/models/stock_fundamental_history.dart';
import 'package:rico_investidor/features/quotes/models/stock_quote_detail.dart';
import 'package:rico_investidor/features/quotes/models/stock_macro.dart';
import 'package:rico_investidor/features/quotes/models/stock_performance.dart';
import 'package:rico_investidor/features/quotes/models/stock_screener.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/market_category.dart';

class MarketQuoteDto {
  const MarketQuoteDto({
    required this.symbol,
    required this.name,
    required this.price,
    required this.changePercent,
    required this.category,
    this.provider = 'brapi',
    this.logoUrl,
    this.dividendYield12m,
    this.priceToBook,
  });

  final String symbol;
  final String name;
  final double price;
  final double changePercent;
  final String category;
  final String provider;
  final String? logoUrl;
  final double? dividendYield12m;
  final double? priceToBook;

  factory MarketQuoteDto.fromJson(Map<String, dynamic> json) {
    double? numVal(String key) {
      final value = json[key];
      if (value == null) return null;
      return (value as num).toDouble();
    }

    return MarketQuoteDto(
      symbol: json['symbol'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      changePercent: (json['change_percent'] as num).toDouble(),
      category: json['category'] as String? ?? 'acoes_br',
      provider: json['provider'] as String? ?? 'brapi',
      logoUrl: json['logo_url'] as String?,
      dividendYield12m: numVal('dividend_yield_12m'),
      priceToBook: numVal('price_to_book'),
    );
  }

  AssetItem toAssetItem() {
    return AssetItem(
      symbol: symbol,
      name: name,
      category: _parseCategory(category),
      price: price,
      changePercent: changePercent,
      logoUrl: resolveAssetLogoUrl(symbol, logoUrl, isFii: false),
      dividendYield12m: dividendYield12m,
      priceToBook: priceToBook,
    );
  }

  MarketCategory _parseCategory(String slug) {
    return switch (slug) {
      'bdr' => MarketCategory.bdr,
      'etf' => MarketCategory.etf,
      'etf_intl' => MarketCategory.etfInternacional,
      'fiis' => MarketCategory.fiis,
      _ => MarketCategory.acoesBr,
    };
  }
}

class QuoteListResponse {
  const QuoteListResponse({required this.items, required this.count});

  final List<MarketQuoteDto> items;
  final int count;

  factory QuoteListResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? const [];
    return QuoteListResponse(
      items: raw.map((e) => MarketQuoteDto.fromJson(e as Map<String, dynamic>)).toList(),
      count: json['count'] as int? ?? raw.length,
    );
  }
}

class QuoteApiClient {
  QuoteApiClient({ApiClient? client}) : _client = client ?? apiClient;

  final ApiClient _client;

  Future<MarketQuoteDto> getQuote(String ticker) {
    return _client.getJson(
      '/v1/quotes/$ticker',
      fromJson: MarketQuoteDto.fromJson,
    );
  }

  Future<StockQuoteDetailDto> getDetail(
    String ticker, {
    int candleLimit = 252,
    int dividendLimit = 120,
  }) {
    return _client.getJson(
      '/v1/quotes/$ticker/detail',
      query: {
        'candle_limit': '$candleLimit',
        'dividend_limit': '$dividendLimit',
      },
      fromJson: StockQuoteDetailDto.fromJson,
    );
  }

  Future<StockCandlesResponseDto> getCandles(
    String ticker, {
    String? range,
    int? limit,
    String interval = '1d',
  }) {
    final query = <String, String>{'interval': interval};
    if (range != null) query['range'] = range;
    if (limit != null) query['limit'] = '$limit';

    return _client.getJson(
      '/v1/quotes/$ticker/candles',
      query: query,
      fromJson: StockCandlesResponseDto.fromJson,
    );
  }

  Future<BrazilMacroDto> getBrazilMacro() {
    return _client.getJson(
      '/v1/macro/brazil',
      fromJson: BrazilMacroDto.fromJson,
    );
  }

  Future<DictionaryResponseDto> getDictionary({String category = 'statistics'}) {
    return _client.getJson(
      '/v1/meta/dictionary',
      query: {'category': category},
      fromJson: DictionaryResponseDto.fromJson,
    );
  }

  Future<StockFinancialsDto> getFinancials(
    String ticker, {
    int limit = 8,
    String period = 'quarterly',
  }) {
    return _client.getJson(
      '/v1/quotes/$ticker/financials',
      query: {'limit': '$limit', 'period': period},
      fromJson: StockFinancialsDto.fromJson,
    );
  }

  Future<StockFundamentalHistoryDto> getFundamentalHistory(String ticker, {int limit = 12}) {
    return _client.getJson(
      '/v1/quotes/$ticker/fundamentals/history',
      query: {'limit': '$limit'},
      fromJson: StockFundamentalHistoryDto.fromJson,
    );
  }

  Future<StockPerformanceDto> getPerformance(
    String ticker, {
    String? range,
    int? limit,
    String benchmark = '^BVSP',
  }) {
    final query = <String, String>{'benchmark': benchmark};
    if (range != null) query['range'] = range;
    if (limit != null) query['limit'] = '$limit';

    return _client.getJson(
      '/v1/quotes/$ticker/performance',
      query: query,
      fromJson: StockPerformanceDto.fromJson,
    );
  }

  Future<StockCompareResponseDto> compare(List<String> tickers) {
    return _client.getJson(
      '/v1/quotes/compare',
      query: {'tickers': tickers.join(',')},
      fromJson: StockCompareResponseDto.fromJson,
    );
  }

  Future<StockScreenerResponseDto> screener(Map<String, String> query) {
    return _client.getJson(
      '/v1/quotes/screener',
      query: query,
      fromJson: StockScreenerResponseDto.fromJson,
    );
  }

  Future<QuoteListResponse> featured() {
    return _client.getJson(
      '/v1/quotes/featured',
      fromJson: QuoteListResponse.fromJson,
    );
  }

  Future<StockCatalogResponseDto> getCatalog(String categorySlug) {
    return _client.getJson(
      '/v1/quotes/catalog',
      query: {'category': categorySlug},
      fromJson: StockCatalogResponseDto.fromJson,
    );
  }

  Future<QuoteListResponse> search(String query, {int limit = 20}) {
    return _client.getJson(
      '/v1/quotes/search',
      query: {'q': query, 'limit': '$limit'},
      fromJson: QuoteListResponse.fromJson,
    );
  }

  Future<QuoteListResponse> listByCategory(MarketCategory category, {int limit = 30}) {
    return _client.getJson(
      '/v1/quotes/market/${_categorySlug(category)}',
      query: {'limit': '$limit'},
      fromJson: QuoteListResponse.fromJson,
    );
  }

  Future<QuoteListResponse> batch(List<String> tickers) {
    return _client.getJson(
      '/v1/quotes/batch',
      query: {'tickers': tickers.join(',')},
      fromJson: QuoteListResponse.fromJson,
    );
  }

  String _categorySlug(MarketCategory category) {
    return switch (category) {
      MarketCategory.bdr => 'bdr',
      MarketCategory.etf => 'etf',
      MarketCategory.etfInternacional => 'etf_intl',
      MarketCategory.acoesBr => 'acoes_br',
      _ => 'acoes_br',
    };
  }
}
