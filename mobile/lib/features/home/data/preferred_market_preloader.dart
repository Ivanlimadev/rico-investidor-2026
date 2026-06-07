import 'package:rico_investidor/core/cache/session_cache.dart';
import 'package:rico_investidor/core/network/repository_timeouts.dart';
import 'package:rico_investidor/features/global_markets/data/global_market_repository.dart';
import 'package:rico_investidor/features/global_markets/models/global_market_models.dart';
import 'package:rico_investidor/features/global_markets/widgets/market_hub_section_grid.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/services/market_preference_storage.dart';

class PreferredMarketPreloader {
  PreferredMarketPreloader._();
  static final PreferredMarketPreloader instance = PreferredMarketPreloader._();

  final _cache = SessionCache<List<MarketHubSectionData>>(ttl: const Duration(minutes: 5));
  String? _cachedCode;
  Future<List<MarketHubSectionData>>? _inFlight;

  Future<List<MarketHubSectionData>> load({
    required MarketPreference preference,
    required GlobalMarketRepository globalMarketRepository,
  }) {
    final code = preference.code.toUpperCase();
    if (_cachedCode == code) {
      final cached = _cache.get();
      if (cached != null) return Future.value(cached);
    }

    return _inFlight ??= _fetch(
      preference: preference,
      globalMarketRepository: globalMarketRepository,
    )
        .timeout(kRepositoryFetchTimeout)
        .whenComplete(() => _inFlight = null);
  }

  Future<List<MarketHubSectionData>> _fetch({
    required MarketPreference preference,
    required GlobalMarketRepository globalMarketRepository,
  }) async {
    final sections = await _loadGlobalSections(preference.code, globalMarketRepository);

    _cachedCode = preference.code.toUpperCase();
    _cache.set(sections);
    return sections;
  }

  Future<List<MarketHubSectionData>> _loadGlobalSections(
    String countryCode,
    GlobalMarketRepository globalMarketRepository,
  ) async {
    final hub = await globalMarketRepository.getCountryHub(countryCode);
    return hub.sections
        .map(
          (section) => MarketHubSectionData(
            id: section.id,
            title: section.title,
            assets: section.items
                .map((quote) => quote.toUsAssetItem(category: MarketCategory.stocks))
                .toList(),
          ),
        )
        .where((section) => section.assets.isNotEmpty)
        .toList();
  }

  void invalidate() {
    _cache.clear();
    _cachedCode = null;
    _inFlight = null;
  }
}

final preferredMarketPreloader = PreferredMarketPreloader.instance;
