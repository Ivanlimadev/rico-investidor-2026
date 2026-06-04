import 'package:flutter/material.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/features/quotes/models/stock_quote_detail.dart';

class StockMarketStatsCard extends StatelessWidget {
  const StockMarketStatsCard({
    super.key,
    required this.stats,
    this.useUsd = false,
    this.title = 'Indicadores',
    this.hideValuationMetrics = false,
    this.quotePrice,
    this.quoteAdjClose,
  });

  final StockMarketStatsDto stats;
  final bool useUsd;
  final String title;
  /// Evita duplicar P/L e LPA quando já aparecem no hero / fundamentos.
  final bool hideValuationMetrics;
  final double? quotePrice;
  final double? quoteAdjClose;

  @override
  Widget build(BuildContext context) {
    final rangeLabel = stats.priceRangeLabel ?? '52 sem.';
    final showAdj = quoteAdjClose != null &&
        quotePrice != null &&
        (quoteAdjClose! - quotePrice!).abs() > 0.009;

    final items = <_StatItem>[
      _StatItem('Abertura', _money(stats.open)),
      _StatItem('Máxima', _money(stats.dayHigh)),
      _StatItem('Mínima', _money(stats.dayLow)),
      _StatItem('Fech. ant.', _money(stats.previousClose)),
      if (showAdj) _StatItem('Fech. ajust.', _money(quoteAdjClose)),
      _StatItem('Volume', _volume(stats.volume)),
      _StatItem('Vol. médio 20d', _volume(stats.avgDailyVolume)),
      if (!hideValuationMetrics) _StatItem('P/L', _number(stats.priceEarnings)),
      if (!hideValuationMetrics) _StatItem('LPA', _money(stats.earningsPerShare)),
      _StatItem('Cap. mercado', _marketCap(stats.marketCap)),
      _StatItem(rangeLabel, stats.fiftyTwoWeekRange ?? _range(stats)),
    ].where((item) => item.value != null && item.value != '—').toList();

    if (items.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
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

  String? _money(double? value) => value == null ? null : (useUsd ? formatUsd(value) : formatBrl(value));

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
    if (useUsd) return formatCompactUsd(value);
    if (value >= 1e12) return 'R\$ ${(value / 1e12).toStringAsFixed(1)} tri';
    if (value >= 1e9) return 'R\$ ${(value / 1e9).toStringAsFixed(1)} bi';
    if (value >= 1e6) return 'R\$ ${(value / 1e6).toStringAsFixed(1)} mi';
    return formatBrl(value);
  }

  String? _range(StockMarketStatsDto stats) {
    if (stats.fiftyTwoWeekRange != null && stats.fiftyTwoWeekRange!.isNotEmpty) {
      final parts = stats.fiftyTwoWeekRange!.split(RegExp(r'\s*-\s*')).map((s) => s.trim()).toList();
      if (parts.length == 2) {
        final lo = double.tryParse(parts[0]);
        final hi = double.tryParse(parts[1]);
        if (lo != null && hi != null) {
          return useUsd
              ? '${formatUsd(lo)} – ${formatUsd(hi)}'
              : '${formatBrl(lo)} – ${formatBrl(hi)}';
        }
      }
    }
    if (stats.fiftyTwoWeekLow == null || stats.fiftyTwoWeekHigh == null) return null;
    return useUsd
        ? '${formatUsd(stats.fiftyTwoWeekLow!)} – ${formatUsd(stats.fiftyTwoWeekHigh!)}'
        : '${formatBrl(stats.fiftyTwoWeekLow!)} – ${formatBrl(stats.fiftyTwoWeekHigh!)}';
  }
}

class _StatItem {
  const _StatItem(this.label, this.value);

  final String label;
  final String? value;
}
