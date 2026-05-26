import 'package:rico_investidor/models/portfolio_holding.dart';

class OpenFinanceStatus {
  const OpenFinanceStatus({
    required this.clientUserId,
    required this.linkedItems,
    required this.provider,
    this.itemIds = const [],
  });

  final String clientUserId;
  final int linkedItems;
  final String provider;
  final List<String> itemIds;

  factory OpenFinanceStatus.fromJson(Map<String, dynamic> json) {
    return OpenFinanceStatus(
      clientUserId: json['client_user_id'] as String? ?? '',
      linkedItems: (json['linked_items'] as num?)?.toInt() ?? 0,
      provider: json['provider'] as String? ?? 'pluggy',
      itemIds: (json['item_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

class OpenFinanceImportedHolding {
  const OpenFinanceImportedHolding({
    required this.id,
    required this.symbol,
    required this.name,
    required this.quantity,
    required this.averagePrice,
    required this.currentPrice,
    this.institution,
    this.assetType,
  });

  final String id;
  final String symbol;
  final String name;
  final double quantity;
  final double averagePrice;
  final double currentPrice;
  final String? institution;
  final String? assetType;

  factory OpenFinanceImportedHolding.fromJson(Map<String, dynamic> json) {
    return OpenFinanceImportedHolding(
      id: json['id'] as String? ?? '',
      symbol: json['symbol'] as String? ?? 'ATIVO',
      name: json['name'] as String? ?? 'Investimento',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      averagePrice: (json['average_price'] as num?)?.toDouble() ?? 0,
      currentPrice: (json['current_price'] as num?)?.toDouble() ?? 0,
      institution: json['institution'] as String?,
      assetType: json['asset_type'] as String?,
    );
  }

  PortfolioHolding toPortfolioHolding() {
    return PortfolioHolding(
      id: id,
      symbol: symbol,
      name: name,
      quantity: quantity,
      averagePrice: averagePrice,
      currentPrice: currentPrice,
    );
  }
}

class OpenFinanceSyncResponse {
  const OpenFinanceSyncResponse({
    required this.linkedItems,
    required this.holdings,
    required this.syncedAt,
    required this.provider,
    this.institutions = const [],
  });

  final int linkedItems;
  final List<OpenFinanceImportedHolding> holdings;
  final String syncedAt;
  final String provider;
  final List<String> institutions;

  factory OpenFinanceSyncResponse.fromJson(Map<String, dynamic> json) {
    return OpenFinanceSyncResponse(
      linkedItems: (json['linked_items'] as num?)?.toInt() ?? 0,
      syncedAt: json['synced_at'] as String? ?? '',
      provider: json['provider'] as String? ?? 'pluggy',
      institutions: (json['institutions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      holdings: (json['holdings'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(OpenFinanceImportedHolding.fromJson)
              .toList() ??
          const [],
    );
  }
}
