import 'package:rico_investidor/core/cache/session_cache.dart';
import 'package:rico_investidor/core/network/api_client.dart';
import 'package:rico_investidor/features/assets/models/related_assets.dart';

class RelatedAssetsApiClient {
  RelatedAssetsApiClient({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;
  final Map<String, SessionCache<RelatedAssetsResponseDto>> _cache = {};

  String _cacheKey(
    String ticker, {
    required String market,
    String? sector,
    String? industry,
    required int limit,
  }) =>
      '${ticker.toUpperCase()}:$market:${sector ?? ''}:${industry ?? ''}:$limit';

  Future<RelatedAssetsResponseDto> listRelated(
    String ticker, {
    required String market,
    String? sector,
    String? industry,
    int limit = 6,
  }) async {
    final key = _cacheKey(
      ticker,
      market: market,
      sector: sector,
      industry: industry,
      limit: limit,
    );
    final cache = _cache.putIfAbsent(
      key,
      () => SessionCache<RelatedAssetsResponseDto>(ttl: const Duration(minutes: 15)),
    );
    final cached = cache.get();
    if (cached != null) return cached;

    final query = <String, String>{
      'market': market,
      'limit': '$limit',
    };
    if (sector != null && sector.trim().isNotEmpty) {
      query['sector'] = sector.trim();
    }
    if (industry != null && industry.trim().isNotEmpty) {
      query['industry'] = industry.trim();
    }

    final result = await _api.getJson(
      '/v1/related/${ticker.toUpperCase()}',
      query: query,
      fromJson: RelatedAssetsResponseDto.fromJson,
    );
    cache.set(result);
    return result;
  }
}

final relatedAssetsApiClient = RelatedAssetsApiClient();
