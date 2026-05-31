import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/core/widgets/asset_card_header.dart';
import 'package:rico_investidor/core/widgets/asset_country_flag.dart';
import 'package:rico_investidor/features/global_markets/data/global_market_repository.dart';
import 'package:rico_investidor/features/global_markets/models/global_market_models.dart';
import 'package:rico_investidor/features/global_markets/screens/global_stock_detail_screen.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/market_category.dart';

class CountryMarketScreen extends StatefulWidget {
  const CountryMarketScreen({
    super.key,
    required this.countryCode,
    required this.countryName,
    required this.repository,
    this.exchangeCount,
  });

  final String countryCode;
  final String countryName;
  final GlobalMarketRepository repository;
  final int? exchangeCount;

  @override
  State<CountryMarketScreen> createState() => _CountryMarketScreenState();
}

class _CountryMarketScreenState extends State<CountryMarketScreen> {
  static const _pageSize = 25;

  final _searchController = TextEditingController();
  final _items = <AssetItem>[];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  Object? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
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
      final response = await widget.repository.listCountryMarket(
        widget.countryCode,
        page: 1,
        limit: _pageSize,
        search: _searchQuery.isEmpty ? null : _searchQuery,
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
      final response = await widget.repository.listCountryMarket(
        widget.countryCode,
        page: nextPage,
        limit: _pageSize,
        search: _searchQuery.isEmpty ? null : _searchQuery,
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

  void _onSearchSubmitted(String value) {
    final query = value.trim();
    if (query == _searchQuery) return;
    setState(() => _searchQuery = query);
    _loadInitial();
  }

  void _clearSearch() {
    _searchController.clear();
    if (_searchQuery.isEmpty) return;
    setState(() => _searchQuery = '');
    _loadInitial();
  }

  String _formatPrice(double value) {
    if (widget.countryCode.toUpperCase() == 'BR') {
      return formatBrl(value);
    }
    return formatUsd(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CountryFlagImage(countryCode: widget.countryCode, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(widget.countryName),
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
              hintText: 'Buscar ativo em ${widget.countryName}',
              leading: const Icon(Icons.search),
              trailing: [
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    tooltip: 'Limpar',
                    onPressed: _clearSearch,
                    icon: const Icon(Icons.close),
                  ),
              ],
              onSubmitted: _onSearchSubmitted,
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Não foi possível carregar os ativos de ${widget.countryName}.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: _loadInitial, child: const Text('Tentar novamente')),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(child: Text('Nenhum ativo encontrado em ${widget.countryName}.'));
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
          final positive = asset.changePercent >= 0;
          final changeColor = positive ? AppColors.positive : AppColors.negative;

          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => GlobalStockDetailScreen(
                      symbol: asset.symbol,
                      repository: widget.repository,
                      exchange: asset.exchangeMic,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: AssetCardHeader(
                        symbol: asset.symbol,
                        name: asset.name,
                        logoUrl: asset.logoUrl,
                        logoSize: kAssetLogoSizeCompact,
                        nameMaxLines: 1,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatPrice(asset.price),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        Text(
                          '${positive ? '+' : ''}${asset.changePercent.toStringAsFixed(2)}%',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: changeColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
