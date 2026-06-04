import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/features/global_markets/widgets/us_market_quote_list_tile.dart';
import 'package:rico_investidor/core/search/asset_search_config.dart';
import 'package:rico_investidor/core/search/unified_asset_search.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/features/quotes/models/stock_screener.dart';
import 'package:rico_investidor/features/quotes/utils/stock_screener_presets.dart';
import 'package:rico_investidor/core/widgets/market_heatmap/stock_heatmap_block.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/navigation/open_asset_detail.dart';

class StockExploreScreen extends StatefulWidget {
  const StockExploreScreen({
    super.key,
    required this.repository,
    required this.fiiRepository,
    required this.category,
  });

  final QuoteRepository repository;
  final FiiRepository fiiRepository;
  final MarketCategory category;

  @override
  State<StockExploreScreen> createState() => _StockExploreScreenState();
}

class _StockExploreScreenState extends State<StockExploreScreen> {
  static const _pageSize = 30;

  final _searchController = TextEditingController();
  final _unifiedSearch = UnifiedAssetSearchRunner();
  UnifiedAssetSearchSnapshot _searchSnapshot = const UnifiedAssetSearchSnapshot.idle();

  late String _presetId;
  late List<StockScreenerPreset> _presets;
  List<StockScreenerItemDto> _items = [];
  List<String> _sectors = [];
  String? _selectedSector;
  int _page = 1;
  int _totalPages = 1;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _presets = presetsForCategory(_categorySlug);
    _presetId = _presets.first.id;
    _load(reset: true);
  }

  @override
  void dispose() {
    _unifiedSearch.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _unifiedSearch.search(value, (snapshot) {
      if (!mounted) return;
      setState(() => _searchSnapshot = snapshot);
      if (!snapshot.active) _load(reset: true);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  String get _categorySlug {
    return switch (widget.category) {
      MarketCategory.bdr => 'bdr',
      MarketCategory.etf => 'etf',
      _ => 'acoes_br',
    };
  }

  StockScreenerPreset get _activePreset => _presets.firstWhere((p) => p.id == _presetId);

  bool get _canLoadMore => _page < _totalPages && !_loading && !_loadingMore;

  bool get _showHeatmap => _categorySlug == 'acoes_br' && !_searchSnapshot.active;

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
        _items = [];
      });
    } else {
      setState(() => _loadingMore = true);
    }

    final preset = _activePreset;
    final page = reset ? 1 : _page + 1;

    try {
      final response = await widget.repository.screener(
        preset.toQuery(
          limit: _pageSize,
          page: page,
          sectorOverride: _selectedSector,
        ),
      );
      if (!mounted) return;

      setState(() {
        if (reset) {
          _items = response.items;
          if (response.sectors.isNotEmpty) {
            _sectors = response.sectors;
          }
        } else {
          _items = [..._items, ...response.items];
        }
        _page = response.page;
        _totalPages = response.totalPages ?? 1;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _selectPreset(String presetId) {
    if (_presetId == presetId || _searchSnapshot.active) return;
    setState(() => _presetId = presetId);
    _load(reset: true);
  }

  void _selectSector(String? sector) {
    if (_selectedSector == sector || _searchSnapshot.active) return;
    setState(() => _selectedSector = sector);
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Explorar ${widget.category.title}'),
        actions: const [ShellHomeButton()],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
          if (!_searchSnapshot.active) ...[
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              itemCount: _presets.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final preset = _presets[index];
                return FilterChip(
                  label: Text(preset.label),
                  selected: _presetId == preset.id,
                  onSelected: (_) => _selectPreset(preset.id),
                );
              },
            ),
          ),
          if (_sectors.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                itemCount: _sectors.length + 1,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return FilterChip(
                      label: const Text('Todos setores'),
                      selected: _selectedSector == null,
                      onSelected: (_) => _selectSector(null),
                    );
                  }
                  final sector = _sectors[index - 1];
                  return FilterChip(
                    label: Text(sectorLabel(sector)),
                    selected: _selectedSector == sector,
                    onSelected: (_) => _selectSector(sector),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Página $_page/$_totalPages · Brapi',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          ] else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                _searchSnapshot.loading
                    ? 'Buscando em todas as classes…'
                    : '${_searchSnapshot.results.length} resultados · busca global',
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
        fiiRepository: widget.fiiRepository,
        quoteRepository: widget.repository,
      );
    }

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_items.isEmpty) return const Center(child: Text('Nenhum ativo neste filtro.'));

    void openItem(StockScreenerItemDto item) {
      openAssetDetail(
        context,
        asset: item.toAssetItem(),
        fiiRepository: widget.fiiRepository,
        quoteRepository: widget.repository,
      );
    }

    if (_showHeatmap) {
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: StockHeatmapBlock(
              load: () => widget.repository.getHeatmap(),
              volumeLabel: 'Volume B3',
              onTap: (asset) => openAssetDetail(
                context,
                asset: asset,
                fiiRepository: widget.fiiRepository,
                quoteRepository: widget.repository,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverList.separated(
              itemCount: _items.length + (_canLoadMore || _loadingMore ? 1 : 0),
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (index >= _items.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: OutlinedButton.icon(
                      onPressed: _loadingMore ? null : () => _load(reset: false),
                      icon: _loadingMore
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.expand_more),
                      label: Text(_loadingMore ? 'Carregando…' : 'Carregar mais'),
                    ),
                  );
                }

                final item = _items[index];
                return StockScreenerTile(item: item, onTap: () => openItem(item));
              },
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _items.length + (_canLoadMore || _loadingMore ? 1 : 0),
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: OutlinedButton.icon(
              onPressed: _loadingMore ? null : () => _load(reset: false),
              icon: _loadingMore
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more),
              label: Text(_loadingMore ? 'Carregando…' : 'Carregar mais'),
            ),
          );
        }

        final item = _items[index];
        return StockScreenerTile(
          item: item,
          onTap: () => openAssetDetail(
            context,
            asset: item.toAssetItem(),
            fiiRepository: widget.fiiRepository,
            quoteRepository: widget.repository,
          ),
        );
      },
    );
  }
}

class StockScreenerTile extends StatelessWidget {
  const StockScreenerTile({super.key, required this.item, required this.onTap});

  final StockScreenerItemDto item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              QuoteMarketListRow(
                asset: item.toAssetItem(),
                formatPrice: formatBrl,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  if (item.sector != null)
                    _MetricChip(label: 'Setor', value: sectorLabel(item.sector)),
                  if (item.marketCap != null)
                    _MetricChip(label: 'Cap.', value: formatCompactBrl(item.marketCap!)),
                  if (item.volume != null)
                    _MetricChip(label: 'Vol.', value: _formatVolume(item.volume!)),
                  if (item.dividendYield12m != null)
                    _MetricChip(label: 'DY', value: '${item.dividendYield12m!.toStringAsFixed(1)}%'),
                  if (item.priceEarnings != null)
                    _MetricChip(label: 'P/L', value: item.priceEarnings!.toStringAsFixed(1)),
                  if (item.returnOnEquity != null)
                    _MetricChip(label: 'ROE', value: '${item.returnOnEquity!.toStringAsFixed(1)}%'),
                  if (item.priceToBook != null)
                    _MetricChip(label: 'P/VP', value: item.priceToBook!.toStringAsFixed(2)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatVolume(double volume) {
    if (volume >= 1e6) return '${(volume / 1e6).toStringAsFixed(1)} mi';
    if (volume >= 1e3) return '${(volume / 1e3).toStringAsFixed(0)} mil';
    return volume.toStringAsFixed(0);
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label $value',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
