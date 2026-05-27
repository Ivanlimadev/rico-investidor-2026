class DividendPayment {
  const DividendPayment({
    required this.id,
    required this.symbol,
    required this.name,
    required this.amount,
    required this.date,
  });

  final String id;
  final String symbol;
  final String name;
  final double amount;
  final DateTime date;

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'name': name,
        'amount': amount,
        'date': date.toIso8601String(),
      };

  factory DividendPayment.fromJson(Map<String, dynamic> json) {
    return DividendPayment(
      id: json['id'] as String,
      symbol: json['symbol'] as String,
      name: json['name'] as String,
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
    );
  }
}

enum DividendChartGranularity { day, month, year }

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
