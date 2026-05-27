class FundamentalHistoryPeriodDto {
  const FundamentalHistoryPeriodDto({
    required this.endDate,
    this.totalRevenue,
    this.netIncome,
    this.ebitda,
    this.freeCashflow,
    this.profitMargin,
    this.returnOnEquity,
    this.dividendYield12m,
    this.priceEarnings,
    this.priceToBook,
  });

  final String endDate;
  final double? totalRevenue;
  final double? netIncome;
  final double? ebitda;
  final double? freeCashflow;
  final double? profitMargin;
  final double? returnOnEquity;
  final double? dividendYield12m;
  final double? priceEarnings;
  final double? priceToBook;

  factory FundamentalHistoryPeriodDto.fromJson(Map<String, dynamic> json) {
    double? numVal(String key) {
      final value = json[key];
      if (value == null) return null;
      return (value as num).toDouble();
    }

    return FundamentalHistoryPeriodDto(
      endDate: json['end_date'] as String,
      totalRevenue: numVal('total_revenue'),
      netIncome: numVal('net_income'),
      ebitda: numVal('ebitda'),
      freeCashflow: numVal('free_cashflow'),
      profitMargin: numVal('profit_margin'),
      returnOnEquity: numVal('return_on_equity'),
      dividendYield12m: numVal('dividend_yield_12m'),
      priceEarnings: numVal('price_earnings'),
      priceToBook: numVal('price_to_book'),
    );
  }
}

class StockFundamentalHistoryDto {
  const StockFundamentalHistoryDto({
    required this.ticker,
    required this.periods,
    required this.count,
    this.provider = 'brapi',
  });

  final String ticker;
  final List<FundamentalHistoryPeriodDto> periods;
  final int count;
  final String provider;

  bool get isEmpty => periods.isEmpty;

  factory StockFundamentalHistoryDto.fromJson(Map<String, dynamic> json) {
    final raw = json['periods'] as List<dynamic>? ?? const [];
    return StockFundamentalHistoryDto(
      ticker: json['ticker'] as String,
      periods: raw
          .map((item) => FundamentalHistoryPeriodDto.fromJson(item as Map<String, dynamic>))
          .toList(),
      count: json['count'] as int? ?? raw.length,
      provider: json['provider'] as String? ?? 'brapi',
    );
  }
}

String formatFundamentalPeriodLabel(String endDate) {
  final date = DateTime.tryParse(endDate);
  if (date == null) return endDate;
  final quarter = ((date.month - 1) ~/ 3) + 1;
  final year = date.year.toString().substring(2);
  return '${quarter}T$year';
}
