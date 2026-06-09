import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/widgets/asset_card_header.dart';
import 'package:rico_investidor/models/holding_currency.dart';
import 'package:rico_investidor/models/portfolio_holding.dart';

class PortfolioHoldingCard extends StatelessWidget {
  const PortfolioHoldingCard({
    super.key,
    required this.holding,
    this.onTap,
    this.onDelete,
    this.onViewHistory,
    this.showDayChange = false,
  });

  final PortfolioHolding holding;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onViewHistory;
  final bool showDayChange;

  static const _logoSize = 32.0;

  @override
  Widget build(BuildContext context) {
    final profitColor = holding.profit >= 0 ? AppColors.positive : AppColors.negative;
    final dayColor = holding.changePercent >= 0 ? AppColors.positive : AppColors.negative;
    final quantityLabel = holding.quantity.toStringAsFixed(
      holding.quantity.truncateToDouble() == holding.quantity ? 0 : 2,
    );

    final currency = resolvedHoldingCurrency(holding, category: holding.category);

    final content = Padding(
      padding: EdgeInsets.fromLTRB(12, 10, onDelete != null ? 4 : 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AssetCardHeader(
            symbol: holding.symbol,
            name: holding.name,
            logoSize: _logoSize,
            nameMaxLines: 1,
            useTickerBadge: true,
            trailing: _HeaderTrailing(
              marketValue: currency.format(holding.marketValue),
              dayChange: showDayChange && holding.changePercent != 0
                  ? '${holding.changePercent >= 0 ? '+' : ''}${holding.changePercent.toStringAsFixed(2)}% today'
                  : null,
              dayColor: dayColor,
              onDelete: onDelete,
              onViewHistory: onViewHistory,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _InfoChip(label: 'Qtd', value: quantityLabel),
                    _InfoChip(label: 'PM', value: currency.format(holding.averagePrice)),
                    _InfoChip(label: 'Atual', value: currency.format(holding.currentPrice)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${holding.profit >= 0 ? '+' : ''}${holding.profitPercent.toStringAsFixed(2)}%',
                style: TextStyle(
                  color: profitColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: onTap == null
          ? content
          : InkWell(onTap: onTap, child: content),
    );
  }
}

class _HeaderTrailing extends StatelessWidget {
  const _HeaderTrailing({
    required this.marketValue,
    required this.dayColor,
    this.dayChange,
    this.onDelete,
    this.onViewHistory,
  });

  final String marketValue;
  final String? dayChange;
  final Color dayColor;
  final VoidCallback? onDelete;
  final VoidCallback? onViewHistory;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Position',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                    fontSize: 10,
                  ),
            ),
            Text(
              marketValue,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
            if (dayChange != null)
              Text(
                dayChange!,
                style: TextStyle(
                  color: dayColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 10.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
              ),
          ],
        ),
        if (onViewHistory != null)
          IconButton(
            onPressed: onViewHistory,
            tooltip: 'Transaction history',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: Icon(
              Icons.history_outlined,
              size: 18,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.78),
            ),
          ),
        if (onDelete != null)
          IconButton(
            onPressed: onDelete,
            tooltip: 'Remove asset',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: Icon(
              Icons.delete_outline,
              size: 18,
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.78),
            ),
          ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
