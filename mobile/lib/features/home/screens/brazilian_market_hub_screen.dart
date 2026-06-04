import 'package:flutter/material.dart';
import 'package:rico_investidor/core/widgets/asset_country_flag.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/global_markets/widgets/market_hub_section_grid.dart';
import 'package:rico_investidor/features/home/models/home_feed.dart';
import 'package:rico_investidor/features/home/widgets/market_category_card.dart';
import 'package:rico_investidor/features/market/market_list_screen.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/features/quotes/screens/stock_explore_screen.dart';
import 'package:rico_investidor/core/widgets/market_heatmap/stock_heatmap_block.dart';
import 'package:rico_investidor/features/home/data/brazilian_hub_sections.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/brazilian_market_hub.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/navigation/open_asset_detail.dart';

class BrazilianMarketHubScreen extends StatefulWidget {
  const BrazilianMarketHubScreen({
    super.key,
    required this.fiiRepository,
    required this.quoteRepository,
    this.marketCount,
  });

  final FiiRepository fiiRepository;
  final QuoteRepository quoteRepository;
  final int? Function(MarketCategory category)? marketCount;

  @override
  State<BrazilianMarketHubScreen> createState() => _BrazilianMarketHubScreenState();
}

class _BrazilianMarketHubScreenState extends State<BrazilianMarketHubScreen> {
  late Future<List<MarketHubSectionData>> _sectionsFuture;

  @override
  void initState() {
    super.initState();
    _sectionsFuture = _loadSections();
  }

  Future<List<MarketHubSectionData>> _loadSections() {
    return loadBrazilianHubSections(widget.quoteRepository);
  }

  Future<void> _refresh() async {
    setState(() {
      _sectionsFuture = _loadSections();
    });
    await _sectionsFuture;
  }

  void _openAsset(AssetItem asset) {
    openAssetDetail(
      context,
      asset: asset,
      fiiRepository: widget.fiiRepository,
      quoteRepository: widget.quoteRepository,
    );
  }

  void _openStockExplore() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StockExploreScreen(
          repository: widget.quoteRepository,
          fiiRepository: widget.fiiRepository,
          category: MarketCategory.acoesBr,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            CountryFlagImage(countryCode: 'BR', size: 22),
            SizedBox(width: 10),
            Text('Bolsa Brasileira'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  'Principais ativos, maiores altas, tecnologia e categorias da B3.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: StockHeatmapBlock(
                reloadKey: 'BR',
                load: () => widget.quoteRepository.getHeatmap(),
                volumeLabel: 'Volume B3',
                onTap: _openAsset,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _openStockExplore,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(Icons.leaderboard_outlined, size: 26),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ranking completo',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                Text(
                                  'Todas as ações da B3',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.65),
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            FutureBuilder<List<MarketHubSectionData>>(
              future: _sectionsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Não foi possível carregar os destaques.'),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _refresh,
                            child: const Text('Tentar novamente'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final sections = snapshot.data ?? const [];
                if (sections.isEmpty) {
                  return const SliverToBoxAdapter(child: SizedBox.shrink());
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => MarketHubSectionGrid(
                      section: sections[index],
                      logoSize: 38,
                      onAssetTap: _openAsset,
                    ),
                    childCount: sections.length,
                  ),
                );
              },
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                child: Text(
                  'Categorias',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
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
                    final category = brazilianMarketCategories[index];
                    return MarketCategoryCard(
                      category: category,
                      assetCount: widget.marketCount?.call(category),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => MarketListScreen(
                            category: category,
                            fiiRepository: widget.fiiRepository,
                            quoteRepository: widget.quoteRepository,
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: brazilianMarketCategories.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Soma aproximada de ativos listados nas categorias da Bolsa Brasileira.
int? brazilianMarketTotalAssets(HomeFeed? feed) {
  if (feed == null) return null;

  var total = 0;
  var hasAny = false;

  for (final category in brazilianMarketCategories) {
    final count = switch (category) {
      MarketCategory.fiis => feed.marketCounts.fiis,
      MarketCategory.acoesBr => feed.marketCounts.acoesBr,
      MarketCategory.bdr => feed.marketCounts.bdr,
      MarketCategory.etf => feed.marketCounts.etf,
      MarketCategory.moeda => feed.marketCounts.moeda,
      MarketCategory.tesouroDireto => feed.marketCounts.tesouro,
      MarketCategory.indices => feed.marketCounts.indices,
      _ => null,
    };
    if (count != null) {
      total += count;
      hasAny = true;
    }
  }

  return hasAny ? total : null;
}
