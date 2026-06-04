import 'package:flutter/material.dart';
import 'package:rico_investidor/core/widgets/market_heatmap/heatmap_layout.dart';
import 'package:rico_investidor/models/asset_item.dart';

class HeatmapEntry {
  const HeatmapEntry({required this.item, required this.asset});

  final HeatmapTileItem item;
  final AssetItem asset;
}

class MarketHeatmapSection extends StatelessWidget {
  const MarketHeatmapSection({
    super.key,
    required this.entries,
    required this.onTap,
    required this.volumeLabel,
    this.liveChanges = const {},
    this.title = 'Mapa de calor · 24h',
  });

  final List<HeatmapEntry> entries;
  final Map<String, double> liveChanges;
  final ValueChanged<AssetItem> onTap;
  final String volumeLabel;
  final String title;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    final tileItems = entries.map((entry) => entry.item).toList();
    final rows = partitionHeatmapRows(tileItems);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const totalHeight = 248.0;
    final weights = heatmapRowHeightWeights.take(rows.length).toList();
    final weightSum = weights.fold<double>(0, (sum, weight) => sum + weight);

    final rowSlices = <List<HeatmapEntry>>[];
    var offset = 0;
    for (final row in rows) {
      rowSlices.add(entries.sublist(offset, offset + row.length));
      offset += row.length;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                volumeLabel,
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
                  final gapTotal = (rowSlices.length - 1) * rowGap;
                  final rowsHeight = totalHeight - gapTotal;

                  return Column(
                    children: [
                      for (var i = 0; i < rowSlices.length; i++) ...[
                        if (i > 0) const SizedBox(height: rowGap),
                        SizedBox(
                          height: rowsHeight * (weights[i] / weightSum),
                          child: _HeatmapRow(
                            rowEntries: rowSlices[i],
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
    required this.rowEntries,
    required this.liveChanges,
    required this.isDark,
    required this.onTap,
  });

  final List<HeatmapEntry> rowEntries;
  final Map<String, double> liveChanges;
  final bool isDark;
  final ValueChanged<AssetItem> onTap;

  @override
  Widget build(BuildContext context) {
    final totalVolume = rowEntries.fold<double>(0, (sum, entry) => sum + heatmapTileVolume(entry.item));

    return Row(
      children: [
        for (var i = 0; i < rowEntries.length; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          Expanded(
            flex: (heatmapTileVolume(rowEntries[i].item) / totalVolume * 1000).round().clamp(1, 1000),
            child: _HeatmapTile(
              item: rowEntries[i].item,
              changePercent: liveChanges[rowEntries[i].item.symbol] ?? rowEntries[i].item.changePercent,
              isDark: isDark,
              onTap: () => onTap(rowEntries[i].asset),
            ),
          ),
        ],
      ],
    );
  }
}

class _HeatmapTile extends StatelessWidget {
  const _HeatmapTile({
    required this.item,
    required this.changePercent,
    required this.isDark,
    required this.onTap,
  });

  final HeatmapTileItem item;
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
                          item.symbol,
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
