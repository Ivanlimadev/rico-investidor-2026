import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/asset_returns.dart';
import 'package:rico_investidor/features/global_markets/models/global_market_models.dart';

class GlobalStockReturnsCard extends StatelessWidget {
  const GlobalStockReturnsCard({super.key, required this.returns});

  final List<GlobalStockReturnPeriodDto> returns;

  @override
  Widget build(BuildContext context) {
    final visible = returns.where((item) => item.returnPct != null).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

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
                final columns = visible.length >= 4
                    ? 4
                    : visible.length >= 3
                        ? 3
                        : visible.length;
                const gap = 8.0;
                final chipWidth = (maxW - gap * (columns - 1)) / columns;

                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final item in visible)
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

  final GlobalStockReturnPeriodDto item;

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
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
