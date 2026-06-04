import 'package:rico_investidor/core/utils/asset_logo_url.dart';
import 'package:rico_investidor/features/quotes/data/quote_api_client.dart';
import 'package:rico_investidor/features/quotes/models/stock_quote_detail.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/market_category.dart';

class ExchangeMarketListResponseDto {
  const ExchangeMarketListResponseDto({
    required this.exchangeMic,
    required this.items,
    required this.count,
    required this.page,
    required this.limit,
    this.exchangeName,
    this.countryCode,
    this.total,
    this.dataMode = 'eod',
    this.provider = 'marketstack',
  });

  final String exchangeMic;
  final String? exchangeName;
  final String? countryCode;
  final List<MarketQuoteDto> items;
  final int count;
  final int? total;
  final int page;
  final int limit;
  final String dataMode;
  final String provider;

  factory ExchangeMarketListResponseDto.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? const [];
    return ExchangeMarketListResponseDto(
      exchangeMic: json['exchange_mic'] as String,
      exchangeName: json['exchange_name'] as String?,
      countryCode: json['country_code'] as String?,
      items: raw.map((e) => MarketQuoteDto.fromJson(e as Map<String, dynamic>)).toList(),
      count: (json['count'] as num?)?.toInt() ?? raw.length,
      total: (json['total'] as num?)?.toInt(),
      page: (json['page'] as num?)?.toInt() ?? 1,
      limit: (json['limit'] as num?)?.toInt() ?? raw.length,
      dataMode: json['data_mode'] as String? ?? 'eod',
      provider: json['provider'] as String? ?? 'marketstack',
    );
  }

  bool get hasMore {
    if (total == null) return items.length >= limit;
    return page * limit < total!;
  }
}

class GlobalMarketCapabilitiesDto {
  const GlobalMarketCapabilitiesDto({
    required this.plan,
    required this.dataMode,
    required this.maxHistoryDays,
    required this.realtimeEnabled,
    required this.fundamentalsEnabled,
    this.monthlyRequestBudget,
    this.provider = 'marketstack',
  });

  final String plan;
  final String dataMode;
  final int maxHistoryDays;
  final bool realtimeEnabled;
  final bool fundamentalsEnabled;
  final int? monthlyRequestBudget;
  final String provider;

  factory GlobalMarketCapabilitiesDto.fromJson(Map<String, dynamic> json) {
    return GlobalMarketCapabilitiesDto(
      plan: json['plan'] as String? ?? 'free',
      dataMode: json['data_mode'] as String? ?? 'eod',
      maxHistoryDays: (json['max_history_days'] as num?)?.toInt() ?? 365,
      realtimeEnabled: json['realtime_enabled'] as bool? ?? false,
      fundamentalsEnabled: json['fundamentals_enabled'] as bool? ?? false,
      monthlyRequestBudget: (json['monthly_request_budget'] as num?)?.toInt(),
      provider: json['provider'] as String? ?? 'marketstack',
    );
  }
}

class ExchangeInfoDto {
  const ExchangeInfoDto({
    required this.mic,
    required this.name,
    this.country,
    this.countryCode,
    this.city,
  });

  final String mic;
  final String name;
  final String? country;
  final String? countryCode;
  final String? city;

  factory ExchangeInfoDto.fromJson(Map<String, dynamic> json) {
    return ExchangeInfoDto(
      mic: json['mic'] as String,
      name: json['name'] as String,
      country: json['country'] as String?,
      countryCode: json['country_code'] as String?,
      city: json['city'] as String?,
    );
  }
}

class CountryExchangesGroupDto {
  const CountryExchangesGroupDto({
    required this.countryCode,
    required this.countryName,
    required this.exchanges,
    required this.exchangeCount,
  });

  final String countryCode;
  final String countryName;
  final List<ExchangeInfoDto> exchanges;
  final int exchangeCount;

  factory CountryExchangesGroupDto.fromJson(Map<String, dynamic> json) {
    final raw = json['exchanges'] as List<dynamic>? ?? const [];
    return CountryExchangesGroupDto(
      countryCode: json['country_code'] as String? ?? '',
      countryName: json['country_name'] as String? ?? '',
      exchanges: raw.map((e) => ExchangeInfoDto.fromJson(e as Map<String, dynamic>)).toList(),
      exchangeCount: (json['exchange_count'] as num?)?.toInt() ?? raw.length,
    );
  }
}

