import 'package:rico_investidor/core/network/api_client.dart';
import 'package:rico_investidor/features/indices/models/indices_models.dart';

class IndicesApiClient {
  IndicesApiClient({ApiClient? client}) : _client = client ?? apiClient;

  final ApiClient _client;

  Future<IndexListResponseDto> listFeatured() {
    return _client.getJson(
      '/v1/indices',
      fromJson: IndexListResponseDto.fromJson,
    );
  }

  Future<IndexDetailDto> getDetail(String symbol) {
    final normalized = normalizeIndexSymbol(symbol);
    final encoded = Uri.encodeComponent(normalized);
    return _client.getJson(
      '/v1/indices/$encoded',
      fromJson: IndexDetailDto.fromJson,
    );
  }

  Future<IndexHistoryResponseDto> getHistory(String symbol, {int limit = 252}) {
    final normalized = normalizeIndexSymbol(symbol);
    final encoded = Uri.encodeComponent(normalized);
    return _client.getJson(
      '/v1/indices/$encoded/history',
      query: {'limit': '$limit'},
      fromJson: IndexHistoryResponseDto.fromJson,
    );
  }

  Future<IndexExploreResponseDto> explore({
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
      '/v1/indices/explore',
      query: query,
      fromJson: IndexExploreResponseDto.fromJson,
    );
  }
}
