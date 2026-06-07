import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/asset_returns.dart';
import 'package:rico_investidor/models/market_series_models.dart';

class AssetReturnsCard extends StatelessWidget {
  const AssetReturnsCard({
    super.key,
    required this.currentPrice,
    this.history = const [],
    this.candles = const [],
    this.payments = const [],
  });

  final double? currentPrice;
  final List<HistoryPricePoint> history;
  final List<QuoteCandleBar> candles;
  final List<DistributionPayment> payments;

  @override
  Widget build(BuildContext context) {
    final items = computeAssetReturns(
      currentPrice: currentPrice,
      history: history,
      candles: candles,
      payments: payments,
    ).where((item) => item.hasData).toList();

    if (items.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Rentabilidade', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final maxW = constraints.maxWidth;
                final columns = items.length >= 4
                    ? 4
                    : items.length >= 3
                        ? 3
                        : items.length;
                const gap = 8.0;
                final chipWidth = (maxW - gap * (columns - 1)) / columns;

                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final item in items)
                      SizedBox(
                        width: chipWidth,
                        child: _ReturnChip(item: item),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ReturnChip extends StatelessWidget {
  const _ReturnChip({required this.item});

  final AssetReturnItem item;

  @override
  Widget build(BuildContext context) {
    final value = item.returnPct!;
    final positive = value >= 0;
    final color = positive ? AppColors.positive : AppColors.negative;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              assetReturnPeriodDisplayLabel(item.label),
              style: Theme.of(context).textTheme.labelSmall,
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
