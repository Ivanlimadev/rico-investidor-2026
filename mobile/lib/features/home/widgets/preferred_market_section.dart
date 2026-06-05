import 'package:flutter/material.dart';
import 'package:rico_investidor/core/widgets/asset_country_flag.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/global_markets/data/global_market_repository.dart';
import 'package:rico_investidor/features/global_markets/screens/country_hub_screen.dart';
import 'package:rico_investidor/features/global_markets/screens/country_market_screen.dart';
import 'package:rico_investidor/features/global_markets/widgets/market_hub_section_grid.dart';
import 'package:rico_investidor/features/home/data/preferred_market_preloader.dart';
import 'package:rico_investidor/features/home/screens/brazilian_market_hub_screen.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/features/quotes/screens/stock_explore_screen.dart';
import 'package:rico_investidor/core/widgets/market_heatmap/stock_heatmap_block.dart';
import 'package:rico_investidor/features/global_markets/models/global_market_models.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/navigation/open_asset_detail.dart';
import 'package:rico_investidor/services/market_preference_storage.dart';

/// Bloco da home que exibe o mercado preferido do usuário (ranking, principais
/// ativos, maiores altas/baixas e setores), abaixo do card de distribuição.
class PreferredMarketSection extends StatefulWidget {
  const PreferredMarketSection({
    super.key,
    required this.preference,
    required this.globalMarketRepository,
    required this.fiiRepository,
    required this.quoteRepository,
    required this.onChangePreferred,
  });

  final MarketPreference preference;
  final GlobalMarketRepository globalMarketRepository;
  final FiiRepository fiiRepository;
  final QuoteRepository quoteRepository;
  final VoidCallback onChangePreferred;

  @override
  State<PreferredMarketSection> createState() => _PreferredMarketSectionState();
}

class _PreferredMarketSectionState extends State<PreferredMarketSection> {
  late Future<List<MarketHubSectionData>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant PreferredMarketSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preference.code != widget.preference.code) {
      setState(() {
        _future = _load();
      });
    }
  }

  Future<List<MarketHubSectionData>> _load() {
    return preferredMarketPreloader.load(
      preference: widget.preference,
      quoteRepository: widget.quoteRepository,
      globalMarketRepository: widget.globalMarketRepository,
    );
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  void _openAsset(AssetItem asset) {
    openAssetDetail(
      context,
      asset: asset,
      fiiRepository: widget.fiiRepository,
      quoteRepository: widget.quoteRepository,
      globalMarketRepository: widget.globalMarketRepository,
    );
  }

  void _openFullHub() {
    if (widget.preference.isBrazil) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BrazilianMarketHubScreen(
            fiiRepository: widget.fiiRepository,
            quoteRepository: widget.quoteRepository,
            globalMarketRepository: widget.globalMarketRepository,
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CountryHubScreen(
          countryCode: widget.preference.code,
          countryName: widget.preference.name,
          repository: widget.globalMarketRepository,
          fiiRepository: widget.fiiRepository,
          quoteRepository: widget.quoteRepository,
        ),
      ),
    );
  }

  void _openRanking() {
    if (widget.preference.isBrazil) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => StockExploreScreen(
            repository: widget.quoteRepository,
            fiiRepository: widget.fiiRepository,
            category: MarketCategory.acoesBr,
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CountryMarketScreen(
          countryCode: widget.preference.code,
          countryName: widget.preference.name,
          repository: widget.globalMarketRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          preference: widget.preference,
          onChange: widget.onChangePreferred,
        ),
        _ActionsRow(onRanking: _openRanking, onFullHub: _openFullHub),
        if (widget.preference.isBrazil)
          StockHeatmapBlock(
            key: ValueKey('heatmap-${widget.preference.code}'),
            reloadKey: widget.preference.code,
            load: () => widget.quoteRepository.getHeatmap(),
            volumeLabel: 'Volume B3',
            onTap: _openAsset,
          )
        else if (widget.preference.code.toUpperCase() == 'US')
          StockHeatmapBlock(
            key: ValueKey('heatmap-${widget.preference.code}'),
            reloadKey: widget.preference.code,
            load: () => widget.globalMarketRepository.getUsHeatmap(),
            volumeLabel: 'NASDAQ · volume',
            mapAsset: (quote) => quote.toUsAssetItem(),
            onTap: _openAsset,
          ),
        FutureBuilder<List<MarketHubSectionData>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: Column(
                  children: [
                    Text('Não foi possível carregar ${widget.preference.name}.'),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _reload, child: const Text('Tentar novamente')),
                  ],
                ),
              );
            }

            final sections = snapshot.data ?? const [];
            if (sections.isEmpty) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Destaques indisponíveis para ${widget.preference.name} no momento.'),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _openRanking,
                      child: const Text('Ver ranking completo'),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                for (final section in sections)
                  MarketHubSectionGrid(
                    section: section,
                    logoSize: 38,
                    onAssetTap: _openAsset,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.preference, required this.onChange});

  final MarketPreference preference;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 12, 0),
      child: Row(
        children: [
          CountryFlagImage(countryCode: preference.code, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Mercado · ${preference.name}',
              style: Theme.of(context).textTheme.headlineMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton.icon(
            onPressed: onChange,
            icon: const Icon(Icons.swap_horiz, size: 18),
            label: const Text('Trocar'),
          ),
        ],
      ),
    );
  }
}

class _ActionsRow extends StatelessWidget {
  const _ActionsRow({required this.onRanking, required this.onFullHub});

  final VoidCallback onRanking;
  final VoidCallback onFullHub;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _ActionCard(
              icon: Icons.leaderboard_outlined,
              title: 'Ranking completo',
              onTap: onRanking,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ActionCard(
              icon: Icons.dashboard_customize_outlined,
              title: 'Abrir hub do país',
              onTap: onFullHub,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.icon, required this.title, required this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
