import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/core/search/asset_search_config.dart';
import 'package:rico_investidor/core/search/unified_asset_search.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/features/global_markets/widgets/us_market_quote_list_tile.dart';
import 'package:rico_investidor/features/global_markets/data/global_market_repository.dart';
import 'package:rico_investidor/features/global_markets/models/global_market_models.dart';
import 'package:rico_investidor/features/global_markets/screens/global_stock_detail_screen.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/navigation/open_asset_detail.dart';

class ExchangeMarketScreen extends StatefulWidget {
  const ExchangeMarketScreen({
    super.key,
    required this.exchangeMic,
    required this.exchangeName,
    required this.repository,
    this.countryCode,
  });

  final String exchangeMic;
  final String exchangeName;
  final String? countryCode;
  final GlobalMarketRepository repository;

  @override
  State<ExchangeMarketScreen> createState() => _ExchangeMarketScreenState();
}

class _ExchangeMarketScreenState extends State<ExchangeMarketScreen> {
  static const _pageSize = 25;

  final _searchController = TextEditingController();
  final _unifiedSearch = UnifiedAssetSearchRunner();
  final _items = <AssetItem>[];
  UnifiedAssetSearchSnapshot _searchSnapshot = const UnifiedAssetSearchSnapshot.idle();
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  Object? _error;

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
    });

    try {
      final response = await widget.repository.listExchangeMarket(
        widget.exchangeMic,
        exchangeName: widget.exchangeName,
        countryCode: widget.countryCode,
        page: 1,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(_mapItems(response));
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
      final response = await widget.repository.listExchangeMarket(
        widget.exchangeMic,
        exchangeName: widget.exchangeName,
        countryCode: widget.countryCode,
        page: nextPage,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _page = nextPage;
        _items.addAll(_mapItems(response));
        _hasMore = response.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  List<AssetItem> _mapItems(ExchangeMarketListResponseDto response) {
    return response.items
        .map((quote) => quote.toUsAssetItem(category: MarketCategory.stocks))
        .toList();
  }

  void _onSearchChanged(String value) {
    _unifiedSearch.search(
      value,
      (snapshot) {
        if (!mounted) return;
        setState(() => _searchSnapshot = snapshot);
        if (!snapshot.active) _loadInitial();
      },
      preferredMarket: AppShellScope.maybeOf(context)?.preferredMarket,
    );
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
            exchange: asset.exchangeMic ?? widget.exchangeMic,
          ),
        ),
      );
      return;
    }

    openAssetDetail(
      context,
      asset: asset,
    );
  }

  String _formatPrice(double value) {
    if (widget.countryCode?.toUpperCase() == 'BR') {
      return formatBrl(value);
    }
    return '\$${value.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.exchangeName),
            Text(
              widget.exchangeMic,
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
            const Text('Não foi possível carregar os ativos desta bolsa.'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loadInitial,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return const Center(child: Text('Nenhum ativo encontrado.'));
    }

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
        itemBuilder: (context, index) {
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
            formatPrice: _formatPrice,
          );
        },
      ),
    );
  }
}
