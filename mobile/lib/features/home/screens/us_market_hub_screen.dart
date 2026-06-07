import 'package:flutter/material.dart';
import 'package:rico_investidor/features/global_markets/data/global_market_repository.dart';
import 'package:rico_investidor/features/global_markets/screens/us_market_list_screen.dart';
import 'package:rico_investidor/features/home/models/home_feed.dart';
import 'package:rico_investidor/features/home/widgets/market_category_card.dart';
import 'package:rico_investidor/core/widgets/market_heatmap/stock_heatmap_block.dart';
import 'package:rico_investidor/features/global_markets/models/global_market_models.dart';
import 'package:rico_investidor/models/global_market_hub.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/navigation/open_asset_detail.dart';

class UsMarketHubScreen extends StatelessWidget {
  const UsMarketHubScreen({
    super.key,
    required this.globalMarketRepository,
    this.marketCount,
  });

  final GlobalMarketRepository globalMarketRepository;
  final int? Function(MarketCategory category)? marketCount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bolsa Americana'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Text(
                'Mercado americano — ações e REITs negociados na NYSE e NASDAQ.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: StockHeatmapBlock(
              reloadKey: 'US',
              load: () => globalMarketRepository.getUsHeatmap(),
              volumeLabel: 'NASDAQ · volume',
              mapAsset: (quote) => quote.toUsAssetItem(),
              onTap: (asset) => openAssetDetail(
                context,
                asset: asset,
              ),
              resolveRefreshSeconds: () async {
                final caps = await globalMarketRepository.getCapabilities();
                return caps.realtimeEnabled ? (caps.refreshSeconds ?? 60) : null;
              },
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.82,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final category = usMarketCategories[index];
                  return MarketCategoryCard(
                    category: category,
                    assetCount: marketCount?.call(category),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => UsMarketListScreen(
                          category: category,
                          repository: globalMarketRepository,
                        ),
                      ),
                    ),
                  );
                },
                childCount: usMarketCategories.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

int? usMarketFeaturedCount(HomeFeed? feed) {
  return feed?.marketCounts.stocksUs;
}
