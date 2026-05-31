import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/features/fii/utils/fii_format.dart';
import 'package:rico_investidor/features/quotes/models/stock_quote_detail.dart';

class GlobalStockFundamentalsCard extends StatelessWidget {
  const GlobalStockFundamentalsCard({super.key, required this.fundamentals});

  final StockFundamentalsDto fundamentals;

  @override
  Widget build(BuildContext context) {
    final items = <(String, String)>[];
    void add(String label, double? value, {bool asPct = false, bool asUsd = false}) {
      if (value == null) return;
      final text = asPct
          ? formatPct(value)
          : asUsd
              ? formatUsd(value)
              : value.toStringAsFixed(2);
      items.add((label, text));
    }

    add('DY 12m', fundamentals.dividendYield12m, asPct: true);
    add('P/L', fundamentals.priceEarnings);
    add('P/VP', fundamentals.priceToBook);
    add('ROE', fundamentals.returnOnEquity, asPct: true);
    add('Margem líq.', fundamentals.profitMargin, asPct: true);
    add('Beta', fundamentals.beta);
    add('EPS', fundamentals.earningsPerShare, asUsd: true);
    add('Receita', fundamentals.totalRevenue, asUsd: true);
    add('EBITDA', fundamentals.ebitda, asUsd: true);
    add('Caixa', fundamentals.totalCash, asUsd: true);
    add('Dívida', fundamentals.totalDebt, asUsd: true);

    if (items.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Fundamentos', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final item in items)
                  _MetricChip(
                    label: item.$1,
                    value: item.$2,
                    highlight: item.$1 == 'DY 12m',
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
    final color = highlight ? AppColors.positive : Theme.of(context).colorScheme.onSurface;
    return Container(
      width: 148,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight ? AppColors.positive.withValues(alpha: 0.25) : Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 4),
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
