class DividendPayment {
  const DividendPayment({
    required this.id,
    required this.symbol,
    required this.name,
    required this.amount,
    required this.date,
    this.kind,
    this.amountPerShare,
    this.comDate,
    this.quantity,
    this.isProjected = false,
  });

  final String id;
  final String symbol;
  final String name;
  final double amount;
  /// Data de pagamento (ou melhor referência disponível).
  final DateTime date;
  final String? kind;
  final double? amountPerShare;
  final DateTime? comDate;
  final double? quantity;
  final bool isProjected;

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'name': name,
        'amount': amount,
        'date': date.toIso8601String(),
        if (kind != null) 'kind': kind,
        if (amountPerShare != null) 'amount_per_share': amountPerShare,
        if (comDate != null) 'com_date': comDate!.toIso8601String(),
        if (quantity != null) 'quantity': quantity,
        if (isProjected) 'is_projected': isProjected,
      };

  factory DividendPayment.fromJson(Map<String, dynamic> json) {
    final comRaw = json['com_date'] as String?;
    return DividendPayment(
      id: json['id'] as String,
      symbol: json['symbol'] as String,
      name: json['name'] as String,
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      kind: json['kind'] as String?,
      amountPerShare: (json['amount_per_share'] as num?)?.toDouble(),
      comDate: comRaw == null ? null : DateTime.tryParse(comRaw),
      quantity: (json['quantity'] as num?)?.toDouble(),
      isProjected: json['is_projected'] as bool? ?? false,
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
