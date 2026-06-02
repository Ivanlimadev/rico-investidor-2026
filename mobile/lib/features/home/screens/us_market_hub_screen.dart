import 'package:flutter/material.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/global_markets/data/global_market_repository.dart';
import 'package:rico_investidor/features/home/models/home_feed.dart';
import 'package:rico_investidor/features/home/widgets/market_category_card.dart';
import 'package:rico_investidor/features/market/market_list_screen.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/models/global_market_hub.dart';
import 'package:rico_investidor/models/market_category.dart';

class UsMarketHubScreen extends StatelessWidget {
  const UsMarketHubScreen({
    super.key,
    required this.fiiRepository,
    required this.quoteRepository,
    required this.globalMarketRepository,
    this.marketCount,
  });

  final FiiRepository fiiRepository;
  final QuoteRepository quoteRepository;
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
                'Mercado dos EUA — ações e REITs negociados na NYSE e NASDAQ.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
              ),
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
                        builder: (_) => MarketListScreen(
                          category: category,
                          fiiRepository: fiiRepository,
                          quoteRepository: quoteRepository,
                          globalMarketRepository: globalMarketRepository,
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
