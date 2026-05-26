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
