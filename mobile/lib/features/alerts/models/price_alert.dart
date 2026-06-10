class PriceAlert {
  const PriceAlert({
    required this.id,
    required this.symbol,
    required this.category,
    required this.direction,
    required this.targetPrice,
    required this.enabled,
  });

  final String id;
  final String symbol;
  final String category;
  final String direction;
  final double targetPrice;
  final bool enabled;

  factory PriceAlert.fromJson(Map<String, dynamic> json) {
    return PriceAlert(
      id: json['id'] as String,
      symbol: json['symbol'] as String,
      category: json['category'] as String? ?? 'stocks',
      direction: json['direction'] as String,
      targetPrice: (json['target_price'] as num).toDouble(),
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}

class PriceAlertListResponse {
  const PriceAlertListResponse({required this.items, required this.count});

  final List<PriceAlert> items;
  final int count;

  factory PriceAlertListResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? const [];
    return PriceAlertListResponse(
      items: raw.map((e) => PriceAlert.fromJson(e as Map<String, dynamic>)).toList(),
      count: json['count'] as int? ?? raw.length,
    );
  }
}
