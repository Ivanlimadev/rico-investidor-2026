import 'package:rico_investidor/core/network/api_client.dart';
import 'package:rico_investidor/features/currency/models/currency_models.dart';

class CurrencyApiClient {
  CurrencyApiClient({ApiClient? client}) : _client = client ?? apiClient;

  final ApiClient _client;

  Future<CurrencyListResponseDto> listFeatured() {
    return _client.getJson(
      '/v1/currency',
      fromJson: CurrencyListResponseDto.fromJson,
    );
  }

  Future<CurrencyQuoteDto> getRate(String pair) {
    final normalized = normalizeCurrencyPair(pair);
    return _client.getJson(
      '/v1/currency/$normalized',
      fromJson: CurrencyQuoteDto.fromJson,
    );
  }

  Future<CurrencyHistoryResponseDto> getHistory(
    String pair, {
    int limit = 252,
  }) {
    final normalized = normalizeCurrencyPair(pair);
    return _client.getJson(
      '/v1/currency/$normalized/history',
      query: {'limit': '$limit'},
      fromJson: CurrencyHistoryResponseDto.fromJson,
    );
  }

  Future<CurrencyExploreResponseDto> explore({
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
      '/v1/currency/explore',
      query: query,
      fromJson: CurrencyExploreResponseDto.fromJson,
    );
  }
}
