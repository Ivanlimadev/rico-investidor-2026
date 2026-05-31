import 'package:rico_investidor/features/quotes/data/quote_api_client.dart';
import 'package:rico_investidor/features/quotes/models/stock_macro.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/fii_models.dart';

class HomeMarketCounts {
  const HomeMarketCounts({
    this.fiis,
    this.acoesBr,
    this.bdr,
    this.etf,
    this.etfIntl,
    this.moeda,
    this.tesouro,
    this.indices,
    this.cripto,
    this.stocksUs,
    this.worldExchanges,
  });

  final int? fiis;
  final int? acoesBr;
  final int? bdr;
  final int? etf;
  final int? etfIntl;
  final int? moeda;
  final int? tesouro;
  final int? indices;
  final int? cripto;
  final int? stocksUs;
  final int? worldExchanges;

  factory HomeMarketCounts.fromJson(Map<String, dynamic> json) {
    int? intVal(String key) {
      final value = json[key];
      if (value == null) return null;
      return (value as num).toInt();
    }

    return HomeMarketCounts(
      fiis: intVal('fiis'),
      acoesBr: intVal('acoes_br'),
      bdr: intVal('bdr'),
      etf: intVal('etf'),
      etfIntl: intVal('etf_intl'),
      moeda: intVal('moeda'),
      tesouro: intVal('tesouro'),
      indices: intVal('indices'),
      cripto: intVal('cripto'),
      stocksUs: intVal('stocks_us'),
      worldExchanges: intVal('world_exchanges'),
    );
  }

  int? countForCategorySlug(String slug) {
    return switch (slug) {
      'fiis' => fiis,
      'acoes_br' => acoesBr,
      'bdr' => bdr,
      'etf' => etf,
      'etf_intl' => etfIntl,
      'moeda' => moeda,
      'tesouro' => tesouro,
      'indices' => indices,
      'cripto' => cripto,
      'stocks' => stocksUs,
      'reits' => stocksUs,
      _ => null,
    };
  }
}

class HomeFeed {
  const HomeFeed({
    required this.featuredUsStocks,
    required this.featuredStocks,
    required this.featuredFiis,
    required this.marketCounts,
    this.macro,
    this.provider = 'brapi',
  });

  final List<AssetItem> featuredUsStocks;
  final List<AssetItem> featuredStocks;
  final List<FiiScreenerItem> featuredFiis;
  final HomeMarketCounts marketCounts;
  final BrazilMacroDto? macro;
  final String provider;

  factory HomeFeed.fromJson(Map<String, dynamic> json) {
    final usStocksRaw = json['featured_us_stocks'] as Map<String, dynamic>?;
    final stocksRaw = json['featured_stocks'] as Map<String, dynamic>? ?? const {};
    final fiisRaw = json['featured_fiis'] as Map<String, dynamic>? ?? const {};
    final countsRaw = json['market_counts'] as Map<String, dynamic>? ?? const {};
    final macroRaw = json['macro'];

    final usStocks = usStocksRaw == null
        ? const <AssetItem>[]
        : QuoteListResponse.fromJson(usStocksRaw).items.map((e) => e.toAssetItem()).toList();
    final stocks = QuoteListResponse.fromJson(stocksRaw).items.map((e) => e.toAssetItem()).toList();
    final fiis = FiiScreenerResponse.fromJson(fiisRaw).data;

    return HomeFeed(
      featuredUsStocks: usStocks,
      featuredStocks: stocks,
      featuredFiis: fiis,
      marketCounts: HomeMarketCounts.fromJson(countsRaw),
      macro: macroRaw is Map<String, dynamic> ? BrazilMacroDto.fromJson(macroRaw) : null,
      provider: json['provider'] as String? ?? 'brapi',
    );
  }
}
