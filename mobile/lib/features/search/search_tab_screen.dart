import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/app/main_shell_screen.dart';
import 'package:rico_investidor/core/search/asset_search_config.dart';
import 'package:rico_investidor/core/search/unified_asset_search.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/fii/screens/fii_compare_screen.dart';
import 'package:rico_investidor/features/fii/screens/fii_explore_screen.dart';
import 'package:rico_investidor/features/fii/screens/fii_list_screen.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/features/quotes/screens/stock_compare_screen.dart';
import 'package:rico_investidor/features/quotes/screens/stock_explore_screen.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/navigation/open_asset_detail.dart';
import 'package:rico_investidor/state/portfolio_state.dart';

class SearchTabScreen extends StatefulWidget {
  const SearchTabScreen({
    super.key,
    required this.portfolio,
    required this.fiiRepository,
    required this.quoteRepository,
    this.initialQuery,
    this.onInitialQueryApplied,
  });

  final PortfolioState portfolio;
  final FiiRepository fiiRepository;
  final QuoteRepository quoteRepository;
  final String? initialQuery;
  final VoidCallback? onInitialQueryApplied;

  @override
  State<SearchTabScreen> createState() => _SearchTabScreenState();
}

class _SearchTabScreenState extends State<SearchTabScreen> {
  final _controller = TextEditingController();
  final _unifiedSearch = UnifiedAssetSearchRunner();
  UnifiedAssetSearchSnapshot _snapshot = const UnifiedAssetSearchSnapshot.idle();

  @override
  void initState() {
    super.initState();
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
    _unifiedSearch.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _search(String query) {
    _unifiedSearch.search(query, (snapshot) {
      if (!mounted) return;
      setState(() => _snapshot = snapshot);
    });
  }

  void _openAsset(AssetItem asset) {
    openAssetDetail(
      context,
      asset: asset,
      fiiRepository: widget.fiiRepository,
      quoteRepository: widget.quoteRepository,
    );
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
            onSubmitted: _search,
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
          Text('Atalhos ações', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ShortcutChip(
                icon: Icons.travel_explore,
                label: 'Explorar',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => StockExploreScreen(
                      repository: widget.quoteRepository,
                      fiiRepository: widget.fiiRepository,
                      category: MarketCategory.acoesBr,
                    ),
                  ),
                ),
              ),
              _ShortcutChip(
                icon: Icons.compare_arrows,
                label: 'Comparar',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => StockCompareScreen(repository: widget.quoteRepository),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Atalhos FIIs', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ShortcutChip(
                icon: Icons.list_alt,
                label: 'Lista completa',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => FiiListScreen(repository: widget.fiiRepository),
                  ),
                ),
              ),
              _ShortcutChip(
                icon: Icons.travel_explore,
                label: 'Explorar',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => FiiExploreScreen(repository: widget.fiiRepository),
                  ),
                ),
              ),
              _ShortcutChip(
                icon: Icons.compare_arrows,
                label: 'Comparar',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => FiiCompareScreen(repository: widget.fiiRepository),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
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
          else if (!_snapshot.active)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Digite pelo menos 2 caracteres para buscar ações, FIIs, cripto, EUA e outros ativos.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          else ...[
            Text('Resultados', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final asset in _snapshot.results)
              UnifiedAssetResultTile(
                asset: asset,
                onTap: () => _openAsset(asset),
              ),
          ],
        ],
      ),
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  const _ShortcutChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}
