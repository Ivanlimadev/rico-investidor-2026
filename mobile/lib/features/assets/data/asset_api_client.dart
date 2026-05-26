import 'package:rico_investidor/core/network/api_client.dart';
import 'package:rico_investidor/features/assets/models/asset_detail.dart';

class AssetApiClient {
  AssetApiClient({ApiClient? client}) : _client = client ?? apiClient;

  final ApiClient _client;

  Future<AssetDetailDto> getDetail(
    String ticker, {
    int candleLimit = 252,
    int dividendLimit = 120,
  }) {
    return _client.getJson(
      '/v1/assets/${ticker.trim().toUpperCase()}',
      query: {
        'candle_limit': '$candleLimit',
        'dividend_limit': '$dividendLimit',
      },
      fromJson: AssetDetailDto.fromJson,
    );
  }
}

final assetApiClient = AssetApiClient();
