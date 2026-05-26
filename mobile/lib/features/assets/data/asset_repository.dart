import 'package:rico_investidor/features/assets/data/asset_api_client.dart';
import 'package:rico_investidor/features/assets/models/asset_detail.dart';

class AssetRepository {
  AssetRepository({AssetApiClient? api}) : _api = api ?? assetApiClient;

  final AssetApiClient _api;

  Future<AssetDetailDto> getDetail(String ticker) {
    return _api.getDetail(ticker);
  }
}

final assetRepository = AssetRepository();
