import 'package:flutter/material.dart';
import 'package:rico_investidor/core/widgets/asset_country_flag.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/global_markets/data/global_market_repository.dart';
import 'package:rico_investidor/features/global_markets/models/global_market_models.dart';
import 'package:rico_investidor/features/global_markets/screens/country_market_screen.dart';
import 'package:rico_investidor/features/global_markets/screens/global_stock_compare_screen.dart';
import 'package:rico_investidor/features/global_markets/widgets/market_hub_section_grid.dart';
import 'package:rico_investidor/core/widgets/market_heatmap/stock_heatmap_block.dart';
import 'package:rico_investidor/features/home/screens/us_market_hub_screen.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/navigation/open_asset_detail.dart';

class CountryHubScreen extends StatefulWidget {
  const CountryHubScreen({
    super.key,
    required this.countryCode,
    required this.countryName,
    required this.repository,
    required this.fiiRepository,
    required this.quoteRepository,
    this.exchangeCount,
  });

  final String countryCode;
  final String countryName;
  final GlobalMarketRepository repository;
  final FiiRepository fiiRepository;
  final QuoteRepository quoteRepository;
  final int? exchangeCount;

  @override
  State<CountryHubScreen> createState() => _CountryHubScreenState();
}

class _CountryHubScreenState extends State<CountryHubScreen> {
  late Future<CountryHubResponseDto> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.getCountryHub(widget.countryCode);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = widget.repository.getCountryHub(widget.countryCode);
    });
    await _future;
  }

  void _openRanking() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CountryMarketScreen(
          countryCode: widget.countryCode,
          countryName: widget.countryName,
          repository: widget.repository,
          exchangeCount: widget.exchangeCount,
        ),
      ),
    );
  }

  void _openUsMarketHub() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UsMarketHubScreen(
          fiiRepository: widget.fiiRepository,
          quoteRepository: widget.quoteRepository,
          globalMarketRepository: widget.repository,
        ),
      ),
    );
  }

  void _openCompare() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GlobalStockCompareScreen(repository: widget.repository),
      ),
    );
  }

  void _openAsset(AssetItem asset) {
    openAssetDetail(
      context,
      asset: asset,
      fiiRepository: widget.fiiRepository,
      quoteRepository: widget.quoteRepository,
    );
  }

  List<_CountryHubAction> _quickActions() {
    final code = widget.countryCode.toUpperCase();

    final actions = <_CountryHubAction>[
      _CountryHubAction(
        title: 'Ranking completo',
        subtitle: 'Ver todos',
        icon: Icons.leaderboard_outlined,
        onTap: _openRanking,
      ),
    ];

    if (code == 'US') {
      actions.addAll([
        _CountryHubAction(
          title: 'Bolsa Americana',
          subtitle: 'Ações e REITs',
          icon: Icons.public,
          onTap: _openUsMarketHub,
        ),
        _CountryHubAction(
          title: 'Comparador',
          subtitle: 'Até 3 tickers',
          icon: Icons.compare_arrows,
          onTap: _openCompare,
        ),
      ]);
    }

    return actions;
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
      body: FutureBuilder<CountryHubResponseDto>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Não foi possível carregar ${widget.countryName}.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _refresh,
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!;
          final actions = _quickActions();

          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Text(
                      'Principais ativos, maiores altas, tecnologia e mais.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                    ),
                  ),
                ),
                if (widget.countryCode.toUpperCase() == 'US')
                  SliverToBoxAdapter(
                    child: StockHeatmapBlock(
                      reloadKey: 'US',
                      load: () => widget.repository.getUsHeatmap(),
                      volumeLabel: 'NASDAQ · volume',
                      mapAsset: (quote) => quote.toUsAssetItem(),
                      onTap: _openAsset,
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: actions.length >= 3 ? 3 : 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: actions.length >= 3 ? 0.95 : 1.35,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final action = actions[index];
                        return _QuickActionCard(action: action);
                      },
                      childCount: actions.length,
                    ),
                  ),
                ),
                if (data.sections.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Destaques indisponíveis para ${widget.countryName} no momento.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _openRanking,
                              child: const Text('Ver ranking completo'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  ...data.sections.map(
                    (section) => SliverToBoxAdapter(
                      child: MarketHubSectionGrid(
                        section: MarketHubSectionData(
                          id: section.id,
                          title: section.title,
                          assets: section.items
                              .map((quote) => quote.toUsAssetItem(category: MarketCategory.stocks))
                              .toList(),
                        ),
                        onAssetTap: _openAsset,
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CountryHubAction {
  const _CountryHubAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.action});

  final _CountryHubAction action;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: action.onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(action.icon, size: 26),
              const Spacer(),
              Text(
                action.title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                action.subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
