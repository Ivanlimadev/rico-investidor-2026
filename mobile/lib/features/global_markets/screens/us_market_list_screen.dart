import 'package:flutter/material.dart';
import 'package:rico_investidor/core/config/api_config.dart';
import 'package:rico_investidor/core/search/asset_search_config.dart';
import 'package:rico_investidor/core/search/unified_asset_search.dart';
import 'package:rico_investidor/features/global_markets/widgets/us_market_quote_list_tile.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/global_markets/data/global_market_repository.dart';
import 'package:rico_investidor/features/global_markets/models/global_market_models.dart';
import 'package:rico_investidor/features/global_markets/screens/global_stock_detail_screen.dart';
import 'package:rico_investidor/features/global_markets/utils/marketstack_errors.dart';
import 'package:rico_investidor/core/widgets/market_heatmap/stock_heatmap_block.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/navigation/open_asset_detail.dart';

class UsMarketListScreen extends StatefulWidget {
  const UsMarketListScreen({
    super.key,
    required this.category,
    required this.repository,
    required this.fiiRepository,
    required this.quoteRepository,
  });

  final MarketCategory category;
  final GlobalMarketRepository repository;
  final FiiRepository fiiRepository;
  final QuoteRepository quoteRepository;

  @override
  State<UsMarketListScreen> createState() => _UsMarketListScreenState();
}

class _UsMarketListScreenState extends State<UsMarketListScreen> {
  static const _pageSize = 25;

  final _searchController = TextEditingController();
  final _unifiedSearch = UnifiedAssetSearchRunner();
  final _items = <AssetItem>[];
  UnifiedAssetSearchSnapshot _searchSnapshot = const UnifiedAssetSearchSnapshot.idle();
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  int? _total;
  Object? _error;

  String get _categorySlug =>
      widget.category == MarketCategory.reits ? 'reits' : 'stocks';

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _unifiedSearch.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
      _items.clear();
      _hasMore = true;
      _total = null;
    });

    try {
      final response = await widget.repository.listUsMarketWithRetry(
        category: _categorySlug,
        page: 1,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(_mapItems(response));
        _total = response.total;
        _hasMore = response.hasMore;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);

    try {
      final nextPage = _page + 1;
      final response = await widget.repository.listUsMarketWithRetry(
        category: _categorySlug,
        page: nextPage,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _page = nextPage;
        _items.addAll(_mapItems(response));
        _total = response.total ?? _total;
        _hasMore = response.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  List<AssetItem> _mapItems(ExchangeMarketListResponseDto response) {
    final mappedCategory =
        widget.category == MarketCategory.reits ? MarketCategory.reits : MarketCategory.stocks;
    return response.items.map((quote) => quote.toUsAssetItem(category: mappedCategory)).toList();
  }

  void _onSearchChanged(String value) {
    _unifiedSearch.search(value, (snapshot) {
      if (!mounted) return;
      setState(() => _searchSnapshot = snapshot);
      if (!snapshot.active) _loadInitial();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  void _openDetail(AssetItem asset) {
    if (asset.category == MarketCategory.stocks || asset.category == MarketCategory.reits) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => GlobalStockDetailScreen(
            symbol: asset.symbol,
            repository: widget.repository,
            exchange: asset.exchangeMic,
          ),
        ),
      );
      return;
    }

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.category.title),
            Text(
              'NASDAQ, NYSE e Arca',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
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
          if (_searchSnapshot.active)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
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
        quoteRepository: widget.quoteRepository,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              marketstackErrorMessage(
                _error,
                fallback: 'Não foi possível carregar o mercado americano.',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'API: ${ApiConfig.baseUrl}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: isMarketstackQuotaError(_error)
                  ? null
                  : _loadInitial,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return const Center(child: Text('Nenhum ativo encontrado.'));
    }

    if (_categorySlug != 'stocks') {
      return NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 120) {
            _loadMore();
          }
          return false;
        },
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          itemCount: _items.length + (_loadingMore ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) => _buildListTile(context, index),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 120) {
          _loadMore();
        }
        return false;
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: StockHeatmapBlock(
              reloadKey: 'US-list',
              load: () => widget.repository.getUsHeatmap(),
              volumeLabel: 'NASDAQ · volume',
              mapAsset: (quote) => quote.toUsAssetItem(),
              onTap: _openDetail,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            sliver: SliverList.separated(
              itemCount: _items.length + (_loadingMore ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _buildListTile(context, index),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile(BuildContext context, int index) {
    if (index >= _items.length) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final asset = _items[index];
    return UsMarketQuoteListTile(
      asset: asset,
      onTap: () => _openDetail(asset),
    );
  }
}
