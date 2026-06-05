import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/features/fii/widgets/fii_history_charts.dart';
import 'package:rico_investidor/features/global_markets/models/global_market_models.dart';
import 'package:rico_investidor/features/global_markets/utils/global_stock_dividend_utils.dart';
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
        Text(
          'Dividendos',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        GlobalStockDividendsSummaryCard(summary: summary),
        if (summary.nextDividend != null) ...[
          const SizedBox(height: 12),
          _NextDividendCard(
            dividend: summary.nextDividend!,
            frequencyLabel: summary.frequencyLabel,
          ),
        ],
        if (annual.isNotEmpty) ...[
          const SizedBox(height: 12),
          FiiDistributionsChart(
            annualSummary: annual,
            globalDividends: dividends,
            title: 'Dividendos pagos por ano',
            valueFormatter: formatUsd,
            maxYears: 8,
            perShareLabel: 'ação',
          ),
        ],
        if (summary.upcoming.isNotEmpty) ...[
          const SizedBox(height: 12),
          _AgendaCard(upcoming: summary.upcoming),
        ],
        if (dividends.isNotEmpty) ...[
          const SizedBox(height: 12),
          _DividendsHistoryCard(dividends: dividends, total: total),
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
                if (summary.dividendYieldTtm != null)
                  _MetricChip(
                    label: 'DY 12m',
                    value: '${summary.dividendYieldTtm!.toStringAsFixed(2)}%',
                    highlight: true,
                  ),
                if (summary.ttmPerShare != null)
                  _MetricChip(
                    label: 'Total 12m / ação',
                    value: formatUsd(summary.ttmPerShare!),
                  ),
                if (summary.avgAmount12m != null)
                  _MetricChip(
                    label: 'Média por pagamento',
                    value: formatUsd(summary.avgAmount12m!),
                  ),
                if (summary.frequencyLabel != null)
                  _MetricChip(
                    label: 'Frequência',
                    value: summary.frequencyLabel!,
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

class _NextDividendCard extends StatelessWidget {
  const _NextDividendCard({
    required this.dividend,
    this.frequencyLabel,
  });

  final GlobalStockDividendDto dividend;
  final String? frequencyLabel;

  @override
  Widget build(BuildContext context) {
    final projected = dividend.isProjected;
    final onSurface = Theme.of(context).colorScheme.onSurface;

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
                    projected ? 'Próximo dividendo (estimado)' : 'Próximo dividendo',
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
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatUsd(dividend.amount),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.positive,
                      ),
                ),
                const SizedBox(width: 8),
                if (frequencyLabel != null)
                  Text(
                    '· $frequencyLabel',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: onSurface.withValues(alpha: 0.65),
                        ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _TimelineRow(
              label: 'Data ex',
              value: formatGlobalDividendDate(dividend.effectiveExDate),
              helper: 'Último dia para comprar com direito',
            ),
            _TimelineRow(
              label: 'Data COM',
              value: formatGlobalDividendDate(dividend.effectiveComDate),
              helper: 'Último pregão para comprar com direito ao provento',
            ),
            _TimelineRow(
              label: 'Pagamento',
              value: formatGlobalDividendDate(dividend.paymentDate),
              helper: projected && dividend.paymentDate == null ? 'Data a confirmar' : 'Crédito estimado na conta',
              muted: dividend.paymentDate == null,
            ),
            if (dividend.declarationDate != null)
              _TimelineRow(
                label: 'Declaração',
                value: formatGlobalDividendDate(dividend.declarationDate),
                helper: 'Anúncio oficial da empresa',
              ),
            if (projected) ...[
              const SizedBox(height: 10),
              Text(
                'Estimativa com base no histórico de pagamentos. Confirme no comunicado oficial da empresa.',
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
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: muted ? onSurface.withValues(alpha: 0.35) : AppColors.positive,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: onSurface.withValues(alpha: 0.65),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const Spacer(),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: muted ? onSurface.withValues(alpha: 0.45) : null,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
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
              'Agenda confirmada',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const _DividendsTableHeader(),
            const Divider(height: 1),
            ...upcoming.map(
              (item) => Column(
                children: [
                  _DividendTableRow(dividend: item),
                  const Divider(height: 1),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DividendsHistoryCard extends StatefulWidget {
  const _DividendsHistoryCard({required this.dividends, required this.total});

  final List<GlobalStockDividendDto> dividends;
  final int total;

  @override
  State<_DividendsHistoryCard> createState() => _DividendsHistoryCardState();
}

class _DividendsHistoryCardState extends State<_DividendsHistoryCard> {
  static const _pageSize = 10;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final sorted = sortGlobalDividendsNewestFirst(widget.dividends);
    if (sorted.isEmpty) return const SizedBox.shrink();

    final maxPage = ((sorted.length - 1) / _pageSize).floor();
    final page = _page.clamp(0, maxPage);
    final start = page * _pageSize;
    final end = (start + _pageSize).clamp(0, sorted.length);
    final pageItems = sorted.sublist(start, end);
    final hasNext = end < sorted.length;
    final hasPrevious = page > 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Histórico de proventos',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (widget.total > sorted.length)
                  Text('${sorted.length} de ${widget.total}', style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
            const SizedBox(height: 8),
            const _DividendsTableHeader(),
            const Divider(height: 1),
            for (var i = 0; i < pageItems.length; i++) ...[
              _DividendTableRow(dividend: pageItems[i]),
              if (i < pageItems.length - 1) const Divider(height: 1),
            ],
            if (hasNext || hasPrevious) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (hasPrevious)
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () => setState(() => _page = (page - 1).clamp(0, maxPage)),
                      child: const Text('Anterior'),
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: Text(
                      '${start + 1}–$end de ${sorted.length}',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (hasNext)
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () => setState(() => _page = (page + 1).clamp(0, maxPage)),
                      child: const Text('Próximo'),
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DividendsTableHeader extends StatelessWidget {
  const _DividendsTableHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          fontWeight: FontWeight.w600,
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(flex: 22, child: Text('Tipo', style: style)),
          Expanded(flex: 26, child: Text('Data COM', style: style)),
          Expanded(flex: 28, child: Text('Pagamento', style: style)),
          Expanded(
            flex: 24,
            child: Text('Valor', style: style, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

class _DividendTableRow extends StatelessWidget {
  const _DividendTableRow({required this.dividend});

  final GlobalStockDividendDto dividend;

  @override
  Widget build(BuildContext context) {
    final cellStyle = Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600);
    final valueStyle = cellStyle?.copyWith(color: AppColors.positive);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 22,
            child: Text(
              globalDividendTypeLabel(dividend),
              style: cellStyle,
            ),
          ),
            Expanded(
            flex: 26,
            child: Text(
              formatGlobalDividendDate(dividend.effectiveComDate),
              style: cellStyle,
            ),
          ),
          Expanded(
            flex: 28,
            child: Text(
              formatGlobalDividendDate(dividend.effectivePaymentDate),
              style: cellStyle,
            ),
          ),
          Expanded(
            flex: 24,
            child: Text(
              formatGlobalDividendAmount(dividend.amount),
              style: valueStyle,
              textAlign: TextAlign.end,
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
