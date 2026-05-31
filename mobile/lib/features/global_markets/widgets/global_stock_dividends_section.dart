import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/features/fii/widgets/fii_history_charts.dart';
import 'package:rico_investidor/features/global_markets/models/global_market_models.dart';
import 'package:rico_investidor/models/fii_models.dart';

class GlobalStockDividendsSection extends StatelessWidget {
  const GlobalStockDividendsSection({
    super.key,
    required this.summary,
    required this.dividends,
    required this.total,
  });

  final GlobalStockDividendsSummaryDto summary;
  final List<GlobalStockDividendDto> dividends;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (dividends.isEmpty && summary.ttmPerShare == null) {
      return const SizedBox.shrink();
    }

    final annual = summary.annualTotals
        .map(
          (row) => FiiDistributionYear(
            year: row.year,
            totalPerShare: row.total,
            payments: null,
          ),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlobalStockDividendsSummaryCard(summary: summary),
        if (annual.isNotEmpty) ...[
          const SizedBox(height: 12),
          FiiDistributionsChart(annualSummary: annual),
        ],
        if (summary.upcoming.isNotEmpty) ...[
          const SizedBox(height: 12),
          _AgendaCard(upcoming: summary.upcoming),
        ],
        if (dividends.isNotEmpty) ...[
          const SizedBox(height: 12),
          _RecentDividendsCard(dividends: dividends, total: total),
        ],
      ],
    );
  }
}

class GlobalStockDividendsSummaryCard extends StatelessWidget {
  const GlobalStockDividendsSummaryCard({super.key, required this.summary});

  final GlobalStockDividendsSummaryDto summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Proventos', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (summary.dividendYieldTtm != null)
                  _MetricChip(
                    label: 'DY 12m',
                    value: '${summary.dividendYieldTtm!.toStringAsFixed(2)}%',
                    highlight: true,
                  ),
                if (summary.ttmPerShare != null)
                  _MetricChip(
                    label: 'Total 12m',
                    value: formatUsd(summary.ttmPerShare!),
                  ),
                if (summary.payments12m > 0)
                  _MetricChip(
                    label: 'Pagamentos 12m',
                    value: '${summary.payments12m}',
                  ),
                if (summary.totalPayments > 0)
                  _MetricChip(
                    label: 'Histórico',
                    value: '${summary.totalPayments}',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AgendaCard extends StatelessWidget {
  const _AgendaCard({required this.upcoming});

  final List<GlobalStockDividendDto> upcoming;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Agenda de dividendos',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...upcoming.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(_formatDate(item.date))),
                    Text(
                      formatUsd(item.amount),
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
}

class _RecentDividendsCard extends StatelessWidget {
  const _RecentDividendsCard({required this.dividends, required this.total});

  final List<GlobalStockDividendDto> dividends;
  final int total;

  @override
  Widget build(BuildContext context) {
    final recent = dividends.take(12).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Proventos recentes',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (total > recent.length)
                  Text('${recent.length} de $total', style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
            const SizedBox(height: 8),
            ...recent.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(_formatDate(item.date))),
                    Text(
                      formatUsd(item.amount),
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
    final color = highlight ? AppColors.positive : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(String raw) {
  if (raw.length >= 10) return raw.substring(0, 10);
  return raw;
}
