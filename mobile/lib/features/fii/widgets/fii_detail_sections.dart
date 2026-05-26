import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/features/fii/utils/fii_format.dart';
import 'package:rico_investidor/features/fii/utils/fii_payments.dart';
import 'package:rico_investidor/features/fii/utils/fii_property_state.dart';
import 'package:rico_investidor/models/fii_models.dart';

class FiiSectionHeader extends StatelessWidget {
  const FiiSectionHeader(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}

class FiiMetricsGrid extends StatelessWidget {
  const FiiMetricsGrid({super.key, required this.metrics, this.embedded = false});

  final List<FiiMetricItem> metrics;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final visible = metrics.where((m) => m.value != null && m.value!.isNotEmpty).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        runSpacing: 16,
        children: visible.map((m) => SizedBox(width: 100, child: _MetricTile(item: m))).toList(),
      ),
    );

    if (embedded) return content;

    return Card(child: content);
  }
}

class FiiMetricItem {
  const FiiMetricItem({
    required this.label,
    required this.value,
    this.highlight = false,
    this.valueColor,
  });

  final String label;
  final String? value;
  final bool highlight;
  final Color? valueColor;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.item});

  final FiiMetricItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          item.value!,
          style: (item.highlight
                  ? Theme.of(context).textTheme.titleMedium
                  : Theme.of(context).textTheme.titleSmall)
              ?.copyWith(fontWeight: FontWeight.w700, color: item.valueColor),
        ),
      ],
    );
  }
}

class FiiInfoCard extends StatelessWidget {
  const FiiInfoCard({super.key, required this.rows});

  final List<FiiInfoRow> rows;

