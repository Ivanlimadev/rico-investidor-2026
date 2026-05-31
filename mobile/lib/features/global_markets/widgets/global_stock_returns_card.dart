import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/asset_returns.dart';
import 'package:rico_investidor/features/global_markets/models/global_market_models.dart';

class GlobalStockReturnsCard extends StatelessWidget {
  const GlobalStockReturnsCard({super.key, required this.returns});

  final List<GlobalStockReturnPeriodDto> returns;

  @override
  Widget build(BuildContext context) {
    if (returns.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Rentabilidade', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.05,
              ),
              itemCount: returns.length,
              itemBuilder: (context, index) => _ReturnChip(item: returns[index]),
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
    final value = item.returnPct;
    final hasValue = value != null;
    final positive = hasValue && value >= 0;
    final color = !hasValue
        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35)
        : positive
            ? AppColors.positive
            : AppColors.negative;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: hasValue ? color.withValues(alpha: 0.1) : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasValue ? color.withValues(alpha: 0.25) : Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            assetReturnPeriodDisplayLabel(item.label),
            style: Theme.of(context).textTheme.labelSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            hasValue ? '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}%' : '—',
            style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
