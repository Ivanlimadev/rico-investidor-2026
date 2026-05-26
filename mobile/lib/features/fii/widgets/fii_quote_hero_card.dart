import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/features/fii/utils/fii_format.dart';
import 'package:rico_investidor/features/fii/utils/fii_returns.dart';
import 'package:rico_investidor/features/fii/widgets/fii_detail_sections.dart';
import 'package:rico_investidor/models/fii_models.dart';

class FiiQuoteHeroCard extends StatelessWidget {
  const FiiQuoteHeroCard({
    super.key,
    required this.detail,
    this.history,
  });

  final FiiDetail detail;
  final List<FiiHistoryPoint>? history;

  @override
  Widget build(BuildContext context) {
    final changePct = history != null ? dailyReturnPct(history!, detail.closePrice) : null;
    final isPositive = changePct != null && changePct >= 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.55),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cotação', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    detail.closePrice != null ? formatBrl(detail.closePrice!) : '—',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                if (changePct != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: (isPositive ? AppColors.positive : AppColors.negative)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                              size: 14,
                              color: isPositive ? AppColors.positive : AppColors.negative,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${changePct.abs().toStringAsFixed(2)}%',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: isPositive ? AppColors.positive : AppColors.negative,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rentabilidade do dia',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.end,
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FiiMetricsGrid(
              embedded: true,
              metrics: [
                FiiMetricItem(
                  label: 'P/VP',
                  value: detail.pvp?.toStringAsFixed(2),
                  valueColor: _pvpColor(detail.pvp),
                ),
                FiiMetricItem(
                  label: 'VP/cota',
                  value: detail.bookValuePerShare != null
                      ? formatBrl(detail.bookValuePerShare!)
                      : null,
                ),
                FiiMetricItem(
                  label: 'Patrimônio',
                  value: detail.netAssetValue != null
                      ? formatCompactBrl(detail.netAssetValue!)
                      : null,
                ),
                FiiMetricItem(
                  label: 'DY 12m',
                  value: detail.dividendYieldTtm != null
                      ? formatPct(detail.dividendYieldTtm!)
                      : null,
                  valueColor: AppColors.positive,
                ),
                FiiMetricItem(
                  label: 'Cotistas',
                  value: detail.totalShareholders != null
                      ? formatShareholders(detail.totalShareholders!)
                      : null,
                ),
                FiiMetricItem(
                  label: 'Cotas emitidas',
                  value: detail.sharesOutstanding != null
                      ? formatSharesOutstanding(detail.sharesOutstanding!)
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color? _pvpColor(double? pvp) {
    if (pvp == null) return null;
    if (pvp < 0.95) return AppColors.positive;
    if (pvp > 1.05) return AppColors.negative;
    return null;
  }
}
