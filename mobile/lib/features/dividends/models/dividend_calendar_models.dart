class DividendCalendarEntry {
  const DividendCalendarEntry({
    required this.market,
    required this.symbol,
    required this.companyName,
    required this.dividendType,
    required this.comDate,
    this.paymentDate,
    required this.amount,
    required this.currency,
    this.exchange,
  });

  final String market;
  final String symbol;
  final String companyName;
  final String dividendType;
  final String comDate;
  final String? paymentDate;
  final double amount;
  final String currency;
  final String? exchange;

  factory DividendCalendarEntry.fromJson(Map<String, dynamic> json) {
    return DividendCalendarEntry(
      market: json['market'] as String? ?? 'br',
      symbol: (json['symbol'] as String? ?? '').toUpperCase(),
      companyName: json['company_name'] as String? ?? '',
      dividendType: json['dividend_type'] as String? ?? 'Dividendo',
      comDate: json['com_date'] as String? ?? '',
      paymentDate: json['payment_date'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'BRL',
      exchange: json['exchange'] as String?,
    );
  }
}

class DividendCalendarResponse {
  const DividendCalendarResponse({
    required this.market,
    required this.sortBy,
    required this.items,
    this.dataSources = const [],
  });

  final String market;
  final String sortBy;
  final List<DividendCalendarEntry> items;
  final List<String> dataSources;

  factory DividendCalendarResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? const [];
    final sources = json['data_sources'] as List<dynamic>? ?? const [];
    return DividendCalendarResponse(
      market: json['market'] as String? ?? 'br',
      sortBy: json['sort_by'] as String? ?? 'payment',
      dataSources: sources.whereType<String>().toList(),
      items: raw
          .whereType<Map<String, dynamic>>()
          .map(DividendCalendarEntry.fromJson)
          .toList(),
    );
  }
}
