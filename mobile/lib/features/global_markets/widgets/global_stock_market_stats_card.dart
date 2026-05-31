import 'package:flutter/material.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/features/quotes/data/quote_api_client.dart';

class GlobalStockMarketStatsCard extends StatelessWidget {
  const GlobalStockMarketStatsCard({super.key, required this.meta});

  final MarketQuoteDto meta;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pregão',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _Stat(label: 'Abertura', value: _usd(meta.open))),
                Expanded(child: _Stat(label: 'Máxima', value: _usd(meta.high))),
                Expanded(child: _Stat(label: 'Mínima', value: _usd(meta.low))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _Stat(label: 'Fech. ant.', value: _usd(meta.previousClose))),
                Expanded(child: _Stat(label: 'Ajustado', value: _usd(meta.adjClose))),
                Expanded(child: _Stat(label: 'Volume', value: _volume(meta.volume))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String? _usd(double? value) {
    if (value == null) return null;
    return formatUsd(value);
  }

  static String? _volume(double? value) {
    if (value == null) return null;
    if (value >= 1e9) return '${(value / 1e9).toStringAsFixed(2)}B';
    if (value >= 1e6) return '${(value / 1e6).toStringAsFixed(2)}M';
    if (value >= 1e3) return '${(value / 1e3).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        Text(
          value ?? '—',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
