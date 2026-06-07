import 'package:rico_investidor/features/quotes/models/market_quote_dto.dart';
import 'package:rico_investidor/models/asset_item.dart';

class HomeMarketCounts {
  const HomeMarketCounts({
    this.cripto,
    this.stocksUs,
    this.worldExchanges,
  });

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
      cripto: intVal('cripto'),
      stocksUs: intVal('stocks_us'),
      worldExchanges: intVal('world_exchanges'),
    );
  }

  int? countForCategorySlug(String slug) {
    return switch (slug) {
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
    required this.marketCounts,
  });

  final List<AssetItem> featuredUsStocks;
  final HomeMarketCounts marketCounts;

  factory HomeFeed.fromJson(Map<String, dynamic> json) {
    final usStocksRaw = json['featured_us_stocks'] as Map<String, dynamic>?;
    final countsRaw = json['market_counts'] as Map<String, dynamic>? ?? const {};

    final usStocks = usStocksRaw == null
        ? const <AssetItem>[]
        : QuoteListResponse.fromJson(usStocksRaw).items.map((e) => e.toAssetItem()).toList();

    return HomeFeed(
      featuredUsStocks: usStocks,
      marketCounts: HomeMarketCounts.fromJson(countsRaw),
    );
  }
}
