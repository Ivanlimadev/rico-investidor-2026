import 'package:rico_investidor/core/network/api_client.dart';
import 'package:rico_investidor/features/treasury/models/treasury_models.dart';

class TreasuryApiClient {
  TreasuryApiClient({ApiClient? client}) : _client = client ?? apiClient;

  final ApiClient _client;

  Future<TreasuryListResponseDto> listFeatured() {
    return _client.getJson(
      '/v1/treasury',
      fromJson: TreasuryListResponseDto.fromJson,
    );
  }

  Future<TreasuryBondDto> getBond(String symbol) {
    final normalized = normalizeTreasurySymbol(symbol);
    return _client.getJson(
      '/v1/treasury/$normalized',
      fromJson: TreasuryBondDto.fromJson,
    );
  }

  Future<TreasuryHistoryResponseDto> getHistory(
    String symbol, {
    int limit = 252,
  }) {
    final normalized = normalizeTreasurySymbol(symbol);
    return _client.getJson(
      '/v1/treasury/$normalized/history',
      query: {'limit': '$limit'},
      fromJson: TreasuryHistoryResponseDto.fromJson,
    );
  }

  Future<TreasuryExploreResponseDto> explore({
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
      '/v1/treasury/explore',
      query: query,
      fromJson: TreasuryExploreResponseDto.fromJson,
    );
  }
}
