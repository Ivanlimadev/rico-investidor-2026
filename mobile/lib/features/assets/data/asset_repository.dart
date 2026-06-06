import 'package:rico_investidor/features/assets/data/asset_api_client.dart';
import 'package:rico_investidor/features/assets/models/asset_detail.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';

class AssetRepository {
  AssetRepository({AssetApiClient? api}) : _api = api ?? assetApiClient;

  final AssetApiClient _api;

  Future<AssetDetailDto> getDetail(String ticker) {
    return _api.getDetail(
      ticker,
      candleLimit: QuoteRepository.extendedCandleLimit,
      dividendLimit: QuoteRepository.extendedDividendLimit,
    );
  }
}

final assetRepository = AssetRepository();
