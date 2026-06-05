import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/features/fii/utils/fii_payments.dart';
import 'package:rico_investidor/features/fii/widgets/fii_history_charts.dart';
import 'package:rico_investidor/features/quotes/models/stock_quote_detail.dart';
import 'package:rico_investidor/features/quotes/utils/stock_payments.dart';
import 'package:rico_investidor/features/quotes/widgets/stock_recent_dividends_card.dart';
import 'package:rico_investidor/models/fii_models.dart';

/// Seção de proventos BR alinhada ao Investidor10 (resumo, próximo, agenda, histórico).
class BrStockDividendsSection extends StatelessWidget {
  const BrStockDividendsSection({
    super.key,
    required this.dividends,
    this.dividendYield12m,
  });

  final StockDividendsDto dividends;
  final double? dividendYield12m;

  @override
  Widget build(BuildContext context) {
    if (dividends.payments.isEmpty && dividends.displayDividendYield == null) {
      return const SizedBox.shrink();
    }

    final summary = dividends.summary;
    final dy = dividendYield12m ?? dividends.displayDividendYield;
    final annual = dividends.annualSummary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Proventos',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        _BrDividendsSummaryCard(dividends: dividends, dividendYield12m: dy),
        if (summary.nextDividend != null) ...[
          const SizedBox(height: 12),
          _BrNextDividendCard(
            event: summary.nextDividend!,
            frequencyLabel: summary.frequencyLabel,
          ),
        ],
        if (annual.isNotEmpty) ...[
          const SizedBox(height: 12),
          FiiDistributionsChart(
            annualSummary: annual,
            payments: dividends.payments,
            title: 'Proventos pagos por ano',
            valueFormatter: formatBrl,
            maxYears: 10,
          ),
        ],
        if (summary.upcoming.isNotEmpty) ...[
          const SizedBox(height: 12),
          _BrUpcomingAgendaCard(events: summary.upcoming),
        ],
        if (dividends.payments.isNotEmpty) ...[
          const SizedBox(height: 12),
          StockRecentDividendsCard(payments: dividends.payments),
        ],
      ],
    );
  }
}

class _BrDividendsSummaryCard extends StatelessWidget {
  const _BrDividendsSummaryCard({
    required this.dividends,
    this.dividendYield12m,
  });

  final StockDividendsDto dividends;
  final double? dividendYield12m;

  @override
  Widget build(BuildContext context) {
    final summary = dividends.summary;
    final dy = dividendYield12m ?? dividends.displayDividendYield;
    final ttm = summary.ttmPerShareDisplay ?? dividends.ttmPerShare;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.positive.withValues(alpha: 0.12),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Resumo de proventos', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (dy != null)
                  _MetricChip(
                    label: 'DY atual',
                    value: '${dy.toStringAsFixed(2)}%',
                    highlight: true,
                  ),
                if (summary.dividendYieldAvg5y != null)
                  _MetricChip(
                    label: 'DY médio 5a',
                    value: '${summary.dividendYieldAvg5y!.toStringAsFixed(2)}%',
                  ),
                if (summary.dividendYieldAvg10y != null)
                  _MetricChip(
                    label: 'DY médio 10a',
                    value: '${summary.dividendYieldAvg10y!.toStringAsFixed(2)}%',
                  ),
                if (ttm != null)
                  _MetricChip(label: 'Total 12m / ação', value: formatBrl(ttm)),
                if (summary.avgAmount12m != null)
                  _MetricChip(
                    label: 'Média por pagamento',
                    value: formatBrl(summary.avgAmount12m!),
                  ),
                if (summary.frequencyLabel != null)
                  _MetricChip(label: 'Frequência', value: summary.frequencyLabel!),
                if (summary.payments12m != null && summary.payments12m! > 0)
                  _MetricChip(label: 'Pagamentos 12m', value: '${summary.payments12m}'),
                if (dividends.totalPayments != null)
                  _MetricChip(label: 'Histórico', value: '${dividends.totalPayments}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BrNextDividendCard extends StatelessWidget {
  const _BrNextDividendCard({
    required this.event,
    this.frequencyLabel,
  });

  final StockDividendEventDto event;
  final String? frequencyLabel;

  @override
  Widget build(BuildContext context) {
    final projected = event.isProjected;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final amount = event.valuePerShare;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.event_available_outlined, color: AppColors.positive, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    projected ? 'Próximo provento (estimado)' : 'Próximo provento',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (projected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Projeção',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
            if (amount != null) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatBrl(amount),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.positive,
                        ),
                  ),
                  if (event.label != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      event.label!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: onSurface.withValues(alpha: 0.65),
                          ),
                    ),
                  ],
                  if (frequencyLabel != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      '· $frequencyLabel',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: onSurface.withValues(alpha: 0.65),
                          ),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 16),
            _TimelineRow(
              label: 'Data COM',
              value: _formatBrDate(event.comDate),
              helper: 'Último dia para comprar com direito ao provento',
            ),
            _TimelineRow(
              label: 'Data ex',
              value: _formatBrDate(event.exDate),
              helper: 'Data ex-dividendo na B3',
            ),
            _TimelineRow(
              label: 'Pagamento',
              value: _formatBrDate(event.paymentDate),
              helper: projected && event.paymentDate == null
                  ? 'Data a confirmar'
                  : 'Crédito estimado na conta',
              muted: event.paymentDate == null,
            ),
            if (projected) ...[
              const SizedBox(height: 10),
              Text(
                'Estimativa com base no histórico. Confirme no comunicado oficial da empresa.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: onSurface.withValues(alpha: 0.65),
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BrUpcomingAgendaCard extends StatelessWidget {
  const _BrUpcomingAgendaCard({required this.events});

  final List<StockDividendEventDto> events;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Agenda de proventos', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (var i = 0; i < events.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              _AgendaRow(event: events[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _AgendaRow extends StatelessWidget {
  const _AgendaRow({required this.event});

  final StockDividendEventDto event;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.label ?? 'Provento',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'COM ${_formatBrDate(event.comDate)} · Pag. ${_formatBrDate(event.paymentDate)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                ),
              ],
            ),
          ),
          if (event.valuePerShare != null)
            Text(
              formatBrl(event.valuePerShare!),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.positive,
                  ),
            ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.label,
    required this.value,
    required this.helper,
    this.muted = false,
  });

  final String label;
  final String value;
  final String helper;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: onSurface.withValues(alpha: 0.7),
                  ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: muted ? onSurface.withValues(alpha: 0.45) : null,
                      ),
                ),
                Text(
                  helper,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: onSurface.withValues(alpha: 0.55),
                      ),
                ),
              ],
            ),
          ),
        ],
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
                  color: highlight ? AppColors.positive : null,
                ),
          ),
        ],
      ),
    );
  }
}

String _formatBrDate(String? iso) {
  if (iso == null || iso.length < 10) return '—';
  return formatPaymentDate(iso);
}
