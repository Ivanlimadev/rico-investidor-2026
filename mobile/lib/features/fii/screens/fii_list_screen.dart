import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/core/search/asset_search_config.dart';
import 'package:rico_investidor/core/search/unified_asset_search.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/fii/screens/fii_compare_screen.dart';
import 'package:rico_investidor/features/fii/screens/fii_explore_screen.dart' show FiiExploreScreen, FiiScreenerTile;
import 'package:rico_investidor/features/fii/utils/fii_screener_presets.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/models/fii_models.dart';
import 'package:rico_investidor/navigation/open_asset_detail.dart';

class FiiListScreen extends StatefulWidget {
  const FiiListScreen({
    super.key,
    required this.repository,
    this.quoteRepository,
  });

  final FiiRepository repository;
  final QuoteRepository? quoteRepository;

  @override
  State<FiiListScreen> createState() => _FiiListScreenState();
}

class _FiiListScreenState extends State<FiiListScreen> {
  final _searchController = TextEditingController();
  final _unifiedSearch = UnifiedAssetSearchRunner();

  UnifiedAssetSearchSnapshot _searchSnapshot = const UnifiedAssetSearchSnapshot.idle();
  List<FiiScreenerItem> _items = [];
  int _total = 0;
  bool _loading = true;
  String? _error;

  QuoteRepository get _quoteRepository => widget.quoteRepository ?? quoteRepository;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _unifiedSearch.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final preset = fiiScreenerPresets.firstWhere((p) => p.id == 'all');
      final response = await widget.repository.screener(preset.params);
      if (!mounted) return;
      setState(() {
        _items = response.data;
        _total = response.total;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    _unifiedSearch.search(value, (snapshot) {
      if (!mounted) return;
      setState(() => _searchSnapshot = snapshot);
      if (!snapshot.active) _load();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  void _reload() {
    widget.repository.invalidate();
    _searchController.clear();
    _onSearchChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FIIs'),
        actions: [
          const ShellHomeButton(),
          IconButton(
            tooltip: 'Explorar',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => FiiExploreScreen(
                  repository: widget.repository,
                  quoteRepository: _quoteRepository,
                ),
              ),
            ),
            icon: const Icon(Icons.tune),
          ),
          IconButton(
            tooltip: 'Comparar',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => FiiCompareScreen(repository: widget.repository),
              ),
            ),
            icon: const Icon(Icons.compare_arrows),
          ),
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SearchBar(
              controller: _searchController,
              hintText: kUnifiedAssetSearchHint,
              leading: const Icon(Icons.search),
              trailing: [
                if (_searchSnapshot.query.isNotEmpty)
                  IconButton(
                    tooltip: 'Limpar',
                    onPressed: _clearSearch,
                    icon: const Icon(Icons.close),
                  ),
              ],
              onChanged: _onSearchChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              _searchSnapshot.active
                  ? (_searchSnapshot.loading
                      ? 'Buscando em todas as classes…'
                      : '${_searchSnapshot.results.length} resultados · busca global')
                  : '$_total FIIs · cotações ao vivo',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_searchSnapshot.active) {
      return UnifiedAssetResultsBody(
        snapshot: _searchSnapshot,
        fiiRepository: widget.repository,
        quoteRepository: _quoteRepository,
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Tentar novamente')),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return const Center(child: Text('Nenhum FII encontrado.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _items[index];
        return FiiScreenerTile(
          item: item,
          onTap: () => openTickerDetailQuick(context, item.ticker),
        );
      },
    );
  }
}
