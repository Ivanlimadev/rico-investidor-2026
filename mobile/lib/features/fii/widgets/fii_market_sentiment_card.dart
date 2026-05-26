import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/features/fii/utils/fii_market_sentiment.dart';
import 'package:rico_investidor/features/fii/utils/fii_returns.dart';
import 'package:rico_investidor/models/fii_models.dart';

class FiiMarketSentimentCard extends StatelessWidget {
  const FiiMarketSentimentCard({
    super.key,
    required this.history,
    required this.currentPrice,
  });

  final List<FiiHistoryPoint> history;
  final double? currentPrice;

  @override
  Widget build(BuildContext context) {
    final sentiment = computeFiiMarketSentiment(
      history: history,
      currentPrice: currentPrice,
    );

    if (sentiment == null) return const SizedBox.shrink();

    final color = _colorForLevel(sentiment.level);
    final icon = _iconForLevel(sentiment.level);
    final markerPosition = ((sentiment.score + 100) / 200).clamp(0.0, 1.0);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.14),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.insights_outlined, size: 20, color: color),
                const SizedBox(width: 8),
                Text('Sentimento de mercado', style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Indicador educativo com base na valorização ou desvalorização '
              'da cotação em diferentes prazos (não inclui proventos).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sentiment.label,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sentiment.summary,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SentimentGauge(markerPosition: markerPosition, markerColor: color),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Pessimista', style: Theme.of(context).textTheme.labelSmall),
                Text('Neutro', style: Theme.of(context).textTheme.labelSmall),
                Text('Otimista', style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sentiment.periods.map((period) {
                final positive = period.priceReturnPct >= 0;
                final chipColor = positive ? AppColors.positive : AppColors.negative;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: chipColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: chipColor.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        fiiReturnPeriodDisplayLabel(period.label),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            positive ? Icons.trending_up : Icons.trending_down,
                            size: 14,
                            color: chipColor,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${positive ? '+' : ''}${period.priceReturnPct.toStringAsFixed(1)}%',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: chipColor,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            Text(
              '${sentiment.positivePeriods} prazos em valorização · '
              '${sentiment.negativePeriods} em desvalorização',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Color _colorForLevel(FiiSentimentLevel level) {
    return switch (level) {
      FiiSentimentLevel.veryBullish || FiiSentimentLevel.bullish => AppColors.positive,
      FiiSentimentLevel.neutral => AppColors.accent,
      FiiSentimentLevel.bearish || FiiSentimentLevel.veryBearish => AppColors.negative,
    };
  }

  IconData _iconForLevel(FiiSentimentLevel level) {
    return switch (level) {
      FiiSentimentLevel.veryBullish => Icons.sentiment_very_satisfied,
      FiiSentimentLevel.bullish => Icons.sentiment_satisfied,
      FiiSentimentLevel.neutral => Icons.sentiment_neutral,
      FiiSentimentLevel.bearish => Icons.sentiment_dissatisfied,
      FiiSentimentLevel.veryBearish => Icons.sentiment_very_dissatisfied,
    };
  }
}

class _SentimentGauge extends StatelessWidget {
  const _SentimentGauge({
    required this.markerPosition,
    required this.markerColor,
  });

  final double markerPosition;
  final Color markerColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final markerLeft = (width * markerPosition - 7).clamp(0.0, width - 14);

        return SizedBox(
          height: 18,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: SizedBox(
                  height: 8,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Container(color: AppColors.negative.withValues(alpha: 0.35)),
                      ),
                      Expanded(
                        flex: 1,
                        child: Container(color: AppColors.accent.withValues(alpha: 0.35)),
                      ),
                      Expanded(
                        flex: 1,
                        child: Container(color: AppColors.positive.withValues(alpha: 0.35)),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: markerLeft,
                top: -3,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: markerColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: markerColor.withValues(alpha: 0.35),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
