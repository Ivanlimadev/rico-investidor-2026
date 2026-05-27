import 'package:rico_investidor/core/network/api_client.dart';
import 'package:rico_investidor/features/crypto/models/crypto_models.dart';

class CryptoApiClient {
  CryptoApiClient({ApiClient? client}) : _client = client ?? apiClient;

  final ApiClient _client;

  Future<CryptoListResponseDto> listFeatured() {
    return _client.getJson(
      '/v1/crypto',
      fromJson: CryptoListResponseDto.fromJson,
    );
  }

  Future<CryptoQuoteDto> getQuote(String symbol) {
    final normalized = normalizeCryptoSymbol(symbol);
    return _client.getJson(
      '/v1/crypto/$normalized',
      fromJson: CryptoQuoteDto.fromJson,
    );
  }

  Future<CryptoMarketSnapshotDto> getMarket(String symbol) {
    final normalized = normalizeCryptoSymbol(symbol);
    return _client.getJson(
      '/v1/crypto/$normalized/market',
      fromJson: CryptoMarketSnapshotDto.fromJson,
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
    );
  }
}