class WorldExchangesResponseDto {
  const WorldExchangesResponseDto({
    required this.priorityCountries,
    required this.otherCountries,
    required this.totalExchanges,
    this.totalCountries = 0,
    this.dataMode = 'eod',
    this.provider = 'marketstack',
  });

  final List<CountryExchangesGroupDto> priorityCountries;
  final List<CountryExchangesGroupDto> otherCountries;
  final int totalExchanges;
  final int totalCountries;
  final String dataMode;
  final String provider;

  factory WorldExchangesResponseDto.fromJson(Map<String, dynamic> json) {
    List<CountryExchangesGroupDto> parseList(String key) {
      final raw = json[key] as List<dynamic>? ?? const [];
      return raw.map((e) => CountryExchangesGroupDto.fromJson(e as Map<String, dynamic>)).toList();
    }

    return WorldExchangesResponseDto(
      priorityCountries: parseList('priority_countries'),
      otherCountries: parseList('other_countries'),
      totalExchanges: (json['total_exchanges'] as num?)?.toInt() ?? 0,
      totalCountries: (json['total_countries'] as num?)?.toInt() ?? 0,
      dataMode: json['data_mode'] as String? ?? 'eod',
      provider: json['provider'] as String? ?? 'marketstack',
    );
  }
}

class CountryHubSectionDto {
  const CountryHubSectionDto({
    required this.id,
    required this.title,
    required this.items,
    required this.count,
    this.subtitle,
  });

  final String id;
  final String title;
  final String? subtitle;
  final List<MarketQuoteDto> items;
  final int count;

  factory CountryHubSectionDto.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? const [];
    return CountryHubSectionDto(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      items: raw.map((e) => MarketQuoteDto.fromJson(e as Map<String, dynamic>)).toList(),
      count: (json['count'] as num?)?.toInt() ?? raw.length,
    );
  }
}

class CountryHubResponseDto {
  const CountryHubResponseDto({
    required this.countryCode,
    required this.countryName,
    required this.sections,
    this.totalMarket,
    this.exchangeCount = 0,
    this.dataMode = 'eod',
    this.provider = 'marketstack',
  });

  final String countryCode;
  final String countryName;
  final List<CountryHubSectionDto> sections;
  final int? totalMarket;
  final int exchangeCount;
  final String dataMode;
  final String provider;

  factory CountryHubResponseDto.fromJson(Map<String, dynamic> json) {
    final raw = json['sections'] as List<dynamic>? ?? const [];
    return CountryHubResponseDto(
      countryCode: json['country_code'] as String? ?? '',
      countryName: json['country_name'] as String? ?? '',
      sections: raw.map((e) => CountryHubSectionDto.fromJson(e as Map<String, dynamic>)).toList(),
      totalMarket: (json['total_market'] as num?)?.toInt(),
      exchangeCount: (json['exchange_count'] as num?)?.toInt() ?? 0,
      dataMode: json['data_mode'] as String? ?? 'eod',
      provider: json['provider'] as String? ?? 'marketstack',
    );
  }
}

class GlobalStockTickerInfoDto {
  const GlobalStockTickerInfoDto({
    required this.symbol,
    required this.name,
    this.country,
    this.hasEod = true,
    this.hasIntraday = false,
    this.exchangeMic,
    this.exchangeName,
    this.exchangeAcronym,
    this.exchangeCity,
    this.exchangeCountryCode,
    this.exchangeWebsite,
    this.isin,
    this.cusip,
  });

  final String symbol;
  final String name;
  final String? country;
  final bool hasEod;
  final bool hasIntraday;
  final String? exchangeMic;
  final String? exchangeName;
  final String? exchangeAcronym;
  final String? exchangeCity;
  final String? exchangeCountryCode;
  final String? exchangeWebsite;
  final String? isin;
  final String? cusip;

  factory GlobalStockTickerInfoDto.fromJson(Map<String, dynamic> json) {
    final symbol = json['symbol'] as String? ?? '';
    return GlobalStockTickerInfoDto(
      symbol: symbol,
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? json['name'] as String
          : symbol,
      country: json['country'] as String?,
      hasEod: json['has_eod'] as bool? ?? true,
      hasIntraday: json['has_intraday'] as bool? ?? false,
      exchangeMic: json['exchange_mic'] as String?,
      exchangeName: json['exchange_name'] as String?,
      exchangeAcronym: json['exchange_acronym'] as String?,
      exchangeCity: json['exchange_city'] as String?,
      exchangeCountryCode: json['exchange_country_code'] as String?,
      exchangeWebsite: json['exchange_website'] as String?,
      isin: json['isin'] as String?,
      cusip: json['cusip'] as String?,
    );
  }
}

