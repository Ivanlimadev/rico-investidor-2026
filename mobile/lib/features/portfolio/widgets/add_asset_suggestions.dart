import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/core/markets/supported_market_countries.dart';
import 'package:rico_investidor/core/search/asset_search_config.dart';
import 'package:rico_investidor/core/utils/asset_logo_url.dart';
import 'package:rico_investidor/core/widgets/asset_logo.dart';
import 'package:rico_investidor/features/global_markets/data/global_market_repository.dart';
import 'package:rico_investidor/features/global_markets/widgets/market_hub_section_grid.dart';
import 'package:rico_investidor/features/home/data/preferred_market_preloader.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/features/portfolio/widgets/add_asset_circle_grid.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/services/favorites_storage.dart';
import 'package:rico_investidor/services/market_preference_storage.dart';
import 'package:rico_investidor/services/recent_searched_assets_storage.dart';

const _featuredLoadTimeout = Duration(seconds: 8);

/// Favoritos, buscas recentes e principais ativos do país — grid 3×4 na tela Adicionar ativo.
class AddAssetSuggestions extends StatefulWidget {
  const AddAssetSuggestions({
    super.key,
    required this.onAssetTap,
    this.quoteRepository,
    this.globalMarketRepository,
  });

  final ValueChanged<AssetItem> onAssetTap;
  final QuoteRepository? quoteRepository;
  final GlobalMarketRepository? globalMarketRepository;

  @override
  State<AddAssetSuggestions> createState() => _AddAssetSuggestionsState();
}

class _AddAssetSuggestionsState extends State<AddAssetSuggestions> {
  List<AssetItem> _favorites = const [];
  List<AssetItem> _recent = const [];
  List<AssetItem> _featured = const [];
  String _featuredTitle = 'Principais ativos';
  bool _loading = true;
  StreamSubscription<void>? _favoritesSubscription;
  StreamSubscription<void>? _recentSubscription;
  int _loadGeneration = 0;

  QuoteRepository get _quoteRepository => widget.quoteRepository ?? quoteRepository;
  GlobalMarketRepository get _globalMarketRepository =>
      widget.globalMarketRepository ?? globalMarketRepository;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
    _favoritesSubscription = favoritesStorage.changes.listen((_) => _load());
    _recentSubscription = recentSearchedAssetsStorage.changes.listen((_) => _load());
  }

  @override
  void dispose() {
    _favoritesSubscription?.cancel();
    _recentSubscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final preferredMarket =
          AppShellScope.maybeOf(context)?.preferredMarket ?? defaultMarketPreference;

      final favoritesRaw = await favoritesStorage.load();
      final recentRaw = await recentSearchedAssetsStorage.load();

      final favorites = _enrichStoredAssets(
        favoritesRaw.take(kMaxSearchFavoritesDisplay),
      );
      final recent = _enrichStoredAssets(
        recentRaw.take(kMaxRecentSearchedAssets),
      );
      final featuredBundle = await _loadFeaturedAssets(preferredMarket);

      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _favorites = favorites;
        _recent = recent;
        _featured = featuredBundle.assets;
        _featuredTitle = featuredBundle.title;
        _loading = false;
      });

      unawaited(warmAssetLogoSymbols([
        ...favorites.map((a) => a.symbol),
        ...recent.map((a) => a.symbol),
        ...featuredBundle.assets.map((a) => a.symbol),
      ]));
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _loading = false);
    }
  }

  List<AssetItem> _enrichStoredAssets(Iterable<AssetItem> items) {
    return items
        .map(
          (item) => AssetItem(
            symbol: item.symbol,
            name: item.name,
            category: item.category,
            price: item.price,
            changePercent: item.changePercent,
            logoUrl: resolveAssetLogoUrl(
              item.symbol,
              item.logoUrl,
              isFii: looksLikeFiiTicker(item.symbol),
            ),
            dividendYield12m: item.dividendYield12m,
            priceToBook: item.priceToBook,
            exchangeMic: item.exchangeMic,
          ),
        )
        .toList();
  }

  Future<({String title, List<AssetItem> assets})> _loadFeaturedAssets(
    MarketPreference preferredMarket,
  ) async {
    var title = preferredMarket.isBrazil ? 'Principais ativos' : 'Top stocks';
    List<AssetItem> assets = const [];

    try {
      final sections = await preferredMarketPreloader
          .load(
            preference: preferredMarket,
            quoteRepository: _quoteRepository,
            globalMarketRepository: _globalMarketRepository,
          )
          .timeout(_featuredLoadTimeout);

      MarketHubSectionData? section;
      for (final candidate in sections) {
        if (candidate.id == 'featured') {
          section = candidate;
          break;
        }
      }
      section ??= sections.isNotEmpty ? sections.first : null;
      if (section != null && section.assets.isNotEmpty) {
        title = section.title;
        assets = section.assets.take(kMaxSearchFavoritesDisplay).toList();
      }
    } catch (_) {}

    if (assets.isEmpty && preferredMarket.isBrazil) {
      try {
        final stocks = await _quoteRepository
            .featuredStocks()
            .timeout(_featuredLoadTimeout);
        if (stocks.isNotEmpty) {
          assets = stocks.take(kMaxSearchFavoritesDisplay).toList();
        }
      } catch (_) {}
    }

    return (title: title, assets: assets);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final sections = <Widget>[];

    if (_favorites.isNotEmpty) {
      sections.addAll([
        _SectionHeader(title: 'Favoritos', icon: Icons.star_rounded),
        const SizedBox(height: 8),
        AddAssetCircleGrid(assets: _favorites, onAssetTap: widget.onAssetTap),
      ]);
    }

    if (_recent.isNotEmpty) {
      if (sections.isNotEmpty) sections.add(const SizedBox(height: 20));
      sections.addAll([
        _SectionHeader(title: 'Buscados recentemente', icon: Icons.history_rounded),
        const SizedBox(height: 8),
        AddAssetCircleGrid(
          assets: _recent,
          onAssetTap: widget.onAssetTap,
          maxItems: kMaxRecentSearchedAssets,
        ),
      ]);
    }

    if (_featured.isNotEmpty) {
      if (sections.isNotEmpty) sections.add(const SizedBox(height: 20));
      sections.addAll([
        _SectionHeader(title: _featuredTitle, icon: Icons.trending_up_rounded),
        const SizedBox(height: 8),
        AddAssetCircleGrid(assets: _featured, onAssetTap: widget.onAssetTap),
      ]);
    }

    if (sections.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Digite pelo menos 2 caracteres para buscar um ativo.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
              ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: sections,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}