  @override
  Widget build(BuildContext context) {
    final visible = rows.where((r) => r.value != null && r.value!.isNotEmpty).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            ListTile(
              title: Text(visible[i].label),
              subtitle: visible[i].subtitle != null ? Text(visible[i].subtitle!) : null,
              trailing: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(
                  visible[i].value!,
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class FiiInfoRow {
  const FiiInfoRow({required this.label, required this.value, this.subtitle});

  final String label;
  final String? value;
  final String? subtitle;
}

class FiiCompositionCard extends StatelessWidget {
  const FiiCompositionCard({super.key, required this.composition});

  final FiiAssetComposition composition;

  static const _colors = [
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
    Color(0xFF009688),
    Color(0xFFE91E63),
    Color(0xFF795548),
    Color(0xFF607D8B),
  ];

  @override
  Widget build(BuildContext context) {
    final items = composition.nonZeroItems();
    if (items.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Expanded(
                        flex: (items[i].value * 100).round().clamp(1, 10000),
                        child: Container(color: _colors[i % _colors.length]),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _colors[i % _colors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(items[i].label)),
                  Text(
                    formatPct(items[i].value),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class FiiPropertiesCard extends StatefulWidget {
  const FiiPropertiesCard({
    super.key,
    required this.properties,
    this.referenceDate,
    this.pageSize = 3,
  });

  final List<FiiProperty> properties;
  final String? referenceDate;
  final int pageSize;

  @override
  State<FiiPropertiesCard> createState() => _FiiPropertiesCardState();
}

class _FiiPropertiesCardState extends State<FiiPropertiesCard> {
  int _page = 0;

  int get _pageCount {
    if (widget.properties.isEmpty) return 0;
    return (widget.properties.length / widget.pageSize).ceil();
  }

  List<FiiProperty> get _visibleProperties {
    final start = _page * widget.pageSize;
    final end = (start + widget.pageSize).clamp(0, widget.properties.length);
    return widget.properties.sublist(start, end);
  }

  void _goToPage(int page) {
    setState(() => _page = page.clamp(0, _pageCount - 1));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.properties.isEmpty) return const SizedBox.shrink();

    final showPager = widget.properties.length > widget.pageSize;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.72,
              ),
              itemCount: _visibleProperties.length,
              itemBuilder: (context, index) => _PropertyTile(property: _visibleProperties[index]),
            ),
            if (showPager) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Anterior',
                    onPressed: _page > 0 ? () => _goToPage(_page - 1) : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text(
                    '${_page + 1} / $_pageCount',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  IconButton(
                    tooltip: 'Próximos',
                    onPressed: _page < _pageCount - 1 ? () => _goToPage(_page + 1) : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PropertyTile extends StatelessWidget {
  const _PropertyTile({required this.property});

  final FiiProperty property;

  @override
  Widget build(BuildContext context) {
    final state = parsePropertyState(property.address);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                state,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            )
          else
            Text(
              '—',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              property.name,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (property.revenuePct != null)
            Text(
              formatPct(property.revenuePct!),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.positive,
                    fontWeight: FontWeight.w700,
                  ),
            )
          else if (property.areaSqm != null)
            Text(
              formatAreaSqm(property.areaSqm!),
              style: Theme.of(context).textTheme.labelSmall,
            ),
        ],
      ),
    );
  }
}

class FiiTenantsCard extends StatelessWidget {
  const FiiTenantsCard({super.key, required this.tenants});

  final FiiTenantsResponse tenants;

  @override
  Widget build(BuildContext context) {
    if (tenants.sectors.isEmpty) return const SizedBox.shrink();

    final sorted = List<FiiTenantSector>.from(tenants.sectors)
      ..sort((a, b) => (b.revenuePct ?? 0).compareTo(a.revenuePct ?? 0));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (tenants.topSectorPct != null)
            ListTile(
              title: const Text('Maior setor'),
              trailing: Text(
                formatPct(tenants.topSectorPct!),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          for (var i = 0; i < sorted.length; i++) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(sorted[i].sector)),
                      Text(
                        sorted[i].revenuePct != null ? formatPct(sorted[i].revenuePct!) : '—',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  if (sorted[i].revenuePct != null) ...[
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: (sorted[i].revenuePct! / 100).clamp(0, 1),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class FiiDistributionsSection extends StatefulWidget {
  const FiiDistributionsSection({super.key, required this.distributions});

  final FiiDistributions distributions;

  @override
  State<FiiDistributionsSection> createState() => _FiiDistributionsSectionState();
}

class _FiiDistributionsSectionState extends State<FiiDistributionsSection> {
  int? _expandedYear;

  static int? _paymentYear(FiiDistributionPayment payment) {
    final date = payment.paymentDate ?? payment.referenceDate;
    if (date == null || date.length < 4) return null;
    return int.tryParse(date.substring(0, 4));
  }

  List<FiiDistributionPayment> _paymentsForYear(int year) {
    return widget.distributions.payments.where((p) => _paymentYear(p) == year).toList()
      ..sort((a, b) => (a.referenceDate ?? '').compareTo(b.referenceDate ?? ''));
  }

  @override
  Widget build(BuildContext context) {
    final distributions = widget.distributions;
    final hasSummary = distributions.annualSummary.isNotEmpty;
    if (!hasSummary && distributions.payments.isEmpty) return const SizedBox.shrink();

    final sortedSummary = List<FiiDistributionYear>.from(distributions.annualSummary)
      ..sort((a, b) => b.year.compareTo(a.year));

    final lastPayment = latestPayment(distributions.payments);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FiiMetricsGrid(
          metrics: [
            FiiMetricItem(
              label: 'DY 12m',
              value: distributions.dividendYieldTtm != null
                  ? formatPct(distributions.dividendYieldTtm!)
                  : null,
              valueColor: AppColors.positive,
            ),
            FiiMetricItem(
              label: 'Provento 12m/cota',
              value: distributions.ttmPerShare != null ? formatBrl(distributions.ttmPerShare!) : null,
            ),
            FiiMetricItem(
              label: 'Último dividendo',
              value: lastPayment?.valuePerShare != null
                  ? formatBrl(lastPayment!.valuePerShare!)
                  : null,
              valueColor: AppColors.positive,
            ),
            FiiMetricItem(
              label: 'Pagamentos',
              value: distributions.totalPayments?.toString(),
            ),
          ],
        ),
        if (hasSummary) ...[
          const SizedBox(height: 12),
          const FiiSectionHeader('Proventos por ano'),
          const SizedBox(height: 8),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < sortedSummary.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _YearPaymentsTile(
                    summary: sortedSummary[i],
                    payments: _paymentsForYear(sortedSummary[i].year),
                    expanded: _expandedYear == sortedSummary[i].year,
                    onTap: () {
                      setState(() {
                        final year = sortedSummary[i].year;
                        _expandedYear = _expandedYear == year ? null : year;
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _YearPaymentsTile extends StatelessWidget {
  const _YearPaymentsTile({
    required this.summary,
    required this.payments,
    required this.expanded,
    required this.onTap,
  });

  final FiiDistributionYear summary;
  final List<FiiDistributionPayment> payments;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          title: Text('${summary.year}'),
          subtitle: Text('${summary.payments ?? payments.length} pagamentos'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                summary.totalPerShare != null ? formatBrl(summary.totalPerShare!) : '—',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.positive,
                    ),
              ),
              const SizedBox(width: 4),
              Icon(expanded ? Icons.expand_less : Icons.expand_more),
            ],
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Column(
            children: [
              if (payments.isEmpty)
                const ListTile(
                  dense: true,
                  title: Text('Nenhum pagamento detalhado disponível'),
                )
              else
                for (var i = 0; i < payments.length; i++) ...[
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    dense: true,
                    title: Text(payments[i].referenceDate ?? '—'),
                    subtitle: payments[i].paymentDate != null
                        ? Text('Pagamento: ${payments[i].paymentDate}')
                        : null,
                    trailing: Text(
                      payments[i].valuePerShare != null
                          ? formatBrl(payments[i].valuePerShare!)
                          : '—',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.positive,
                          ),
                    ),
                  ),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

class FiiHeaderChips extends StatelessWidget {
  const FiiHeaderChips({super.key, required this.detail});

  final FiiDetail detail;

  @override
  Widget build(BuildContext context) {
    final chips = <String>[
      if (detail.fundType != null) detail.fundType!,
      if (detail.segment != null) detail.segment!,
      if (detail.managementType != null) detail.managementType!,
      if (detail.mandate != null) detail.mandate!,
    ];

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: chips
          .map(
            (label) => Chip(
              label: Text(label),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          )
          .toList(),
    );
  }
}
