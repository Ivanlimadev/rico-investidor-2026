import 'package:flutter/material.dart';
import 'package:rico_investidor/features/global_markets/models/global_market_models.dart';

class GlobalStockSplitsCard extends StatelessWidget {
  const GlobalStockSplitsCard({super.key, required this.splits, required this.total});

  final List<GlobalStockSplitDto> splits;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (splits.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Desdobramentos',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (total > splits.length)
                  Text('${splits.length} de $total', style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
            const SizedBox(height: 8),
            ...splits.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(_formatDate(item.date))),
                    Text(
                      '${item.splitFactor.toStringAsFixed(4)}x',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(String raw) {
    if (raw.length >= 10) return raw.substring(0, 10);
    return raw;
  }
}
