import 'package:rico_investidor/features/quotes/data/quote_api_client.dart';
import 'package:rico_investidor/models/fii_models.dart';

class StockMarketStatsDto {
  const StockMarketStatsDto({
    this.open,
    this.dayHigh,
    this.dayLow,
    this.previousClose,
    this.volume,
    this.marketCap,
    this.priceEarnings,
    this.earningsPerShare,
    this.fiftyTwoWeekLow,
    this.fiftyTwoWeekHigh,
    this.fiftyTwoWeekRange,
  });

  final double? open;
  final double? dayHigh;
  final double? dayLow;
  final double? previousClose;
  final double? volume;
  final double? marketCap;
  final double? priceEarnings;
  final double? earningsPerShare;
  final double? fiftyTwoWeekLow;
  final double? fiftyTwoWeekHigh;
  final String? fiftyTwoWeekRange;

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
      marketCap: numVal('market_cap'),
      priceEarnings: numVal('price_earnings'),
      earningsPerShare: numVal('earnings_per_share'),
      fiftyTwoWeekLow: numVal('fifty_two_week_low'),
      fiftyTwoWeekHigh: numVal('fifty_two_week_high'),
      fiftyTwoWeekRange: json['fifty_two_week_range'] as String?,
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

class StockDividendsDto {
  const StockDividendsDto({
    required this.payments,
    this.annualSummary = const [],
    this.ttmPerShare,
    this.totalPayments,
    this.corporateActions = const [],
  });

  final List<FiiDistributionPayment> payments;
  final List<FiiDistributionYear> annualSummary;
  final double? ttmPerShare;
  final int? totalPayments;
  final List<StockCorporateActionDto> corporateActions;

  factory StockDividendsDto.fromJson(Map<String, dynamic> json) {
    final rawPayments = json['payments'] as List<dynamic>? ?? const [];
    final rawSummary = json['annual_summary'] as List<dynamic>? ?? const [];
    final rawActions = json['corporate_actions'] as List<dynamic>? ?? const [];
    final ttm = json['ttm_per_share'];

    return StockDividendsDto(
      payments: rawPayments
          .map((item) => FiiDistributionPayment.fromJson(item as Map<String, dynamic>))
          .toList(),
      annualSummary: rawSummary
          .map((item) => FiiDistributionYear.fromJson(item as Map<String, dynamic>))
          .toList(),
      ttmPerShare: ttm == null ? null : (ttm as num).toDouble(),
      totalPayments: json['total_payments'] as int?,
      corporateActions: rawActions
          .map((item) => StockCorporateActionDto.fromJson(item as Map<String, dynamic>))
          .toList(),
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
  });

  final MarketQuoteDto quote;
  final StockMarketStatsDto marketStats;
  final StockProfileDto profile;
  final StockFundamentalsDto fundamentals;
  final List<FiiCandleBar> candles;
  final StockDividendsDto dividends;

  List<FiiDistributionPayment> get payments => dividends.payments;

  factory StockQuoteDetailDto.fromJson(Map<String, dynamic> json) {
    final rawCandles = json['candles'] as List<dynamic>? ?? const [];

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
          .map((item) => FiiCandleBar.fromJson(item as Map<String, dynamic>))
          .toList(),
      dividends: StockDividendsDto.fromJson(json['dividends'] as Map<String, dynamic>? ?? const {}),
    );
  }
}

class StockCandlesResponseDto {
  const StockCandlesResponseDto({required this.candles});

  final List<FiiCandleBar> candles;

  factory StockCandlesResponseDto.fromJson(Map<String, dynamic> json) {
    final raw = json['candles'] as List<dynamic>? ?? const [];
    return StockCandlesResponseDto(
      candles: raw.map((item) => FiiCandleBar.fromJson(item as Map<String, dynamic>)).toList(),
    );
  }
}
