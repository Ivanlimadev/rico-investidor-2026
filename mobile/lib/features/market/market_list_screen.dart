import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/data/mock_market_data.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/fii/screens/fii_list_screen.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/features/quotes/screens/stock_compare_screen.dart';
import 'package:rico_investidor/features/quotes/screens/stock_explore_screen.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/navigation/open_asset_detail.dart';
import 'package:rico_investidor/models/market_category.dart';

class MarketListScreen extends StatefulWidget {
  const MarketListScreen({
    super.key,
    required this.category,
    required this.fiiRepository,
    required this.quoteRepository,
  });

  final MarketCategory category;
  final FiiRepository fiiRepository;
  final QuoteRepository quoteRepository;

  @override
  State<MarketListScreen> createState() => _MarketListScreenState();
}

class _MarketListScreenState extends State<MarketListScreen> {
  late Future<List<AssetItem>> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadAssets();
  }

  Future<List<AssetItem>> _loadAssets() async {
    if (widget.category == MarketCategory.fiis) return const [];

    if (widget.quoteRepository.supportsCategory(widget.category)) {
      try {
        final items = await widget.quoteRepository.listByCategory(widget.category);
        if (items.isNotEmpty) return items;
      } catch (_) {}
    }

    return MockMarketData.byCategory(widget.category);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.category == MarketCategory.fiis) {
      return FiiListScreen(repository: widget.fiiRepository);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category.title),
        actions: [
          if (widget.quoteRepository.supportsCategory(widget.category)) ...[
            IconButton(
              tooltip: 'Explorar',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => StockExploreScreen(
                    repository: widget.quoteRepository,
                    fiiRepository: widget.fiiRepository,
                    category: widget.category,
                  ),
                ),
              ),
              icon: const Icon(Icons.tune),
            ),
            IconButton(
              tooltip: 'Comparar',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => StockCompareScreen(repository: widget.quoteRepository),
                ),
              ),
              icon: const Icon(Icons.compare_arrows),
            ),
          ],
          const ShellHomeButton(),
        ],
      ),
      body: FutureBuilder<List<AssetItem>>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final assets = snapshot.data ?? const [];
          if (assets.isEmpty) {
            return Center(
              child: Text(
                'Nenhum ativo nesta categoria ainda.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: assets.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _AssetListTile(
              asset: assets[index],
              onTap: () => openAssetDetail(
                context,
                asset: assets[index],
                fiiRepository: widget.fiiRepository,
                quoteRepository: widget.quoteRepository,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AssetListTile extends StatelessWidget {
  const _AssetListTile({required this.asset, required this.onTap});

  final AssetItem asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final changeColor = asset.isPositive ? AppColors.positive : AppColors.negative;

    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        title: Text(asset.symbol, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(asset.name),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatBrl(asset.price),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              '${asset.isPositive ? '+' : ''}${asset.changePercent.toStringAsFixed(2)}%',
              style: TextStyle(color: changeColor, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
