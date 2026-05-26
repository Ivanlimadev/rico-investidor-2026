import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/app/main_shell_screen.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/fii/screens/fii_compare_screen.dart';
import 'package:rico_investidor/features/fii/screens/fii_explore_screen.dart';
import 'package:rico_investidor/features/fii/screens/fii_list_screen.dart';
import 'package:rico_investidor/features/fii/utils/fii_ticker.dart';
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
  });

  final PortfolioState portfolio;
  final FiiRepository fiiRepository;
  final QuoteRepository quoteRepository;

  @override
  State<SearchTabScreen> createState() => _SearchTabScreenState();
}

class _SearchTabScreenState extends State<SearchTabScreen> {
  final _controller = TextEditingController();
  List<AssetItem> _results = const [];
  bool _loading = false;
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    setState(() {
      _query = q;
      _loading = q.length >= 2;
      if (q.length < 2) _results = const [];
    });

    if (q.length < 2) return;

    final results = await widget.portfolio.searchService.searchAsync(q);
    if (!mounted || _query != q) return;
    setState(() {
      _results = results;
      _loading = false;
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
            hintText: 'Ticker ou nome do ativo',
            leading: const Icon(Icons.search),
            onChanged: _search,
            onSubmitted: _search,
            trailing: _query.isNotEmpty
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
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (_query.length >= 2 && _results.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text(
                'Nenhum resultado para "$_query".',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else if (_query.length < 2)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Digite pelo menos 2 caracteres para buscar ações, FIIs e outros ativos.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          else ...[
            Text('Resultados', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final asset in _results)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      asset.symbol.length > 2 ? asset.symbol.substring(0, 2) : asset.symbol,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                  title: Text(asset.symbol),
                  subtitle: Text(asset.name),
                  trailing: isFiiTicker(asset.symbol)
                      ? const Chip(label: Text('FII'), visualDensity: VisualDensity.compact)
                      : null,
                  onTap: () => _openAsset(asset),
                ),
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
