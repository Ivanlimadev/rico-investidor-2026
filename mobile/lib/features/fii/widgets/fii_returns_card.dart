import 'package:rico_investidor/core/widgets/asset_returns_card.dart';

/// Alias mantido para compatibilidade com telas de FII.
class FiiReturnsCard extends AssetReturnsCard {
  const FiiReturnsCard({
    super.key,
    required super.currentPrice,
    super.history = const [],
    super.candles = const [],
    super.payments = const [],
  });
}
