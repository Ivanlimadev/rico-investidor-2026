import 'package:rico_investidor/core/cache/session_cache.dart';
import 'package:rico_investidor/features/global_markets/data/global_market_repository.dart';
import 'package:rico_investidor/features/global_markets/models/global_market_models.dart';
import 'package:rico_investidor/features/global_markets/widgets/market_hub_section_grid.dart';
import 'package:rico_investidor/features/home/data/brazilian_hub_sections.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/services/market_preference_storage.dart';

/// Cache de seções do mercado preferido — compartilhado entre intro e home.
class PreferredMarketPreloader {
  PreferredMarketPreloader._();
  static final PreferredMarketPreloader instance = PreferredMarketPreloader._();

  final _cache = SessionCache<List<MarketHubSectionData>>(ttl: const Duration(minutes: 5));
  String? _cachedCode;
  Future<List<MarketHubSectionData>>? _inFlight;

  Future<List<MarketHubSectionData>> load({
    required MarketPreference preference,
    required QuoteRepository quoteRepository,
    required GlobalMarketRepository globalMarketRepository,
  }) {
    final code = preference.code.toUpperCase();
    if (_cachedCode == code) {
      final cached = _cache.get();
      if (cached != null) return Future.value(cached);
    }

    return _inFlight ??= _fetch(
      preference: preference,
      quoteRepository: quoteRepository,
      globalMarketRepository: globalMarketRepository,
    ).whenComplete(() => _inFlight = null);
  }

  Future<List<MarketHubSectionData>> _fetch({
    required MarketPreference preference,
    required QuoteRepository quoteRepository,
    required GlobalMarketRepository globalMarketRepository,
  }) async {
    final sections = preference.isBrazil
        ? await loadBrazilianHubSections(quoteRepository)
        : await _loadGlobalSections(preference.code, globalMarketRepository);

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