class GlobalStockCompanyProfileDto {
  const GlobalStockCompanyProfileDto({
    required this.symbol,
    required this.name,
    this.country,
    this.exchangeMic,
    this.exchangeName,
    this.exchangeAcronym,
    this.exchangeCity,
    this.exchangeCountryCode,
    this.exchangeWebsite,
    this.hasEod = true,
    this.hasIntraday = false,
    this.isin,
    this.cusip,
    this.sector,
    this.industry,
    this.summary,
    this.website,
    this.employees,
  });

  final String symbol;
  final String name;
  final String? country;
  final String? exchangeMic;
  final String? exchangeName;
  final String? exchangeAcronym;
  final String? exchangeCity;
  final String? exchangeCountryCode;
  final String? exchangeWebsite;
  final bool hasEod;
  final bool hasIntraday;
  final String? isin;
  final String? cusip;
  final String? sector;
  final String? industry;
  final String? summary;
  final String? website;
  final int? employees;

  factory GlobalStockCompanyProfileDto.fromJson(Map<String, dynamic> json) {
    return GlobalStockCompanyProfileDto(
      symbol: json['symbol'] as String? ?? '',
      name: json['name'] as String? ?? '',
      country: json['country'] as String?,
      exchangeMic: json['exchange_mic'] as String?,
      exchangeName: json['exchange_name'] as String?,
      exchangeAcronym: json['exchange_acronym'] as String?,
      exchangeCity: json['exchange_city'] as String?,
      exchangeCountryCode: json['exchange_country_code'] as String?,
      exchangeWebsite: json['exchange_website'] as String?,
      hasEod: json['has_eod'] as bool? ?? true,
      hasIntraday: json['has_intraday'] as bool? ?? false,
      isin: json['isin'] as String?,
      cusip: json['cusip'] as String?,
      sector: json['sector'] as String?,
      industry: json['industry'] as String?,
      summary: json['summary'] as String?,
      website: json['website'] as String?,
      employees: (json['employees'] as num?)?.toInt(),
    );
  }
}

class GlobalStockDividendsSummaryDto {
  const GlobalStockDividendsSummaryDto({
    this.ttmPerShare,
    this.dividendYieldTtm,
    this.payments12m = 0,
    this.annualTotals = const [],
    this.upcoming = const [],
    this.nextDividend,
    this.frequencyLabel,
    this.avgAmount12m,
    this.totalPayments = 0,
  });

  final double? ttmPerShare;
  final double? dividendYieldTtm;
  final int payments12m;
  final List<GlobalStockAnnualDividendDto> annualTotals;
  final List<GlobalStockDividendDto> upcoming;
  final GlobalStockDividendDto? nextDividend;
  final String? frequencyLabel;
  final double? avgAmount12m;
  final int totalPayments;

