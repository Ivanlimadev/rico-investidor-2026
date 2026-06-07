import 'package:rico_investidor/core/search/asset_search_config.dart';
import 'package:rico_investidor/core/widgets/asset_logo.dart';
import 'package:rico_investidor/features/global_markets/data/global_market_repository.dart';
import 'package:rico_investidor/features/global_markets/widgets/market_hub_section_grid.dart';
import 'package:rico_investidor/features/home/data/preferred_market_preloader.dart';
import 'package:rico_investidor/services/asset_search_service.dart';
import 'package:rico_investidor/services/favorites_storage.dart';
import 'package:rico_investidor/services/market_preference_storage.dart';

class AppBootstrapService {
  AppBootstrapService({
    AssetSearchService? searchService,
  }) : _searchService = searchService ?? assetSearchService;

  final AssetSearchService _searchService;
  bool _warmed = false;

  bool get hasWarmed => _warmed;

  Future<void> warmIntro({
    MarketPreference? preferredMarket,
    required GlobalMarketRepository globalMarketRepository,
  }) async {
    await Future.wait<void>([
      if (preferredMarket != null)
        _warmPreferredMarket(
          preference: preferredMarket,
          globalMarketRepository: globalMarketRepository,
        ),
      _warmSearchFavorites(),
    ], eagerError: false);

    _warmed = true;
  }

  Future<void> _warmPreferredMarket({
    required MarketPreference preference,
    required GlobalMarketRepository globalMarketRepository,
  }) async {
    try {
      final warmTasks = <Future<void>>[
        preferredMarketPreloader
            .load(
              preference: preference,
              globalMarketRepository: globalMarketRepository,
            )
            .then((sections) => warmAssetLogoSymbols(_symbolsFromHubSections(sections))),
      ];
      if (preference.code.toUpperCase() == 'US') {
        warmTasks.add(globalMarketRepository.getUsHeatmap().then((_) {}));
      }
      await Future.wait(warmTasks, eagerError: false);
    } catch (_) {}
  }

  Future<void> _warmSearchFavorites() async {
    try {
      final favorites = await favoritesStorage.load();
      final top = favorites.take(kMaxSearchFavoritesDisplay).toList();
      if (top.isEmpty) return;

      final refreshed = await Future.wait(
        top.map((item) async {
          try {
            return await _searchService.findBySymbolAsync(item.symbol) ?? item;
          } catch (_) {
            return item;
          }
        }),
      );

      await warmAssetLogoSymbols(
        refreshed.map(
          (item) => item.symbol,
        ),
      );
    } catch (_) {}
  }

  Iterable<String> _symbolsFromHubSections(List<MarketHubSectionData> sections) {
    final seen = <String>{};
    final symbols = <String>[];
    for (final section in sections) {
      for (final asset in section.assets) {
        final symbol = asset.symbol.trim().toUpperCase();
        if (symbol.isEmpty || !seen.add(symbol)) continue;
        symbols.add(symbol);
        if (symbols.length >= 48) return symbols;
      }
    }
    return symbols;
  }
}

final appBootstrapService = AppBootstrapService();
