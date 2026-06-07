import 'package:rico_investidor/features/global_markets/models/global_market_models.dart';
import 'package:rico_investidor/models/market_series_models.dart';
import 'package:rico_investidor/features/quotes/models/market_quote_dto.dart';

class StockMarketStatsDto {
  const StockMarketStatsDto({
    this.open,
    this.dayHigh,
    this.dayLow,
    this.previousClose,
    this.volume,
    this.avgDailyVolume,
    this.marketCap,
    this.priceEarnings,
    this.earningsPerShare,
    this.fiftyTwoWeekLow,
    this.fiftyTwoWeekHigh,
    this.fiftyTwoWeekRange,
    this.priceRangeSessions,
    this.priceRangeLabel,
  });

  final double? open;
  final double? dayHigh;
  final double? dayLow;
  final double? previousClose;
  final double? volume;
  final double? avgDailyVolume;
  final double? marketCap;
  final double? priceEarnings;
  final double? earningsPerShare;
  final double? fiftyTwoWeekLow;
  final double? fiftyTwoWeekHigh;
  final String? fiftyTwoWeekRange;
  final int? priceRangeSessions;
  final String? priceRangeLabel;

  factory StockMarketStatsDto.fromJson(Map<String, dynamic> json) {
    double? numVal(String key) {
      final value = json[key];
      if (value == null) return null;
      return (value as num).toDouble();
    }

    return StockMarketStatsDto(
      open: numVal('open'),
      dayHigh: numVal('day_high'),
      dayLow: numVal('day_low'),
      previousClose: numVal('previous_close'),
      volume: numVal('volume'),
      avgDailyVolume: numVal('avg_daily_volume'),
      marketCap: numVal('market_cap'),
      priceEarnings: numVal('price_earnings'),
      earningsPerShare: numVal('earnings_per_share'),
      fiftyTwoWeekLow: numVal('fifty_two_week_low'),
      fiftyTwoWeekHigh: numVal('fifty_two_week_high'),
      fiftyTwoWeekRange: json['fifty_two_week_range'] as String?,
      priceRangeSessions: (json['price_range_sessions'] as num?)?.toInt(),
      priceRangeLabel: json['price_range_label'] as String?,
    );
  }
}

class StockProfileDto {
  const StockProfileDto({
    this.sector,
    this.industry,
    this.website,
    this.summary,
    this.employees,
    this.country,
    this.logoUrl,
  });

  final String? sector;
  final String? industry;
  final String? website;
  final String? summary;
  final int? employees;
  final String? country;
  final String? logoUrl;

  factory StockProfileDto.fromJson(Map<String, dynamic> json) {
    return StockProfileDto(
      sector: json['sector'] as String?,
      industry: json['industry'] as String?,
      website: json['website'] as String?,
      summary: json['summary'] as String?,
      employees: json['employees'] as int?,
      country: json['country'] as String?,
      logoUrl: json['logo_url'] as String?,
    );
  }
}

class StockFundamentalsDto {
  const StockFundamentalsDto({
    this.dividendYield12m,
    this.priceEarnings,
    this.priceToBook,
    this.returnOnEquity,
    this.returnOnAssets,
    this.profitMargin,
    this.debtToEquity,
    this.payoutRatio,
    this.beta,
    this.bookValuePerShare,
    this.earningsPerShare,
    this.freeCashflow,
    this.earningsGrowth,
    this.totalRevenue,
    this.ebitda,
    this.enterpriseValue,
    this.enterpriseToEbitda,
    this.forwardPe,
    this.grossMargin,
    this.operatingMargin,
    this.revenueGrowth,
    this.totalCash,
    this.totalDebt,
    this.currentRatio,
    this.targetMeanPrice,
    this.recommendationKey,
    this.numberOfAnalystOpinions,
  });

  final double? dividendYield12m;
  final double? priceEarnings;
  final double? priceToBook;
  final double? returnOnEquity;
  final double? returnOnAssets;
  final double? profitMargin;
  final double? debtToEquity;
  final double? payoutRatio;
  final double? beta;
  final double? bookValuePerShare;
  final double? earningsPerShare;
  final double? freeCashflow;
  final double? earningsGrowth;
  final double? totalRevenue;
  final double? ebitda;
  final double? enterpriseValue;
  final double? enterpriseToEbitda;
  final double? forwardPe;
  final double? grossMargin;
  final double? operatingMargin;
  final double? revenueGrowth;
  final double? totalCash;
  final double? totalDebt;
  final double? currentRatio;
  final double? targetMeanPrice;
  final String? recommendationKey;
  final int? numberOfAnalystOpinions;

