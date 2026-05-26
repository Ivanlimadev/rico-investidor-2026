import 'package:rico_investidor/features/quotes/data/quote_api_client.dart';
import 'package:rico_investidor/features/quotes/models/stock_quote_detail.dart';

class StockCompareItemDto {
  const StockCompareItemDto({
    required this.quote,
    required this.profile,
    required this.fundamentals,
    required this.marketStats,
  });

  final MarketQuoteDto quote;
  final StockProfileDto profile;
  final StockFundamentalsDto fundamentals;
  final StockMarketStatsDto marketStats;

  factory StockCompareItemDto.fromJson(Map<String, dynamic> json) {
    return StockCompareItemDto(
      quote: MarketQuoteDto.fromJson(json['quote'] as Map<String, dynamic>),
      profile: StockProfileDto.fromJson(json['profile'] as Map<String, dynamic>? ?? const {}),
      fundamentals: StockFundamentalsDto.fromJson(
        json['fundamentals'] as Map<String, dynamic>? ?? const {},
      ),
      marketStats: StockMarketStatsDto.fromJson(
        json['market_stats'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

class StockCompareResponseDto {
  const StockCompareResponseDto({required this.items, required this.count});

  final List<StockCompareItemDto> items;
  final int count;

  factory StockCompareResponseDto.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? const [];
    return StockCompareResponseDto(
      items: raw.map((item) => StockCompareItemDto.fromJson(item as Map<String, dynamic>)).toList(),
      count: json['count'] as int? ?? raw.length,
    );
  }
}
