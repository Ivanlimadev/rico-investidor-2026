import 'package:flutter/material.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/features/quotes/models/stock_quote_detail.dart';

class StockMarketStatsCard extends StatelessWidget {
  const StockMarketStatsCard({super.key, required this.stats});

  final StockMarketStatsDto stats;

  @override
  Widget build(BuildContext context) {
    final items = <_StatItem>[
      _StatItem('Abertura', _money(stats.open)),
      _StatItem('Máxima', _money(stats.dayHigh)),
      _StatItem('Mínima', _money(stats.dayLow)),
      _StatItem('Fech. ant.', _money(stats.previousClose)),
      _StatItem('Volume', _volume(stats.volume)),
      _StatItem('P/L', _number(stats.priceEarnings)),
      _StatItem('LPA', _money(stats.earningsPerShare)),
      _StatItem('Cap. mercado', _marketCap(stats.marketCap)),
      _StatItem('52 sem.', stats.fiftyTwoWeekRange ?? _range(stats)),
    ].where((item) => item.value != null && item.value != '—').toList();

    if (items.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Indicadores', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final item in items)
                  SizedBox(
                    width: 150,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6),
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.value!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _money(double? value) => value == null ? null : formatBrl(value);

  String? _number(double? value) {
    if (value == null) return null;
    return value.toStringAsFixed(2);
  }

  String? _volume(double? value) {
    if (value == null) return null;
    if (value >= 1e9) return '${(value / 1e9).toStringAsFixed(1)} bi';
    if (value >= 1e6) return '${(value / 1e6).toStringAsFixed(1)} mi';
    if (value >= 1e3) return '${(value / 1e3).toStringAsFixed(1)} mil';
    return value.toStringAsFixed(0);
  }

  String? _marketCap(double? value) {
    if (value == null) return null;
    if (value >= 1e12) return 'R\$ ${(value / 1e12).toStringAsFixed(1)} tri';
    if (value >= 1e9) return 'R\$ ${(value / 1e9).toStringAsFixed(1)} bi';
    if (value >= 1e6) return 'R\$ ${(value / 1e6).toStringAsFixed(1)} mi';
    return formatBrl(value);
  }

  String? _range(StockMarketStatsDto stats) {
    if (stats.fiftyTwoWeekLow == null || stats.fiftyTwoWeekHigh == null) return null;
    return '${formatBrl(stats.fiftyTwoWeekLow!)} – ${formatBrl(stats.fiftyTwoWeekHigh!)}';
  }
}

class _StatItem {
  const _StatItem(this.label, this.value);

  final String label;
  final String? value;
}