  factory StockFundamentalsDto.fromJson(Map<String, dynamic> json) {
    double? numVal(String key) {
      final value = json[key];
      if (value == null) return null;
      return (value as num).toDouble();
    }

    return StockFundamentalsDto(
      dividendYield12m: numVal('dividend_yield_12m'),
      priceEarnings: numVal('price_earnings'),
      priceToBook: numVal('price_to_book'),
      returnOnEquity: numVal('return_on_equity'),
      returnOnAssets: numVal('return_on_assets'),
      profitMargin: numVal('profit_margin'),
      debtToEquity: numVal('debt_to_equity'),
      payoutRatio: numVal('payout_ratio'),
      beta: numVal('beta'),
      bookValuePerShare: numVal('book_value_per_share'),
      earningsPerShare: numVal('earnings_per_share'),
      freeCashflow: numVal('free_cashflow'),
      earningsGrowth: numVal('earnings_growth'),
      totalRevenue: numVal('total_revenue'),
      ebitda: numVal('ebitda'),
      enterpriseValue: numVal('enterprise_value'),
      enterpriseToEbitda: numVal('enterprise_to_ebitda'),
      forwardPe: numVal('forward_pe'),
      grossMargin: numVal('gross_margin'),
      operatingMargin: numVal('operating_margin'),
      revenueGrowth: numVal('revenue_growth'),
      totalCash: numVal('total_cash'),
      totalDebt: numVal('total_debt'),
      currentRatio: numVal('current_ratio'),
      targetMeanPrice: numVal('target_mean_price'),
      recommendationKey: json['recommendation_key'] as String?,
      numberOfAnalystOpinions: json['number_of_analyst_opinions'] as int?,
    );
  }
}

class StockCorporateActionDto {
  const StockCorporateActionDto({
    this.label,
    this.factor,
    this.completeFactor,
    this.exDate,
  });

  final String? label;
  final double? factor;
  final String? completeFactor;
  final String? exDate;

  factory StockCorporateActionDto.fromJson(Map<String, dynamic> json) {
    final factor = json['factor'];
    return StockCorporateActionDto(
      label: json['label'] as String?,
      factor: factor == null ? null : (factor as num).toDouble(),
      completeFactor: json['complete_factor'] as String?,
      exDate: json['ex_date'] as String?,
    );
  }
}

class StockDividendEventDto {
  const StockDividendEventDto({
    this.label,
    this.comDate,
    this.exDate,
    this.paymentDate,
    this.valuePerShare,
    this.isProjected = false,
  });

  final String? label;
  final String? comDate;
  final String? exDate;
  final String? paymentDate;
  final double? valuePerShare;
  final bool isProjected;

  factory StockDividendEventDto.fromJson(Map<String, dynamic> json) {
    return StockDividendEventDto(
      label: json['label'] as String?,
      comDate: json['com_date'] as String?,
      exDate: json['ex_date'] as String?,
      paymentDate: json['payment_date'] as String?,
      valuePerShare: (json['value_per_share'] as num?)?.toDouble(),
      isProjected: json['is_projected'] as bool? ?? false,
    );
  }
}

class StockDividendsSummaryDto {
  const StockDividendsSummaryDto({
    this.dividendYieldDisplay,
    this.ttmPerShareDisplay,
    this.dividendYieldAvg5y,
    this.dividendYieldAvg10y,
    this.frequencyLabel,
    this.avgAmount12m,
    this.payments12m,
    this.nextDividend,
    this.upcoming = const [],
  });

  final double? dividendYieldDisplay;
  final double? ttmPerShareDisplay;
  final double? dividendYieldAvg5y;
  final double? dividendYieldAvg10y;
  final String? frequencyLabel;
  final double? avgAmount12m;
  final int? payments12m;
  final StockDividendEventDto? nextDividend;
  final List<StockDividendEventDto> upcoming;

