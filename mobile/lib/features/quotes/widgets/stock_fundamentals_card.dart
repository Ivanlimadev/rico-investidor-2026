import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/features/quotes/models/stock_quote_detail.dart';

class StockFundamentalsCard extends StatelessWidget {
  const StockFundamentalsCard({super.key, required this.fundamentals});

  final StockFundamentalsDto fundamentals;

  @override
  Widget build(BuildContext context) {
    final items = <_FundItem>[
      _FundItem('DY 12m', _pct(fundamentals.dividendYield12m), highlight: true),
      _FundItem('P/L', _num(fundamentals.priceEarnings)),
      _FundItem('P/VP', _num(fundamentals.priceToBook)),
      _FundItem('ROE', _pct(fundamentals.returnOnEquity)),
      _FundItem('ROA', _pct(fundamentals.returnOnAssets)),
      _FundItem('Margem líq.', _pct(fundamentals.profitMargin)),
      _FundItem('Dív./PL', _num(fundamentals.debtToEquity)),
      _FundItem('Payout', _pct(fundamentals.payoutRatio)),
      _FundItem('Beta', _num(fundamentals.beta)),
      _FundItem('VP/cota', _money(fundamentals.bookValuePerShare)),
      _FundItem('LPA', _money(fundamentals.earningsPerShare)),
      _FundItem('Cresc. lucro', _pct(fundamentals.earningsGrowth)),
    ].where((item) => item.value != null).toList();

    if (items.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Fundamentos', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final item in items)
                  _MetricTile(
                    label: item.label,
                    value: item.value!,
                    highlight: item.highlight,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _pct(double? value) {
    if (value == null) return null;
    return '${value.toStringAsFixed(2)}%';
  }

  String? _num(double? value) {
    if (value == null) return null;
    return value.toStringAsFixed(2);
  }

  String? _money(double? value) {
    if (value == null) return null;
    return formatBrl(value);
  }
}

class _FundItem {
  const _FundItem(this.label, this.value, {this.highlight = false});

  final String label;
  final String? value;
  final bool highlight;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
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
      width: 104,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
