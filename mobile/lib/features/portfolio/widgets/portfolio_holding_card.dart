import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/core/widgets/asset_card_header.dart';
import 'package:rico_investidor/models/portfolio_holding.dart';

class PortfolioHoldingCard extends StatelessWidget {
  const PortfolioHoldingCard({
    super.key,
    required this.holding,
    this.onTap,
    this.showDayChange = false,
  });

  final PortfolioHolding holding;
  final VoidCallback? onTap;
  final bool showDayChange;

  @override
  Widget build(BuildContext context) {
    final profitColor = holding.profit >= 0 ? AppColors.positive : AppColors.negative;
    final dayColor = holding.changePercent >= 0 ? AppColors.positive : AppColors.negative;
    final quantityLabel = holding.quantity.toStringAsFixed(
      holding.quantity.truncateToDouble() == holding.quantity ? 0 : 2,
    );

    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AssetCardHeader(
            symbol: holding.symbol,
            name: holding.name,
            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatBrl(holding.marketValue),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
                if (showDayChange && holding.changePercent != 0)
                  Text(
                    '${holding.changePercent >= 0 ? '+' : ''}${holding.changePercent.toStringAsFixed(2)}% hoje',
                    style: TextStyle(color: dayColor, fontWeight: FontWeight.w600, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(label: 'Qtd', value: quantityLabel),
                    _InfoChip(label: 'PM', value: formatBrl(holding.averagePrice)),
                    _InfoChip(label: 'Atual', value: formatBrl(holding.currentPrice)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${holding.profit >= 0 ? '+' : ''}${holding.profitPercent.toStringAsFixed(2)}%',
                style: TextStyle(color: profitColor, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );

    if (onTap == null) {
      return Card(child: content);
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: content),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.bodySmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
