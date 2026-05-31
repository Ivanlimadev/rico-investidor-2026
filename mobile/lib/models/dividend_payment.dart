class DividendPayment {
  const DividendPayment({
    required this.id,
    required this.symbol,
    required this.name,
    required this.amount,
    required this.date,
    this.kind,
    this.amountPerShare,
  });

  final String id;
  final String symbol;
  final String name;
  final double amount;
  final DateTime date;
  final String? kind;
  final double? amountPerShare;

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'name': name,
        'amount': amount,
        'date': date.toIso8601String(),
        if (kind != null) 'kind': kind,
        if (amountPerShare != null) 'amount_per_share': amountPerShare,
      };

  factory DividendPayment.fromJson(Map<String, dynamic> json) {
    return DividendPayment(
      id: json['id'] as String,
      symbol: json['symbol'] as String,
      name: json['name'] as String,
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      kind: json['kind'] as String?,
      amountPerShare: (json['amount_per_share'] as num?)?.toDouble(),
    );
  }
}

enum DividendChartGranularity { month, year }

class DividendChartPoint {
  const DividendChartPoint({
    required this.label,
    required this.total,
    required this.periodStart,
  });

  final String label;
  final double total;
  final DateTime periodStart;
}
