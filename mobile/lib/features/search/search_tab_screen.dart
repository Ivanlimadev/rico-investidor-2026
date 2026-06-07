import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/app/main_shell_screen.dart';
import 'package:rico_investidor/core/search/asset_search_config.dart';
import 'package:rico_investidor/core/search/unified_asset_search.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/navigation/open_asset_detail.dart';
import 'package:rico_investidor/core/widgets/asset_logo.dart';
import 'package:rico_investidor/features/search/widgets/search_asset_grid.dart';
import 'package:rico_investidor/services/asset_search_service.dart';
import 'package:rico_investidor/services/favorites_storage.dart';
import 'package:rico_investidor/services/recent_searched_assets_storage.dart';
import 'package:rico_investidor/services/search_history_storage.dart';
import 'package:rico_investidor/state/portfolio_state.dart';

class SearchTabScreen extends StatefulWidget {
  const SearchTabScreen({
    super.key,
    required this.portfolio,
    this.initialQuery,
    this.onInitialQueryApplied,
  });

  final PortfolioState portfolio;
  final String? initialQuery;
  final VoidCallback? onInitialQueryApplied;

  @override
  State<SearchTabScreen> createState() => _SearchTabScreenState();
}

class _SearchTabScreenState extends State<SearchTabScreen> {
  final _controller = TextEditingController();
  final _unifiedSearch = UnifiedAssetSearchRunner();
  UnifiedAssetSearchSnapshot _snapshot = const UnifiedAssetSearchSnapshot.idle();

  List<AssetItem> _favorites = const [];
  List<String> _recentQueries = const [];
  bool _favoritesLoading = false;
  StreamSubscription<void>? _favoritesSubscription;
  final _searchService = assetSearchService;

  @override
  void initState() {
    super.initState();
    _loadIdleSections();
    _favoritesSubscription = favoritesStorage.changes.listen((_) => _loadIdleSections());

    final query = widget.initialQuery?.trim();
    if (query != null && query.isNotEmpty) {
      _controller.text = query;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _search(query);
        widget.onInitialQueryApplied?.call();
      });
    }
  }

  @override
  void didUpdateWidget(covariant SearchTabScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final query = widget.initialQuery?.trim();
    if (query != null &&
        query.isNotEmpty &&
        query != oldWidget.initialQuery &&
        query != _controller.text.trim()) {
      _controller.text = query;
      _search(query);
      widget.onInitialQueryApplied?.call();
    }
  }

  @override
  void dispose() {
    _favoritesSubscription?.cancel();
    _unifiedSearch.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadIdleSections() async {
    if (!mounted) setState(() => _favoritesLoading = true);

    final favorites = await favoritesStorage.load();
    final history = await searchHistoryStorage.load();
    final top = favorites.take(kMaxSearchFavoritesDisplay).toList();

    final refreshed = await Future.wait<AssetItem>(
      top.map((item) async {
        try {
          final live = await _searchService.findBySymbolAsync(item.symbol);
          if (live != null) return live;
        } catch (_) {}
        return AssetItem(
          symbol: item.symbol,
          name: item.name,
          category: item.category,
          price: item.price,
          changePercent: item.changePercent,
          logoUrl: item.logoUrl,
          dividendYield12m: item.dividendYield12m,
          priceToBook: item.priceToBook,
          exchangeMic: item.exchangeMic,
        );
      }),
    );

    if (!mounted) return;
    setState(() {
      _favorites = refreshed;
      _recentQueries = history.take(kMaxSearchHistoryEntries).toList();
      _favoritesLoading = false;
    });
    unawaited(warmAssetLogoSymbols(refreshed.map((item) => item.symbol)));
  }

  void _search(String query) {
    _unifiedSearch.search(
      query,
      (snapshot) {
        if (!mounted) return;
        setState(() => _snapshot = snapshot);
        if (!snapshot.loading && snapshot.results.isNotEmpty) {
          unawaited(warmAssetLogoSymbols(snapshot.results.map((item) => item.symbol)));
        }
      },
      preferredMarket: AppShellScope.maybeOf(context)?.preferredMarket,
    );
  }

  Future<void> _recordSearch(String query) async {
    await searchHistoryStorage.record(query);
    await _loadIdleSections();
  }

  void _openAsset(AssetItem asset) {
    final q = _controller.text.trim();
    if (q.isNotEmpty) {
      unawaited(_recordSearch(q));
    }
    unawaited(recentSearchedAssetsStorage.record(asset));
    openAssetDetail(
      context,
      asset: asset,
    );
  }

  void _applyRecentQuery(String query) {
    _controller.text = query;
    _search(query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar'),
        actions: const [ShellHomeButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, kBottomNavContentPadding),
        children: [
          SearchBar(
            controller: _controller,
            hintText: kUnifiedAssetSearchHint,
            leading: const Icon(Icons.search),
            onChanged: _search,
            onSubmitted: (value) {
              _search(value);
              if (value.trim().length >= kMinAssetSearchLength) {
                unawaited(_recordSearch(value.trim()));
              }
            },
            trailing: _snapshot.query.isNotEmpty
                ? [
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _controller.clear();
                        _search('');
                      },
                    ),
                  ]
                : null,
          ),
          const SizedBox(height: 16),
          if (_snapshot.loading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (_snapshot.active && _snapshot.results.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text(
                'Nenhum resultado para "${_snapshot.query}".',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else if (_snapshot.active) ...[
            Text('Resultados', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SearchAssetGrid(
              assets: _snapshot.results,
              onAssetTap: _openAsset,
            ),
          ] else ...[
            if (_favoritesLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_favorites.isNotEmpty) ...[
              _SectionHeader(title: 'Favoritos', icon: Icons.star_rounded),
              const SizedBox(height: 8),
              SearchAssetGrid(
                assets: _favorites,
                onAssetTap: _openAsset,
              ),
              const SizedBox(height: 20),
            ],
            if (_recentQueries.isNotEmpty) ...[
              _SectionHeader(title: 'Buscas recentes', icon: Icons.history_rounded),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final query in _recentQueries)
                    InputChip(
                      label: Text(query),
                      onPressed: () => _applyRecentQuery(query),
                      onDeleted: () async {
                        await searchHistoryStorage.remove(query);
                        await _loadIdleSections();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 20),
            ],
            if (_favorites.isEmpty && _recentQueries.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
'Digite pelo menos 2 caracteres para buscar ações americanas, REITs ou cripto.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ],
      ),
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
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}

