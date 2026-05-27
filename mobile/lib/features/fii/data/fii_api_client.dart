import 'package:rico_investidor/core/network/api_client.dart';
import 'package:rico_investidor/features/fii/utils/fii_ticker.dart';
import 'package:rico_investidor/models/fii_models.dart';

class FiiApiClient {
  FiiApiClient({ApiClient? client}) : _client = client ?? apiClient;

  final ApiClient _client;

  Future<FiiListResponse> listFiis({int limit = 500, int offset = 0}) {
    return _client.getJson(
      '/v1/fiis',
      query: {'limit': '$limit', 'offset': '$offset'},
      fromJson: FiiListResponse.fromJson,
    );
  }

  Future<FiiSearchResponse> searchFiis(String query, {int limit = 20}) {
    return _client.getJson(
      '/v1/fiis/search',
      query: {'q': query, 'limit': '$limit'},
      fromJson: FiiSearchResponse.fromJson,
    );
  }

  Future<FiiCountResponse> countFiis() {
    return _client.getJson(
      '/v1/fiis/count',
      fromJson: FiiCountResponse.fromJson,
    );
  }

  Future<FiiDetail> getFii(String ticker) {
    return _client.getJson(
      '/v1/fiis/${normalizeFiiTicker(ticker)}',
      fromJson: FiiDetail.fromJson,
    );
  }

  Future<FiiDistributions> getDistributions(String ticker, {int years = 5}) {
    return _client.getJson(
      '/v1/fiis/${normalizeFiiTicker(ticker)}/distributions',
      query: {'years': '$years'},
      fromJson: FiiDistributions.fromJson,
    );
  }

  Future<FiiHistoryResponse> getHistory(String ticker, {int limit = 24}) {
    return _client.getJson(
      '/v1/fiis/${normalizeFiiTicker(ticker)}/history',
      query: {'limit': '$limit'},
      fromJson: FiiHistoryResponse.fromJson,
    );
  }

  Future<FiiCandlesResponse> getCandles(
    String ticker, {
    int limit = 252,
    String? start,
    String? end,
  }) {
    final query = <String, String>{'limit': '$limit'};
    if (start != null) query['start'] = start;
    if (end != null) query['end'] = end;

    return _client.getJson(
      '/v1/fiis/${normalizeFiiTicker(ticker)}/candles',
      query: query,
      fromJson: FiiCandlesResponse.fromJson,
    );
  }

  Future<FiiTenantsResponse> getTenants(String ticker) {
    return _client.getJson(
      '/v1/fiis/${normalizeFiiTicker(ticker)}/tenants',
      fromJson: FiiTenantsResponse.fromJson,
    );
  }

  Future<FiiScreenerResponse> screener(Map<String, String> params) {
    return _client.getJson(
      '/v1/fiis/screener',
      query: params,
      fromJson: FiiScreenerResponse.fromJson,
    );
  }

}