  factory StockDividendsSummaryDto.fromJson(Map<String, dynamic> json) {
    final upcomingRaw = json['upcoming'] as List<dynamic>? ?? const [];
    final nextRaw = json['next_dividend'] as Map<String, dynamic>?;
    return StockDividendsSummaryDto(
      dividendYieldDisplay: (json['dividend_yield_display'] as num?)?.toDouble(),
      ttmPerShareDisplay: (json['ttm_per_share_display'] as num?)?.toDouble(),
      dividendYieldAvg5y: (json['dividend_yield_avg_5y'] as num?)?.toDouble(),
      dividendYieldAvg10y: (json['dividend_yield_avg_10y'] as num?)?.toDouble(),
      frequencyLabel: json['frequency_label'] as String?,
      avgAmount12m: (json['avg_amount_12m'] as num?)?.toDouble(),
      payments12m: (json['payments_12m'] as num?)?.toInt(),
      nextDividend: nextRaw == null ? null : StockDividendEventDto.fromJson(nextRaw),
      upcoming: upcomingRaw
          .map((e) => StockDividendEventDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class StockDividendsDto {
  const StockDividendsDto({
    required this.payments,
    this.annualSummary = const [],
    this.ttmPerShare,
    this.dividendYieldTtm,
    this.totalPayments,
    this.corporateActions = const [],
    this.summary = const StockDividendsSummaryDto(),
  });

  final List<DistributionPayment> payments;
  final List<DistributionYear> annualSummary;
  final double? ttmPerShare;
  final double? dividendYieldTtm;
  final int? totalPayments;
  final List<StockCorporateActionDto> corporateActions;
  final StockDividendsSummaryDto summary;

  double? get displayDividendYield {
    if (summary.dividendYieldDisplay != null) {
      return summary.dividendYieldDisplay;
    }
    return dividendYieldTtm;
  }

  factory StockDividendsDto.fromJson(Map<String, dynamic> json) {
    final rawPayments = json['payments'] as List<dynamic>? ?? const [];
    final rawSummary = json['annual_summary'] as List<dynamic>? ?? const [];
    final rawActions = json['corporate_actions'] as List<dynamic>? ?? const [];
    final summaryRaw = json['summary'] as Map<String, dynamic>? ?? const {};
    final ttm = json['ttm_per_share'];
    final dy = json['dividend_yield_ttm'];

    return StockDividendsDto(
      payments: rawPayments
          .map((item) => DistributionPayment.fromJson(item as Map<String, dynamic>))
          .toList(),
      annualSummary: rawSummary
          .map((item) => DistributionYear.fromJson(item as Map<String, dynamic>))
          .toList(),
      ttmPerShare: ttm == null ? null : (ttm as num).toDouble(),
      dividendYieldTtm: dy == null ? null : (dy as num).toDouble(),
      totalPayments: json['total_payments'] as int?,
      corporateActions: rawActions
          .map((item) => StockCorporateActionDto.fromJson(item as Map<String, dynamic>))
          .toList(),
      summary: StockDividendsSummaryDto.fromJson(summaryRaw),
    );
  }
}

class StockQuoteDetailDto {
  const StockQuoteDetailDto({
    required this.quote,
    required this.marketStats,
    required this.profile,
    required this.fundamentals,
    required this.candles,
    required this.dividends,
    this.returns = const [],
    this.provider = 'brapi',
  });

  final MarketQuoteDto quote;
  final StockMarketStatsDto marketStats;
  final StockProfileDto profile;
  final StockFundamentalsDto fundamentals;
  final List<QuoteCandleBar> candles;
  final StockDividendsDto dividends;
  final List<GlobalStockReturnPeriodDto> returns;
  final String provider;

  List<DistributionPayment> get payments => dividends.payments;

  factory StockQuoteDetailDto.fromJson(Map<String, dynamic> json) {
    final rawCandles = json['candles'] as List<dynamic>? ?? const [];
    final rawReturns = json['returns'] as List<dynamic>? ?? const [];

    return StockQuoteDetailDto(
      quote: MarketQuoteDto.fromJson(json['quote'] as Map<String, dynamic>),
      marketStats: StockMarketStatsDto.fromJson(
        json['market_stats'] as Map<String, dynamic>? ?? const {},
      ),
      profile: StockProfileDto.fromJson(json['profile'] as Map<String, dynamic>? ?? const {}),
      fundamentals: StockFundamentalsDto.fromJson(
        json['fundamentals'] as Map<String, dynamic>? ?? const {},
      ),
      candles: rawCandles
          .map((item) => QuoteCandleBar.fromJson(item as Map<String, dynamic>))
          .toList(),
      dividends: StockDividendsDto.fromJson(json['dividends'] as Map<String, dynamic>? ?? const {}),
      returns: rawReturns
          .map((e) => GlobalStockReturnPeriodDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      provider: json['provider'] as String? ?? 'brapi',
    );
  }
}

class StockCandlesResponseDto {
  const StockCandlesResponseDto({required this.candles});

  final List<QuoteCandleBar> candles;

  factory StockCandlesResponseDto.fromJson(Map<String, dynamic> json) {
    final raw = json['candles'] as List<dynamic>? ?? const [];
    return StockCandlesResponseDto(
      candles: raw.map((item) => QuoteCandleBar.fromJson(item as Map<String, dynamic>)).toList(),
    );
  }
}
