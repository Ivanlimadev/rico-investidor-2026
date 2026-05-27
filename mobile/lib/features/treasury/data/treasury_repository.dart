import 'package:rico_investidor/core/cache/session_cache.dart';
import 'package:rico_investidor/features/treasury/data/treasury_api_client.dart';
import 'package:rico_investidor/features/treasury/models/treasury_models.dart';
import 'package:rico_investidor/models/asset_item.dart';

class TreasuryRepository {
  TreasuryRepository({TreasuryApiClient? api}) : _api = api ?? TreasuryApiClient();

  final TreasuryApiClient _api;
  final _listCache = SessionCache<List<TreasuryBondDto>>(ttl: const Duration(minutes: 5));
  final Map<String, SessionCache<TreasuryDetailDto>> _detailCache = {};

  SessionCache<TreasuryDetailDto> _cacheFor(String symbol) {
    return _detailCache.putIfAbsent(
      normalizeTreasurySymbol(symbol),
      () => SessionCache<TreasuryDetailDto>(ttl: const Duration(minutes: 10)),
    );
  }

  Future<List<AssetItem>> listFeaturedAssets() async {
    final bonds = await listFeatured();
    return bonds.map((bond) => bond.toAssetItem()).toList();
  }

  Future<List<TreasuryBondDto>> listFeatured() async {
    final cached = _listCache.get();
    if (cached != null) return cached;

    final response = await _api.listFeatured();
    _listCache.set(response.items);
    return response.items;
  }

  Future<TreasuryDetailDto> getDetail(String symbol, {int historyLimit = 252}) async {
    final normalized = normalizeTreasurySymbol(symbol);
    final cache = _cacheFor(normalized);
    final cached = cache.get();
    if (cached != null) return cached;

    final bondFuture = _api.getBond(normalized);
    final historyFuture = _api.getHistory(normalized, limit: historyLimit);
    final results = await Future.wait([bondFuture, historyFuture]);

    final detail = TreasuryDetailDto(
      bond: results[0] as TreasuryBondDto,
      history: (results[1] as TreasuryHistoryResponseDto).history,
    );
    cache.set(detail);
    return detail;
  }

  Future<TreasuryExploreResponseDto> explore({
    String? search,
    String group = 'all',
    int page = 1,
    int limit = 30,
  }) {
    return _api.explore(search: search, group: group, page: page, limit: limit);
  }

  Future<List<TreasuryBondDto>> searchBonds(String query, {int limit = 8}) async {
    final response = await explore(search: query, limit: limit);
    return response.items;
  }
}

final treasuryRepository = TreasuryRepository();
