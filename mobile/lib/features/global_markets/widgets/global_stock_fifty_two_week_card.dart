import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/features/quotes/models/stock_quote_detail.dart';

/// Faixa de 52 semanas com marcador do preço atual (estilo Investidor10).
class GlobalStockFiftyTwoWeekCard extends StatelessWidget {
  const GlobalStockFiftyTwoWeekCard({
    super.key,
    required this.stats,
    required this.currentPrice,
    this.title = 'Faixa 52 semanas',
  });

  final StockMarketStatsDto stats;
  final double currentPrice;
  final String title;

  @override
  Widget build(BuildContext context) {
    final low = stats.fiftyTwoWeekLow;
    final high = stats.fiftyTwoWeekHigh;
    if (low == null || high == null || high <= low || currentPrice <= 0) {
      return const SizedBox.shrink();
    }

    final span = high - low;
    final position = ((currentPrice - low) / span).clamp(0.0, 1.0);
    final inRange = currentPrice >= low && currentPrice <= high;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formatUsd(low),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Text(
                  formatUsd(high),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final trackW = constraints.maxWidth;
                const thumb = 10.0;
                final x = position * (trackW - thumb);

                return SizedBox(
                  height: 28,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 9,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: position,
                            minHeight: 8,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            color: AppColors.positive.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                      Positioned(
                        left: x,
                        top: 4,
                        child: Container(
                          width: thumb,
                          height: thumb,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.surface,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              inRange
                  ? 'Preço atual ${formatUsd(currentPrice)} (${(position * 100).toStringAsFixed(0)}% da faixa)'
                  : 'Preço atual ${formatUsd(currentPrice)} (fora da faixa de 52 sem.)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
