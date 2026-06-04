import 'package:rico_investidor/core/network/api_client.dart';
import 'package:rico_investidor/features/assets/models/related_assets.dart';

class RelatedAssetsApiClient {
  RelatedAssetsApiClient({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  Future<RelatedAssetsResponseDto> listRelated(
    String ticker, {
    required String market,
    String? sector,
    String? industry,
    int limit = 6,
  }) async {
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

    return _api.getJson(
      '/v1/related/${ticker.toUpperCase()}',
      query: query,
      fromJson: RelatedAssetsResponseDto.fromJson,
    );
  }
}

final relatedAssetsApiClient = RelatedAssetsApiClient();