  factory GlobalStockDividendsSummaryDto.fromJson(Map<String, dynamic> json) {
    final annualRaw = json['annual_totals'] as List<dynamic>? ?? const [];
    final upcomingRaw = json['upcoming'] as List<dynamic>? ?? const [];
    final nextRaw = json['next_dividend'] as Map<String, dynamic>?;
    return GlobalStockDividendsSummaryDto(
      ttmPerShare: (json['ttm_per_share'] as num?)?.toDouble(),
      dividendYieldTtm: (json['dividend_yield_ttm'] as num?)?.toDouble(),
      payments12m: (json['payments_12m'] as num?)?.toInt() ?? 0,
      annualTotals: annualRaw
          .map((e) => GlobalStockAnnualDividendDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      upcoming: upcomingRaw
          .map((e) => GlobalStockDividendDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextDividend: nextRaw == null ? null : GlobalStockDividendDto.fromJson(nextRaw),
      frequencyLabel: json['frequency_label'] as String?,
      avgAmount12m: (json['avg_amount_12m'] as num?)?.toDouble(),
      totalPayments: (json['total_payments'] as num?)?.toInt() ?? 0,
    );
  }
}

class GlobalStockAnnualDividendDto {
  const GlobalStockAnnualDividendDto({required this.year, required this.total});

  final int year;
  final double total;

  factory GlobalStockAnnualDividendDto.fromJson(Map<String, dynamic> json) {
    return GlobalStockAnnualDividendDto(
      year: (json['year'] as num).toInt(),
      total: (json['total'] as num).toDouble(),
    );
  }
}

class GlobalStockReturnPeriodDto {
  const GlobalStockReturnPeriodDto({
    required this.label,
    required this.monthsBack,
    this.returnPct,
  });

  final String label;
  final int monthsBack;
  final double? returnPct;

  factory GlobalStockReturnPeriodDto.fromJson(Map<String, dynamic> json) {
    return GlobalStockReturnPeriodDto(
      label: json['label'] as String? ?? '',
      monthsBack: (json['months_back'] as num?)?.toInt() ?? 0,
      returnPct: (json['return_pct'] as num?)?.toDouble(),
    );
  }
}

class GlobalStockDividendDto {
  const GlobalStockDividendDto({
    required this.date,
    required this.amount,
    this.exDate,
    this.comDate,
    this.recordDate,
    this.paymentDate,
    this.declarationDate,
    this.frequency,
    this.dividendType = 'Dividendo',
    this.isProjected = false,
  });

  final String date;
  final double amount;
  final String? exDate;
  final String? comDate;
  final String? recordDate;
  final String? paymentDate;
  final String? declarationDate;
  final String? frequency;
  final String dividendType;
  final bool isProjected;

  String get effectiveExDate => exDate ?? date;
  String? get effectiveComDate => comDate ?? effectiveRecordDate ?? effectiveExDate;
  String? get effectiveRecordDate => recordDate ?? exDate ?? date;
  String? get effectivePaymentDate => paymentDate;

  factory GlobalStockDividendDto.fromJson(Map<String, dynamic> json) {
    return GlobalStockDividendDto(
      date: json['date'] as String,
      amount: (json['amount'] as num).toDouble(),
      exDate: json['ex_date'] as String?,
      comDate: json['com_date'] as String?,
      recordDate: json['record_date'] as String?,
      paymentDate: json['payment_date'] as String?,
      declarationDate: json['declaration_date'] as String?,
      frequency: json['frequency'] as String?,
      dividendType: json['dividend_type'] as String? ?? 'Dividendo',
      isProjected: json['is_projected'] as bool? ?? false,
    );
  }
}

class GlobalStockSplitDto {
  const GlobalStockSplitDto({required this.date, required this.splitFactor});

  final String date;
  final double splitFactor;

  factory GlobalStockSplitDto.fromJson(Map<String, dynamic> json) {
    return GlobalStockSplitDto(
      date: json['date'] as String,
      splitFactor: (json['split_factor'] as num).toDouble(),
    );
  }
}

class GlobalStockDetailResponseDto {
  const GlobalStockDetailResponseDto({
    required this.quote,
    required this.ticker,
    required this.company,
    required this.candles,
    required this.dividends,
    required this.splits,
    required this.dividendsSummary,
    required this.returns,
    required this.fundamentals,
    required this.marketStats,
    required this.dataMode,
    required this.plan,
    required this.historyLimited,
    required this.maxHistoryDays,
    this.candlesCount = 0,
    this.dividendsTotal = 0,
    this.splitsTotal = 0,
    this.provider = 'marketstack',
  });

  final MarketQuoteDto quote;
  final GlobalStockTickerInfoDto ticker;
  final GlobalStockCompanyProfileDto company;
  final List<GlobalStockCandleDto> candles;
  final List<GlobalStockDividendDto> dividends;
  final List<GlobalStockSplitDto> splits;
  final GlobalStockDividendsSummaryDto dividendsSummary;
  final List<GlobalStockReturnPeriodDto> returns;
  final StockFundamentalsDto fundamentals;
  final StockMarketStatsDto marketStats;
  final int candlesCount;
  final int dividendsTotal;
  final int splitsTotal;
  final String dataMode;
  final String plan;
  final bool historyLimited;
  final int maxHistoryDays;
  final String provider;

  factory GlobalStockDetailResponseDto.fromJson(Map<String, dynamic> json) {
    final quoteRaw = json['quote'] as Map<String, dynamic>? ?? const {};
    final tickerRaw = json['ticker'] as Map<String, dynamic>? ?? const {};
    final companyRaw = json['company'] as Map<String, dynamic>? ?? tickerRaw;
    final candlesRaw = json['candles'] as List<dynamic>? ?? const [];
    final dividendsRaw = json['dividends'] as List<dynamic>? ?? const [];
    final splitsRaw = json['splits'] as List<dynamic>? ?? const [];
    final returnsRaw = json['returns'] as List<dynamic>? ?? const [];
    final summaryRaw = json['dividends_summary'] as Map<String, dynamic>? ?? const {};

    return GlobalStockDetailResponseDto(
      quote: MarketQuoteDto.fromJson(quoteRaw),
      ticker: GlobalStockTickerInfoDto.fromJson(tickerRaw),
      company: GlobalStockCompanyProfileDto.fromJson(companyRaw),
      candles: candlesRaw.map((e) => GlobalStockCandleDto.fromJson(e as Map<String, dynamic>)).toList(),
      dividends: dividendsRaw.map((e) => GlobalStockDividendDto.fromJson(e as Map<String, dynamic>)).toList(),
      splits: splitsRaw.map((e) => GlobalStockSplitDto.fromJson(e as Map<String, dynamic>)).toList(),
      dividendsSummary: GlobalStockDividendsSummaryDto.fromJson(summaryRaw),
      returns: returnsRaw.map((e) => GlobalStockReturnPeriodDto.fromJson(e as Map<String, dynamic>)).toList(),
      fundamentals: StockFundamentalsDto.fromJson(
        json['fundamentals'] as Map<String, dynamic>? ?? const {},
      ),
      marketStats: StockMarketStatsDto.fromJson(
        json['market_stats'] as Map<String, dynamic>? ?? const {},
      ),
      candlesCount: (json['candles_count'] as num?)?.toInt() ?? candlesRaw.length,
      dividendsTotal: (json['dividends_total'] as num?)?.toInt() ?? dividendsRaw.length,
      splitsTotal: (json['splits_total'] as num?)?.toInt() ?? splitsRaw.length,
      dataMode: json['data_mode'] as String? ?? 'eod',
      plan: json['plan'] as String? ?? 'basic',
      historyLimited: json['history_limited'] as bool? ?? false,
      maxHistoryDays: (json['max_history_days'] as num?)?.toInt() ?? 365,
      provider: json['provider'] as String? ?? 'marketstack',
    );
  }
}

class GlobalStockCandleDto {
  const GlobalStockCandleDto({
    required this.date,
    required this.close,
    this.open,
    this.high,
    this.low,
    this.adjClose,
    this.volume,
  });

  final String date;
  final double close;
  final double? open;
  final double? high;
  final double? low;
  final double? adjClose;
  final double? volume;

  double get chartClose => adjClose ?? close;

  factory GlobalStockCandleDto.fromJson(Map<String, dynamic> json) {
    double? numVal(String key) {
      final value = json[key];
      if (value == null) return null;
      return (value as num).toDouble();
    }

    return GlobalStockCandleDto(
      date: json['date'] as String? ?? '',
      close: (json['close'] as num).toDouble(),
      open: numVal('open'),
      high: numVal('high'),
      low: numVal('low'),
      adjClose: numVal('adj_close'),
      volume: numVal('volume'),
    );
  }
}

class GlobalStockCandlesResponseDto {
  const GlobalStockCandlesResponseDto({
    required this.symbol,
    required this.candles,
    required this.count,
    this.exchange,
    this.historyLimited = false,
    this.maxHistoryDays = 365,
    this.dataMode = 'eod',
  });

  final String symbol;
  final String? exchange;
  final List<GlobalStockCandleDto> candles;
  final int count;
  final bool historyLimited;
  final int maxHistoryDays;
  final String dataMode;

  factory GlobalStockCandlesResponseDto.fromJson(Map<String, dynamic> json) {
    final raw = json['candles'] as List<dynamic>? ?? const [];
    return GlobalStockCandlesResponseDto(
      symbol: json['symbol'] as String,
      exchange: json['exchange'] as String?,
      candles: raw.map((e) => GlobalStockCandleDto.fromJson(e as Map<String, dynamic>)).toList(),
      count: (json['count'] as num?)?.toInt() ?? raw.length,
      historyLimited: json['history_limited'] as bool? ?? false,
      maxHistoryDays: (json['max_history_days'] as num?)?.toInt() ?? 365,
      dataMode: json['data_mode'] as String? ?? 'eod',
    );
  }
}

extension GlobalMarketQuoteMapper on MarketQuoteDto {
  AssetItem toUsAssetItem({MarketCategory category = MarketCategory.stocks}) {
    final resolvedLogo = provider == 'marketstack'
        ? globalMarketLogoApiUrl(symbol)
        : resolveAssetLogoUrl(symbol, logoUrl, isFii: false);

    return AssetItem(
      symbol: symbol,
      name: name,
      category: category,
      price: price,
      changePercent: changePercent,
      logoUrl: resolvedLogo,
      exchangeMic: exchange,
      sparkline: sparkline,
    );
  }
}
