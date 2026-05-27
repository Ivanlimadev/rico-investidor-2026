import 'package:flutter/material.dart';
import 'package:rico_investidor/features/fii/utils/fii_data_freshness.dart';
import 'package:rico_investidor/models/fii_models.dart';

class FiiDataFreshnessCard extends StatelessWidget {
  const FiiDataFreshnessCard({
    super.key,
    required this.reportReferenceDate,
    this.candles = const [],
  });

  final String? reportReferenceDate;
  final List<FiiCandleBar> candles;

  @override
  Widget build(BuildContext context) {
    final quoteDate = latestQuoteTradeDate(candles);
    final hasReport = reportReferenceDate != null && reportReferenceDate!.isNotEmpty;
    final hasQuote = quoteDate != null;

    if (!hasReport && !hasQuote) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.65);

    return Card(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Atualização dos dados', style: theme.textTheme.labelLarge),
              ],
            ),
            if (hasReport) ...[
              const SizedBox(height: 10),
              _FreshnessRow(
                icon: Icons.description_outlined,
                title: cvmReportReferenceLabel(reportReferenceDate),
                subtitle: 'P/VP, vacância, patrimônio e taxas vêm do informe mensal da CVM.',
              ),
            ],
            if (hasQuote) ...[
              const SizedBox(height: 10),
              _FreshnessRow(
                icon: Icons.show_chart,
                title: quoteUpdatedLabel(quoteDate),
                subtitle: 'Preço de mercado na B3 — pode ser mais recente que o relatório.',
              ),
            ] else if (hasReport) ...[
              const SizedBox(height: 8),
              Text(
                'Cotação do pregão: carregando…',
                style: theme.textTheme.bodySmall?.copyWith(color: muted, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FreshnessRow extends StatelessWidget {
  const _FreshnessRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.65);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: muted),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
            ],
          ),
        ),
      ],
    );
  }
}
