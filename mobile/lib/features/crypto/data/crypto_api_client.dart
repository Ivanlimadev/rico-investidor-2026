import 'package:rico_investidor/core/network/api_client.dart';
import 'package:rico_investidor/core/network/repository_timeouts.dart';
import 'package:rico_investidor/features/crypto/models/crypto_models.dart';

class CryptoApiClient {
  CryptoApiClient({ApiClient? client}) : _client = client ?? apiClient;

  final ApiClient _client;

  Future<CryptoListResponseDto> listFeatured() {
    return _client.getJson(
      '/v1/crypto',
      fromJson: CryptoListResponseDto.fromJson,
      timeout: kMarketApiTimeout,
    );
  }

  static const _timeout = kMarketApiTimeout;

  Future<CryptoListResponseDto> getQuotesBatch(List<String> symbols) {
    if (symbols.isEmpty) {
      return Future.value(const CryptoListResponseDto(items: [], count: 0));
    }
    final normalized = symbols.map(normalizeCryptoSymbol).toSet().join(',');
    return _client.getJson(
      '/v1/crypto/quotes',
      query: {'symbols': normalized},
      fromJson: CryptoListResponseDto.fromJson,
      timeout: _timeout,
    );
  }

  Future<CryptoQuoteDto> getQuote(String symbol) {
    final normalized = normalizeCryptoSymbol(symbol);
    return _client.getJson(
      '/v1/crypto/$normalized',
      fromJson: CryptoQuoteDto.fromJson,
      timeout: _timeout,
    );
  }

  Future<CryptoMarketSnapshotDto> getMarket(String symbol) {
    final normalized = normalizeCryptoSymbol(symbol);
    return _client.getJson(
      '/v1/crypto/$normalized/market',
      fromJson: CryptoMarketSnapshotDto.fromJson,
      timeout: _timeout,
    );
  }

  Future<CryptoCandlesResponseDto> getCandles(
    String symbol, {
    String preset = '1m',
  }) {
    final normalized = normalizeCryptoSymbol(symbol);
    return _client.getJson(
      '/v1/crypto/$normalized/candles',
      query: {'preset': preset},
      fromJson: CryptoCandlesResponseDto.fromJson,
      timeout: _timeout,
    );
  }

  Future<CryptoHistoryResponseDto> getHistory(
    String symbol, {
    int limit = 252,
    String interval = '1d',
  }) {
    final normalized = normalizeCryptoSymbol(symbol);
    return _client.getJson(
      '/v1/crypto/$normalized/history',
      query: {'limit': '$limit', 'interval': interval},
      fromJson: CryptoHistoryResponseDto.fromJson,
      timeout: _timeout,
    );
  }

  Future<CryptoExploreResponseDto> explore({
    String? search,
    String group = 'all',
    int page = 1,
    int limit = 30,
  }) {
    final query = <String, String>{
      'group': group,
      'page': '$page',
      'limit': '$limit',
    };
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }
    return _client.getJson(
      '/v1/crypto/explore',
      query: query,
      fromJson: CryptoExploreResponseDto.fromJson,
      timeout: _timeout,
    );
  }

  Future<CryptoMoversResponseDto> getMovers({int limit = 5}) {
    return _client.getJson(
      '/v1/crypto/movers',
      query: {'limit': '$limit'},
      fromJson: CryptoMoversResponseDto.fromJson,
      timeout: _timeout,
    );
  }

  Future<CryptoListResponseDto> getHeatmap({int limit = 18}) {
    return _client.getJson(
      '/v1/crypto/heatmap',
      query: {'limit': '$limit'},
      fromJson: CryptoListResponseDto.fromJson,
      timeout: _timeout,
    );
  }

  Future<CryptoInvestorProfileDto> getProfile(String symbol) {
    final normalized = normalizeCryptoSymbol(symbol);
    return _client.getJson(
      '/v1/crypto/$normalized/profile',
      fromJson: CryptoInvestorProfileDto.fromJson,
      timeout: _timeout,
    );
  }

  Future<CryptoMacroSnapshotDto> getMacro() {
    return _client.getJson(
      '/v1/crypto/macro',
      fromJson: CryptoMacroSnapshotDto.fromJson,
      timeout: _timeout,
    );
  }
}
