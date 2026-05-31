import 'package:rico_investidor/features/global_markets/widgets/market_hub_section_grid.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/features/quotes/utils/stock_screener_presets.dart';

/// Carrega as seções do hub brasileiro (Brapi): principais ativos, altas,
/// baixas e tecnologia. Reutilizado pela tela completa e pela home.
Future<List<MarketHubSectionData>> loadBrazilianHubSections(
  QuoteRepository quoteRepository,
) async {
  final volumePreset = stockScreenerPresets.firstWhere((p) => p.id == 'volume');
  final gainersPreset = stockScreenerPresets.firstWhere((p) => p.id == 'gainers');
  final losersPreset = stockScreenerPresets.firstWhere((p) => p.id == 'losers');
  const techPreset = StockScreenerPreset(
    id: 'tech',
    label: 'Tecnologia',
    sector: 'Technology Services',
    sortBy: 'volume',
  );

  final results = await Future.wait([
    quoteRepository.screener(volumePreset.toQuery(limit: 35, page: 1)),
    quoteRepository.screener(gainersPreset.toQuery(limit: 8, page: 1)),
    quoteRepository.screener(losersPreset.toQuery(limit: 8, page: 1)),
    quoteRepository.screener(techPreset.toQuery(limit: 6, page: 1)),
  ]);

  final featured = results[0];
  final gainers = results[1];
  final losers = results[2];
  final tech = results[3];

  return [
    MarketHubSectionData(
      id: 'featured',
      title: 'Principais ativos',
      assets: featured.items.map((e) => e.toAssetItem()).toList(),
    ),
    MarketHubSectionData(
      id: 'gainers',
      title: 'Maiores altas',
      assets: gainers.items.map((e) => e.toAssetItem()).toList(),
    ),
    MarketHubSectionData(
      id: 'losers',
      title: 'Maiores baixas',
      assets: losers.items.map((e) => e.toAssetItem()).toList(),
    ),
    if (tech.items.isNotEmpty)
      MarketHubSectionData(
        id: 'tech',
        title: 'Tecnologia',
        assets: tech.items.map((e) => e.toAssetItem()).toList(),
      ),
  ].where((section) => section.assets.isNotEmpty).toList();
}
