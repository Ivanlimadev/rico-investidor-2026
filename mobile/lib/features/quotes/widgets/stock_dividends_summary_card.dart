import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/features/quotes/models/stock_quote_detail.dart';

class StockDividendsSummaryCard extends StatelessWidget {
  const StockDividendsSummaryCard({
    super.key,
    required this.dividends,
    this.dividendYield12m,
  });

  final StockDividendsDto dividends;
  final double? dividendYield12m;

  @override
  Widget build(BuildContext context) {
    if (dividends.payments.isEmpty) return const SizedBox.shrink();

    final dy = dividendYield12m ?? dividends.dividendYieldTtm;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Proventos', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (dy != null)
                  _MetricChip(
                    label: 'DY 12m',
                    value: '${dy.toStringAsFixed(2)}%',
                    highlight: true,
                  ),
                if (dividends.ttmPerShare != null)
                  _MetricChip(
                    label: 'Total 12m',
                    value: formatBrl(dividends.ttmPerShare!),
                  ),
                if (dividends.totalPayments != null)
                  _MetricChip(
                    label: 'Pagamentos',
                    value: '${dividends.totalPayments}',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight ? AppColors.positive : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.positive.withValues(alpha: 0.1)
            : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        border: highlight ? Border.all(color: AppColors.positive.withValues(alpha: 0.25)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}
