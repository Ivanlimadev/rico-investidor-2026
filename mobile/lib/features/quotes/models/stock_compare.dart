import 'package:rico_investidor/features/quotes/models/stock_quote_detail.dart';
import 'package:rico_investidor/features/quotes/models/market_quote_dto.dart';

class StockCompareDividendsDto {
  const StockCompareDividendsDto({
    this.dividendYieldDisplay,
    this.dividendYieldTtm,
    this.ttmPerShare,
    this.frequencyLabel,
    this.payments12m,
    this.nextComDate,
    this.nextPaymentDate,
    this.nextAmount,
    this.provider,
  });

  final double? dividendYieldDisplay;
  final double? dividendYieldTtm;
  final double? ttmPerShare;
  final String? frequencyLabel;
  final int? payments12m;
  final String? nextComDate;
  final String? nextPaymentDate;
  final double? nextAmount;
  final String? provider;

  double? get displayDy {
    if (dividendYieldDisplay != null) return dividendYieldDisplay;
    return dividendYieldTtm;
  }

  factory StockCompareDividendsDto.fromJson(Map<String, dynamic> json) {
    double? numVal(String key) {
      final value = json[key];
      if (value == null) return null;
      return (value as num).toDouble();
    }

    return StockCompareDividendsDto(
      dividendYieldDisplay: numVal('dividend_yield_display'),
      dividendYieldTtm: numVal('dividend_yield_ttm'),
      ttmPerShare: numVal('ttm_per_share'),
      frequencyLabel: json['frequency_label'] as String?,
      payments12m: json['payments_12m'] as int?,
      nextComDate: json['next_com_date'] as String?,
      nextPaymentDate: json['next_payment_date'] as String?,
      nextAmount: numVal('next_amount'),
      provider: json['provider'] as String?,
    );
  }
}

class StockCompareReturnDto {
  const StockCompareReturnDto({required this.label, this.returnPct});

  final String label;
  final double? returnPct;

  factory StockCompareReturnDto.fromJson(Map<String, dynamic> json) {
    return StockCompareReturnDto(
      label: json['label'] as String? ?? '',
      returnPct: (json['return_pct'] as num?)?.toDouble(),
    );
  }
}

class StockCompareItemDto {
  const StockCompareItemDto({
    required this.quote,
    required this.profile,
    required this.fundamentals,
    required this.marketStats,
    this.dividends = const StockCompareDividendsDto(),
    this.returns = const [],
    this.provider,
  });

  final MarketQuoteDto quote;
  final StockProfileDto profile;
  final StockFundamentalsDto fundamentals;
  final StockMarketStatsDto marketStats;
  final StockCompareDividendsDto dividends;
  final List<StockCompareReturnDto> returns;
  final String? provider;

  factory StockCompareItemDto.fromJson(Map<String, dynamic> json) {
    final rawReturns = json['returns'] as List<dynamic>? ?? const [];
    return StockCompareItemDto(
      quote: MarketQuoteDto.fromJson(json['quote'] as Map<String, dynamic>),
      profile: StockProfileDto.fromJson(json['profile'] as Map<String, dynamic>? ?? const {}),
      fundamentals: StockFundamentalsDto.fromJson(
        json['fundamentals'] as Map<String, dynamic>? ?? const {},
      ),
      marketStats: StockMarketStatsDto.fromJson(
        json['market_stats'] as Map<String, dynamic>? ?? const {},
      ),
      dividends: StockCompareDividendsDto.fromJson(
        json['dividends'] as Map<String, dynamic>? ?? const {},
      ),
      returns: rawReturns
          .map((row) => StockCompareReturnDto.fromJson(row as Map<String, dynamic>))
          .toList(),
      provider: json['provider'] as String?,
    );
  }
}

class StockCompareResponseDto {
  const StockCompareResponseDto({required this.items, required this.count, this.provider});

  final List<StockCompareItemDto> items;
  final int count;
  final String? provider;

  factory StockCompareResponseDto.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? const [];
    return StockCompareResponseDto(
      items: raw.map((item) => StockCompareItemDto.fromJson(item as Map<String, dynamic>)).toList(),
      count: json['count'] as int? ?? raw.length,
      provider: json['provider'] as String?,
    );
  }
}
