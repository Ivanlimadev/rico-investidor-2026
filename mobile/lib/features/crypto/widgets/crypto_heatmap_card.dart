import 'package:flutter/material.dart';
import 'package:rico_investidor/core/widgets/market_heatmap/heatmap_layout.dart';
import 'package:rico_investidor/core/widgets/market_heatmap/market_heatmap_section.dart';
import 'package:rico_investidor/features/crypto/models/crypto_models.dart';
import 'package:rico_investidor/models/asset_item.dart';

class CryptoHeatmapSection extends StatelessWidget {
  const CryptoHeatmapSection({
    super.key,
    required this.items,
    required this.onTap,
    this.liveChanges = const {},
  });

  final List<CryptoQuoteDto> items;
  final Map<String, double> liveChanges;
  final ValueChanged<AssetItem> onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final entries = items
        .map(
          (quote) => HeatmapEntry(
            item: HeatmapTileItem(
              symbol: quote.symbol,
              changePercent: quote.changePercent,
              volume: quote.volume,
            ),
            asset: quote.toAssetItem(),
          ),
        )
        .toList();

    return MarketHeatmapSection(
      entries: entries,
      liveChanges: liveChanges,
      onTap: onTap,
      volumeLabel: 'Volume USDT',
    );
  }
}
