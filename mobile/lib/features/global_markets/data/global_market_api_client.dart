import 'package:rico_investidor/core/network/api_client.dart';
import 'package:rico_investidor/features/global_markets/models/global_market_models.dart';
import 'package:rico_investidor/features/quotes/data/quote_api_client.dart';
import 'package:rico_investidor/features/quotes/models/stock_compare.dart';

class GlobalMarketApiClient {
  GlobalMarketApiClient({ApiClient? client}) : _client = client ?? apiClient;

  final ApiClient _client;

  String _encodedSymbol(String symbol) => Uri.encodeComponent(symbol.toUpperCase());

  Future<QuoteListResponse> listFeaturedUs() {
    return _client.getJson(
      '/v1/global-markets',
      fromJson: QuoteListResponse.fromJson,
    );
  }

  Future<QuoteListResponse> explore({
    required String category,
    int page = 1,
    int limit = 30,
  }) {
    return _client.getJson(
      '/v1/global-markets/explore',
      query: {
        'category': category,
        'page': '$page',
        'limit': '$limit',
      },
      fromJson: QuoteListResponse.fromJson,
    );
  }

  Future<WorldExchangesResponseDto> listWorldExchanges() {
    return _client.getJson(
      '/v1/global-markets/exchanges',
      fromJson: WorldExchangesResponseDto.fromJson,
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
    final normalized = mic.toUpperCase();
    final query = <String, String>{
      'page': '$page',
      'limit': '$limit',
    };
    if (exchangeName != null && exchangeName.isNotEmpty) {
      query['exchange_name'] = exchangeName;
    }
    if (countryCode != null && countryCode.isNotEmpty) {
      query['country_code'] = countryCode;
    }
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }
    return _client.getJson(
      '/v1/global-markets/exchanges/$normalized/market',
      query: query,
      fromJson: ExchangeMarketListResponseDto.fromJson,
    );
  }

  Future<ExchangeMarketListResponseDto> listCountryMarket(
    String countryCode, {
    int page = 1,
    int limit = 25,
    String? search,
  }) {
    final normalized = countryCode.toUpperCase();
    final query = <String, String>{
      'page': '$page',
      'limit': '$limit',
    };
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }
    return _client.getJson(
      '/v1/global-markets/countries/$normalized/market',
      query: query,
      fromJson: ExchangeMarketListResponseDto.fromJson,
    );
  }

  Future<CountryHubResponseDto> getCountryHub(String countryCode) {
    final normalized = countryCode.toUpperCase();
    return _client.getJson(
      '/v1/global-markets/countries/$normalized/hub',
      fromJson: CountryHubResponseDto.fromJson,
    );
  }

  Future<ExchangeMarketListResponseDto> listUsMarket({
    required String category,
    int page = 1,
    int limit = 25,
    String? search,
  }) {
    final query = <String, String>{
      'category': category,
      'page': '$page',
      'limit': '$limit',
    };
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }
    return _client.getJson(
      '/v1/global-markets/us/market',
      query: query,
      fromJson: ExchangeMarketListResponseDto.fromJson,
    );
  }

  Future<MarketQuoteDto> getQuote(String symbol, {String? exchange}) {
    final encoded = _encodedSymbol(symbol);
    final query = <String, String>{};
    if (exchange != null && exchange.isNotEmpty) {
      query['exchange'] = exchange;
    }
    return _client.getJson(
      '/v1/global-markets/$encoded',
      query: query.isEmpty ? null : query,
      fromJson: MarketQuoteDto.fromJson,
    );
  }

  Future<GlobalStockCandlesResponseDto> getCandles(
    String symbol, {
    String? exchange,
    int limit = 252,
  }) {
    final encoded = _encodedSymbol(symbol);
    final query = <String, String>{'limit': '$limit'};
    if (exchange != null && exchange.isNotEmpty) {
      query['exchange'] = exchange;
    }
    return _client.getJson(
      '/v1/global-markets/$encoded/candles',
      query: query,
      fromJson: GlobalStockCandlesResponseDto.fromJson,
    );
  }

  Future<GlobalStockDetailResponseDto> getStockDetail(
    String symbol, {
    String? exchange,
    int candleLimit = 756,
    int dividendLimit = 100,
    int splitLimit = 50,
    bool includeExtras = true,
  }) {
    final encoded = _encodedSymbol(symbol);
    final query = <String, String>{
      'candle_limit': '$candleLimit',
      'dividend_limit': '$dividendLimit',
      'split_limit': '$splitLimit',
      'include_extras': includeExtras ? 'true' : 'false',
    };
    if (exchange != null && exchange.isNotEmpty) {
      query['exchange'] = exchange;
    }
    return _client.getJson(
      '/v1/global-markets/$encoded/detail',
      query: query,
      fromJson: GlobalStockDetailResponseDto.fromJson,
    );
  }

  Future<GlobalMarketCapabilitiesDto> getCapabilities() {
    return _client.getJson(
      '/v1/global-markets/capabilities',
      fromJson: GlobalMarketCapabilitiesDto.fromJson,
    );
  }

  Future<StockCompareResponseDto> compareStocks(List<String> tickers) {
    final symbols = tickers.map((t) => t.trim().toUpperCase()).where((t) => t.isNotEmpty).take(3).join(',');
    return _client.getJson(
      '/v1/global-markets/compare',
      query: {'symbols': symbols},
      fromJson: StockCompareResponseDto.fromJson,
    );
  }
}
