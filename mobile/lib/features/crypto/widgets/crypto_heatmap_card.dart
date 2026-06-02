import 'package:flutter/material.dart';
import 'package:rico_investidor/features/crypto/models/crypto_models.dart';
import 'package:rico_investidor/features/crypto/utils/crypto_heatmap_layout.dart';
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

    final rows = partitionHeatmapRows(items);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const totalHeight = 248.0;
    final weights = heatmapRowHeightWeights.take(rows.length).toList();
    final weightSum = weights.fold<double>(0, (sum, weight) => sum + weight);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Mapa de calor · 24h',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                'Volume USDT',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: totalHeight,
              child: Builder(
                builder: (context) {
                  const rowGap = 3.0;
                  final gapTotal = (rows.length - 1) * rowGap;
                  final rowsHeight = totalHeight - gapTotal;

                  return Column(
                    children: [
                      for (var i = 0; i < rows.length; i++) ...[
                        if (i > 0) const SizedBox(height: rowGap),
                        SizedBox(
                          height: rowsHeight * (weights[i] / weightSum),
                          child: _HeatmapRow(
                            items: rows[i],
                            liveChanges: liveChanges,
                            isDark: isDark,
                            onTap: onTap,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeatmapRow extends StatelessWidget {
  const _HeatmapRow({
    required this.items,
    required this.liveChanges,
    required this.isDark,
    required this.onTap,
  });

  final List<CryptoQuoteDto> items;
  final Map<String, double> liveChanges;
  final bool isDark;
  final ValueChanged<AssetItem> onTap;

  @override
  Widget build(BuildContext context) {
    final totalVolume = items.fold<double>(0, (sum, item) => sum + heatmapTileVolume(item));

    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          Expanded(
            flex: (heatmapTileVolume(items[i]) / totalVolume * 1000).round().clamp(1, 1000),
            child: _HeatmapTile(
              quote: items[i],
              changePercent: liveChanges[items[i].symbol] ?? items[i].changePercent,
              isDark: isDark,
              onTap: () => onTap(items[i].toAssetItem()),
            ),
          ),
        ],
      ],
    );
  }
}

class _HeatmapTile extends StatelessWidget {
  const _HeatmapTile({
    required this.quote,
    required this.changePercent,
    required this.isDark,
    required this.onTap,
  });

  final CryptoQuoteDto quote;
  final double changePercent;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = heatmapChangeColor(changePercent, isDark: isDark);
    final labelColor = heatmapLabelColor(changePercent, isDark: isDark);
    final changeText = '${changePercent >= 0 ? '+' : ''}${changePercent.toStringAsFixed(2)}%';

    return Material(
      color: background,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 54 || constraints.maxWidth < 52;
              final symbolSize = compact ? 11.0 : 13.0;
              final changeSize = compact ? 10.0 : 11.5;

              return Align(
                alignment: Alignment.topLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth > 0 ? constraints.maxWidth : double.infinity,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          quote.symbol,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: labelColor,
                            fontWeight: FontWeight.w800,
                            fontSize: symbolSize,
                            height: 1.1,
                            letterSpacing: 0.2,
                          ),
                        ),
                        SizedBox(height: compact ? 1 : 3),
                        Text(
                          changeText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: labelColor.withValues(alpha: 0.95),
                            fontWeight: FontWeight.w700,
                            fontSize: changeSize,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
