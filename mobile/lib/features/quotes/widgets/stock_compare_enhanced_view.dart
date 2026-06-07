import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/core/widgets/asset_logo.dart';
import 'package:rico_investidor/core/utils/percent_format.dart';
import 'package:rico_investidor/core/utils/dividend_payment_format.dart';
import 'package:rico_investidor/features/quotes/models/stock_compare.dart';

enum CompareMarket { brazil, us }

const _tickerPalette = [
  Color(0xFF1B8A5A),
  Color(0xFF2563EB),
  Color(0xFFE67E22),
];

class StockCompareEnhancedView extends StatelessWidget {
  const StockCompareEnhancedView({
    super.key,
    required this.items,
    required this.market,
  });

  final List<StockCompareItemDto> items;
  final CompareMarket market;

  bool get _isBr => market == CompareMarket.brazil;

  String _money(double value) => _isBr ? formatBrl(value) : formatUsd(value);

  String? _compactMoney(double? value) {
    if (value == null) return null;
    return _isBr ? formatCompactBrl(value) : formatCompactUsd(value);
  }

  String? _pct(double? value) => value == null ? null : formatPct(value);

  String? _num(double? value, {int digits = 2}) =>
      value?.toStringAsFixed(digits);

  Color _colorFor(int index) => _tickerPalette[index % _tickerPalette.length];

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReportHeader(isBr: _isBr, count: items.length),
        const SizedBox(height: 14),
        _TickerHeroStrip(items: items, isBr: _isBr, money: _money, colorFor: _colorFor),
        const SizedBox(height: 14),
        _ExecutiveSummary(items: items, pct: _pct, colorFor: _colorFor),
        const SizedBox(height: 14),
        _SectionShell(
          index: '01',
          title: 'Desempenho no pregão',
          subtitle: 'Variação do dia com escala proporcional',
          icon: Icons.show_chart,
          child: _DailyChangePanel(items: items, colorFor: _colorFor),
        ),
        const SizedBox(height: 12),
        _SectionShell(
          index: '02',
          title: 'Visão gráfica',
          subtitle: 'Participação relativa e rentabilidade',
          icon: Icons.insights_outlined,
          child: Column(
            children: [
              _DualPieRow(
                items: items,
                colorFor: _colorFor,
                compactMoney: _compactMoney,
                pct: _pct,
              ),
              if (items.any((i) => i.returns.isNotEmpty)) ...[
                const SizedBox(height: 14),
                _ReturnsComparisonChart(items: items, colorFor: _colorFor),
              ],
              if (items.any((i) => i.marketStats.fiftyTwoWeekHigh != null)) ...[
                const SizedBox(height: 14),
                _Range52WeekPanel(items: items, money: _money, colorFor: _colorFor),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _WinnersBoard(items: items, pct: _pct, num: _num, colorFor: _colorFor),
        const SizedBox(height: 12),
        _SectionShell(
          index: '03',
          title: 'Proventos',
          subtitle: 'Dividendos e calendário',
          icon: Icons.payments_outlined,
          child: _DataTableSection(
            rows: _dividendRows(),
            items: items,
            highlightMode: _HighlightMode.higher,
          ),
        ),
        const SizedBox(height: 12),
        _SectionShell(
          index: '04',
          title: 'Fundamentos',
          subtitle: 'Valuation e qualidade',
          icon: Icons.analytics_outlined,
          child: Column(
            children: [
              _FundamentalsIndexBars(items: items, colorFor: _colorFor),
              const SizedBox(height: 12),
              _DataTableSection(
                rows: [
                  _RowDef('DY atual', (i) => _pct(i.dividends.displayDy ?? i.fundamentals.dividendYield12m),
                      highlight: true),
                  _RowDef('P/L', (i) => _num(i.fundamentals.priceEarnings)),
                  _RowDef('P/VP', (i) => _num(i.fundamentals.priceToBook)),
                  _RowDef('ROE', (i) => _pct(i.fundamentals.returnOnEquity)),
                  _RowDef('ROA', (i) => _pct(i.fundamentals.returnOnAssets)),
                  _RowDef('Margem líq.', (i) => _pct(i.fundamentals.profitMargin)),
                  _RowDef('Payout', (i) => _pct(i.fundamentals.payoutRatio)),
                  _RowDef('LPA', (i) => _num(i.fundamentals.earningsPerShare)),
                  _RowDef('EV/EBITDA', (i) => _num(i.fundamentals.enterpriseToEbitda)),
                  _RowDef('EBITDA', (i) => _compactMoney(i.fundamentals.ebitda)),
                  _RowDef('FCF', (i) => _compactMoney(i.fundamentals.freeCashflow)),
                ],
                items: items,
                highlightMode: _HighlightMode.higher,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (items.any((i) => i.returns.isNotEmpty))
          _SectionShell(
            index: '05',
            title: 'Rentabilidade histórica',
            subtitle: 'Períodos vs benchmark implícito',
            icon: Icons.trending_up,
            child: _DataTableSection(
              rows: _returnRows(),
              items: items,
              highlightMode: _HighlightMode.higher,
            ),
          ),
        if (items.any((i) => i.returns.isNotEmpty)) const SizedBox(height: 12),
        _SectionShell(
          index: items.any((i) => i.returns.isNotEmpty) ? '06' : '05',
          title: 'Mercado e perfil',
          subtitle: 'Tamanho, liquidez e setor',
          icon: Icons.business_outlined,
          child: _DataTableSection(
            rows: [
              _RowDef('Cap. mercado', (i) => _compactMoney(i.marketStats.marketCap)),
              _RowDef('Volume', (i) => _compactMoney(i.marketStats.volume)),
              _RowDef('Máx. 52s', (i) => _moneyOptional(i.marketStats.fiftyTwoWeekHigh)),
              _RowDef('Mín. 52s', (i) => _moneyOptional(i.marketStats.fiftyTwoWeekLow)),
              _RowDef('Beta', (i) => _num(i.fundamentals.beta)),
              _RowDef('Setor', (i) => sectorLabel(i.profile.sector)),
              _RowDef('Indústria', (i) => i.profile.industry),
            ],
            items: items,
            highlightMode: _HighlightMode.none,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  String? _moneyOptional(double? value) => value == null ? null : _money(value);

  List<_RowDef> _dividendRows() {
    return [
      _RowDef('DY atual', (i) => _pct(i.dividends.displayDy ?? i.fundamentals.dividendYield12m),
          highlight: true),
      _RowDef('Proventos 12m', (i) => i.dividends.ttmPerShare != null ? _money(i.dividends.ttmPerShare!) : null),
      _RowDef('Pagamentos 12m', (i) => i.dividends.payments12m?.toString()),
      _RowDef('Frequência', (i) => i.dividends.frequencyLabel),
      _RowDef('Próx. COM', (i) => _formatDate(i.dividends.nextComDate)),
      _RowDef('Próx. pagamento', (i) => _formatDate(i.dividends.nextPaymentDate)),
      _RowDef('Próx. valor', (i) => i.dividends.nextAmount != null ? _money(i.dividends.nextAmount!) : null),
    ];
  }

  List<_RowDef> _returnRows() {
    final labels = <String>{};
    for (final item in items) {
      for (final row in item.returns) {
        labels.add(row.label);
      }
    }
    const ordered = ['1M', 'YTD', '1A', '3M', '6M'];
    final sorted = [
      ...ordered.where(labels.contains),
      ...labels.where((l) => !ordered.contains(l)),
    ];
    return sorted
        .map(
          (label) => _RowDef(
            'Retorno $label',
            (i) {
              final match = i.returns.where((r) => r.label == label).toList();
              if (match.isEmpty) return null;
              final pct = match.first.returnPct;
              if (pct == null) return null;
              return '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%';
            },
          ),
        )
        .toList();
  }

  String? _formatDate(String? iso) {
    if (iso == null || iso.length < 10) return null;
    return formatPaymentDate(iso);
  }
}

class _ReportHeader extends StatelessWidget {
  const _ReportHeader({required this.isBr, required this.count});

  final bool isBr;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.assessment_outlined, color: Theme.of(context).colorScheme.primary, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Relatório comparativo',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$count ativos · ${isBr ? 'B3' : 'NYSE/NASDAQ'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionShell extends StatelessWidget {
  const _SectionShell({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String index;
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    index,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(14), child: child),
        ],
      ),
    );
  }
}

class _TickerHeroStrip extends StatelessWidget {
  const _TickerHeroStrip({
    required this.items,
    required this.isBr,
    required this.money,
    required this.colorFor,
  });

  final List<StockCompareItemDto> items;
  final bool isBr;
  final String Function(double) money;
  final Color Function(int) colorFor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorFor(i).withValues(alpha: 0.35)),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 4, height: 36, decoration: BoxDecoration(color: colorFor(i), borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 8),
                      AssetLogo(symbol: items[i].quote.symbol, logoUrl: items[i].profile.logoUrl, size: 28),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(items[i].quote.symbol, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                            Text(
                              items[i].quote.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(money(items[i].quote.price), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  Text(
                    '${items[i].quote.changePercent >= 0 ? '+' : ''}${items[i].quote.changePercent.toStringAsFixed(2)}% hoje',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: items[i].quote.changePercent >= 0 ? AppColors.positive : AppColors.negative,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ExecutiveSummary extends StatelessWidget {
  const _ExecutiveSummary({
    required this.items,
    required this.pct,
    required this.colorFor,
  });

  final List<StockCompareItemDto> items;
  final String? Function(double?) pct;
  final Color Function(int) colorFor;

  @override
  Widget build(BuildContext context) {
    final dyLeader = _leaderIndex(items, (i) => i.dividends.displayDy ?? i.fundamentals.dividendYield12m, higher: true);
    final changeLeader = _leaderIndex(items, (i) => i.quote.changePercent, higher: true);
    final capLeader = _leaderIndex(items, (i) => i.marketStats.marketCap, higher: true);

    return Row(
      children: [
        Expanded(child: _SummaryTile(label: 'Maior alta hoje', value: changeLeader != null ? items[changeLeader].quote.symbol : '—', color: changeLeader != null ? colorFor(changeLeader) : null)),
        const SizedBox(width: 8),
        Expanded(child: _SummaryTile(label: 'Maior DY', value: dyLeader != null ? items[dyLeader].quote.symbol : '—', color: dyLeader != null ? colorFor(dyLeader) : null)),
        const SizedBox(width: 8),
        Expanded(child: _SummaryTile(label: 'Maior cap.', value: capLeader != null ? items[capLeader].quote.symbol : '—', color: capLeader != null ? colorFor(capLeader) : null)),
      ],
    );
  }

  int? _leaderIndex(List<StockCompareItemDto> list, double? Function(StockCompareItemDto) pick, {required bool higher}) {
    int? best;
    double? bestVal;
    for (var i = 0; i < list.length; i++) {
      final v = pick(list[i]);
      if (v == null) continue;
      if (bestVal == null || (higher ? v > bestVal : v < bestVal)) {
        bestVal = v;
        best = i;
      }
    }
    return best;
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}

/// Barras horizontais centradas — negativo à esquerda, positivo à direita.
class _DailyChangePanel extends StatelessWidget {
  const _DailyChangePanel({required this.items, required this.colorFor});

  final List<StockCompareItemDto> items;
  final Color Function(int) colorFor;

  @override
  Widget build(BuildContext context) {
    final maxAbs = items.map((e) => e.quote.changePercent.abs()).fold<double>(0, (a, b) => a > b ? a : b);
    final scale = maxAbs <= 0 ? 1.0 : maxAbs;

    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _DailyChangeRow(
            symbol: items[i].quote.symbol,
            change: items[i].quote.changePercent,
            scale: scale,
            color: colorFor(i),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'Escala: ${scale.toStringAsFixed(2)}% = largura máxima',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
              ),
        ),
      ],
    );
  }
}

class _DailyChangeRow extends StatelessWidget {
  const _DailyChangeRow({
    required this.symbol,
    required this.change,
    required this.scale,
    required this.color,
  });

  final String symbol;
  final double change;
  final double scale;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final positive = change >= 0;
    final fraction = (change.abs() / scale).clamp(0.0, 1.0);

    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(symbol, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
        ),
        Expanded(
          child: SizedBox(
            height: 28,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final half = constraints.maxWidth / 2;
                final barWidth = half * fraction;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Positioned(
                      left: positive ? half : half - barWidth,
                      width: barWidth,
                      child: Container(
                        height: 20,
                        decoration: BoxDecoration(
                          color: (positive ? AppColors.positive : AppColors.negative).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: color.withValues(alpha: 0.5)),
                        ),
                      ),
                    ),
                    Container(width: 2, height: 28, color: Theme.of(context).dividerColor),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 56,
          child: Text(
            '${positive ? '+' : ''}${change.toStringAsFixed(2)}%',
            textAlign: TextAlign.end,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: positive ? AppColors.positive : AppColors.negative,
            ),
          ),
        ),
      ],
    );
  }
}

class _PieSlice {
  const _PieSlice({required this.label, required this.value, required this.color});
  final String label;
  final double value;
  final Color color;
}

class _DualPieRow extends StatelessWidget {
  const _DualPieRow({
    required this.items,
    required this.colorFor,
    required this.compactMoney,
    required this.pct,
  });

  final List<StockCompareItemDto> items;
  final Color Function(int) colorFor;
  final String? Function(double?) compactMoney;
  final String? Function(double?) pct;

  @override
  Widget build(BuildContext context) {
    final capSlices = <_PieSlice>[];
    for (var i = 0; i < items.length; i++) {
      final cap = items[i].marketStats.marketCap;
      if (cap != null && cap > 0) capSlices.add(_PieSlice(label: items[i].quote.symbol, value: cap, color: colorFor(i)));
    }

    final dySlices = <_PieSlice>[];
    for (var i = 0; i < items.length; i++) {
      final dy = items[i].dividends.displayDy ?? items[i].fundamentals.dividendYield12m;
      if (dy != null && dy > 0) dySlices.add(_PieSlice(label: items[i].quote.symbol, value: dy, color: colorFor(i)));
    }

    return Column(
      children: [
        if (capSlices.length >= 2)
          _ComparePieCard(title: 'Peso no capitalização', subtitle: 'Share de cap. de mercado', slices: capSlices),
        if (capSlices.length >= 2 && dySlices.length >= 2) const SizedBox(height: 12),
        if (dySlices.length >= 2)
          _ComparePieCard(title: 'Peso no dividend yield', subtitle: 'DY atual relativo', slices: dySlices),
        if (capSlices.length < 2 && dySlices.length < 2)
          Text(
            'Gráficos de pizza exibidos quando há cap. de mercado ou DY em pelo menos dois ativos.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }
}

class _ComparePieCard extends StatelessWidget {
  const _ComparePieCard({
    required this.title,
    required this.subtitle,
    required this.slices,
  });

  final String title;
  final String subtitle;
  final List<_PieSlice> slices;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (a, s) => a + s.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        SizedBox(
          height: 170,
          child: Row(
            children: [
              Expanded(
                flex: 11,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 38,
                    sections: [
                      for (final slice in slices)
                        PieChartSectionData(
                          value: slice.value,
                          color: slice.color,
                          radius: 54,
                          showTitle: false,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 12,
                child: ListView.separated(
                  itemCount: slices.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final slice = slices[index];
                    final share = total > 0 ? (slice.value / total) * 100 : 0.0;
                    return Row(
                      children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: slice.color, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(slice.label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                        ),
                        Text('${share.toStringAsFixed(1)}%', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800)),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReturnsComparisonChart extends StatelessWidget {
  const _ReturnsComparisonChart({required this.items, required this.colorFor});

  final List<StockCompareItemDto> items;
  final Color Function(int) colorFor;

  @override
  Widget build(BuildContext context) {
    const labels = ['1M', 'YTD', '1A'];
    final available = labels.where((label) => items.any((i) => i.returns.any((r) => r.label == label))).toList();
    if (available.isEmpty) return const SizedBox.shrink();

    double maxAbs = 1;
    for (final item in items) {
      for (final row in item.returns) {
        if (row.returnPct != null) {
          final a = row.returnPct!.abs();
          if (a > maxAbs) maxAbs = a;
        }
      }
    }

    final groups = <BarChartGroupData>[];
    for (var xi = 0; xi < available.length; xi++) {
      final label = available[xi];
      final rods = <BarChartRodData>[];
      for (var yi = 0; yi < items.length; yi++) {
        final match = items[yi].returns.where((r) => r.label == label).toList();
        final val = match.isEmpty ? 0.0 : (match.first.returnPct ?? 0);
        rods.add(
          BarChartRodData(
            toY: val,
            width: 12,
            borderRadius: BorderRadius.circular(3),
            color: colorFor(yi),
          ),
        );
      }
      groups.add(BarChartGroupData(x: xi, barRods: rods, barsSpace: 6));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Rentabilidade por período', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxAbs * 1.15,
              minY: -maxAbs * 1.15,
              barGroups: groups,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (v) => FlLine(
                  color: Theme.of(context).dividerColor,
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (v, _) => Text(
                      '${v.toInt()}%',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= available.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(available[i], style: Theme.of(context).textTheme.labelSmall),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            for (var i = 0; i < items.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: colorFor(i), borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 4),
                  Text(items[i].quote.symbol, style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _Range52WeekPanel extends StatelessWidget {
  const _Range52WeekPanel({required this.items, required this.money, required this.colorFor});

  final List<StockCompareItemDto> items;
  final String Function(double) money;
  final Color Function(int) colorFor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Posição na faixa 52 semanas', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _RangeRow(
            symbol: items[i].quote.symbol,
            price: items[i].quote.price,
            low: items[i].marketStats.fiftyTwoWeekLow,
            high: items[i].marketStats.fiftyTwoWeekHigh,
            color: colorFor(i),
            money: money,
          ),
        ],
      ],
    );
  }
}

class _RangeRow extends StatelessWidget {
  const _RangeRow({
    required this.symbol,
    required this.price,
    required this.low,
    required this.high,
    required this.color,
    required this.money,
  });

  final String symbol;
  final double price;
  final double? low;
  final double? high;
  final Color color;
  final String Function(double) money;

  @override
  Widget build(BuildContext context) {
    if (low == null || high == null || high! <= low!) {
      return Row(
        children: [
          Text(symbol, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          const Text('—'),
        ],
      );
    }

    final t = ((price - low!) / (high! - low!)).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(symbol, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
            const Spacer(),
            Text(money(price), style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: t,
                minHeight: 10,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                color: color.withValues(alpha: 0.55),
              ),
            ),
            Align(
              alignment: Alignment(-1 + 2 * t, 0),
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(money(low!), style: Theme.of(context).textTheme.labelSmall),
            Text(money(high!), style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ],
    );
  }
}

class _FundamentalsIndexBars extends StatelessWidget {
  const _FundamentalsIndexBars({required this.items, required this.colorFor});

  final List<StockCompareItemDto> items;
  final Color Function(int) colorFor;

  @override
  Widget build(BuildContext context) {
    final metrics = <(String, double? Function(StockCompareItemDto), bool)>[
      ('DY', (i) => i.dividends.displayDy ?? i.fundamentals.dividendYield12m, true),
      ('ROE', (i) => i.fundamentals.returnOnEquity, true),
      ('Margem', (i) => i.fundamentals.profitMargin, true),
      ('P/L', (i) => i.fundamentals.priceEarnings, false),
    ];

    final visibleMetrics = <(String, double? Function(StockCompareItemDto), bool)>[];
    for (final metric in metrics) {
      final count = items.where((i) {
        final v = metric.$2(i);
        return v != null && v > 0;
      }).length;
      if (count >= 2) visibleMetrics.add(metric);
    }

    if (visibleMetrics.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Índice relativo', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'P/L, ROE e margens ainda não estão disponíveis para todos os ativos comparados.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Índice relativo (0–100)', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          'Normalizado entre os ativos comparados — maior barra = melhor na métrica.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        for (final metric in visibleMetrics) ...[
          _MetricBarsRow(
            label: metric.$1,
            values: _normalized(items, metric.$2, higherIsBetter: metric.$3),
            symbols: items.map((i) => i.quote.symbol).toList(),
            colorFor: colorFor,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  List<double> _normalized(
    List<StockCompareItemDto> list,
    double? Function(StockCompareItemDto) pick, {
    required bool higherIsBetter,
  }) {
    final values = <double?>[];
    for (final item in list) {
      final v = pick(item);
      values.add(v != null && v > 0 ? v : null);
    }
    final available = values.whereType<double>().toList();
    if (available.length < 2) {
      return List.filled(list.length, double.nan);
    }
    final max = available.reduce((a, b) => a > b ? a : b);
    return values.map((v) {
      if (v == null) return double.nan;
      final n = (v / max) * 100;
      return higherIsBetter ? n : 100 - n;
    }).toList();
  }
}

class _MetricBarsRow extends StatelessWidget {
  const _MetricBarsRow({
    required this.label,
    required this.values,
    required this.symbols,
    required this.colorFor,
  });

  final String label;
  final List<double> values;
  final List<String> symbols;
  final Color Function(int) colorFor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        for (var i = 0; i < values.length; i++)
          if (!values[i].isNaN)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SizedBox(width: 44, child: Text(symbols[i], style: Theme.of(context).textTheme.labelSmall)),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (values[i] / 100).clamp(0.05, 1.0),
                        minHeight: 8,
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        color: colorFor(i),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 32,
                    child: Text(values[i].toStringAsFixed(0), textAlign: TextAlign.end, style: Theme.of(context).textTheme.labelSmall),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SizedBox(width: 44, child: Text(symbols[i], style: Theme.of(context).textTheme.labelSmall)),
                  Expanded(child: Text('—', style: Theme.of(context).textTheme.labelSmall)),
                ],
              ),
            ),
      ],
    );
  }
}

class _WinnersBoard extends StatelessWidget {
  const _WinnersBoard({
    required this.items,
    required this.pct,
    required this.num,
    required this.colorFor,
  });

  final List<StockCompareItemDto> items;
  final String? Function(double?) pct;
  final String? Function(double?) num;
  final Color Function(int) colorFor;

  @override
  Widget build(BuildContext context) {
    final awards = <(String, int?)>[
      ('DY', _best((i) => i.dividends.displayDy ?? i.fundamentals.dividendYield12m, true)),
      ('ROE', _best((i) => i.fundamentals.returnOnEquity, true)),
      ('Menor P/L', _best((i) => i.fundamentals.priceEarnings, false)),
      ('Variação hoje', _best((i) => i.quote.changePercent, true)),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events_outlined, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('Destaques do comparativo', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final award in awards)
                  if (award.$2 != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: colorFor(award.$2!).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: colorFor(award.$2!).withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, size: 14, color: colorFor(award.$2!)),
                          const SizedBox(width: 6),
                          Text(
                            '${award.$1}: ${items[award.$2!].quote.symbol}',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int? _best(double? Function(StockCompareItemDto) pick, bool higher) {
    int? idx;
    double? best;
    for (var i = 0; i < items.length; i++) {
      final v = pick(items[i]);
      if (v == null || v <= 0) continue;
      if (best == null || (higher ? v > best : v < best)) {
        best = v;
        idx = i;
      }
    }
    return idx;
  }
}

enum _HighlightMode { higher, lower, none }

class _RowDef {
  const _RowDef(this.label, this.value, {this.highlight = false});

  final String label;
  final String? Function(StockCompareItemDto item) value;
  final bool highlight;
}

class _DataTableSection extends StatelessWidget {
  const _DataTableSection({
    required this.rows,
    required this.items,
    required this.highlightMode,
  });

  final List<_RowDef> rows;
  final List<StockCompareItemDto> items;
  final _HighlightMode highlightMode;

  @override
  Widget build(BuildContext context) {
    final visibleRows = rows.where((row) => items.any((item) => row.value(item) != null)).toList();
    if (visibleRows.isEmpty) {
      return Text('Sem dados para esta seção.', style: Theme.of(context).textTheme.bodySmall);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: MediaQuery.sizeOf(context).width - 68),
        child: Column(
          children: [
            Row(
              children: [
                const SizedBox(width: 120),
                for (final item in items)
                  SizedBox(
                    width: 108,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        item.quote.symbol,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
              ],
            ),
            const Divider(height: 1),
            for (final row in visibleRows) ...[
              _MetricCompareRow(
                label: row.label,
                values: items.map(row.value).toList(),
                highlight: row.highlight,
                highlightMode: highlightMode,
              ),
              const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricCompareRow extends StatelessWidget {
  const _MetricCompareRow({
    required this.label,
    required this.values,
    required this.highlight,
    required this.highlightMode,
  });

  final String label;
  final List<String?> values;
  final bool highlight;
  final _HighlightMode highlightMode;

  @override
  Widget build(BuildContext context) {
    int? bestIndex;
    if (highlight && highlightMode != _HighlightMode.none) {
      double? best;
      for (var i = 0; i < values.length; i++) {
        final raw = values[i];
        if (raw == null) continue;
        final parsed = double.tryParse(raw.replaceAll('%', '').replaceAll('+', '').replaceAll(',', '.'));
        if (parsed == null) continue;
        if (best == null) {
          best = parsed;
          bestIndex = i;
        } else if (highlightMode == _HighlightMode.higher && parsed > best) {
          best = parsed;
          bestIndex = i;
        } else if (highlightMode == _HighlightMode.lower && parsed < best) {
          best = parsed;
          bestIndex = i;
        }
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
        ),
        for (var i = 0; i < values.length; i++)
          SizedBox(
            width: 108,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: Text(
                values[i] ?? '—',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: bestIndex == i ? AppColors.positive : null,
                    ),
              ),
            ),
          ),
      ],
    );
  }
}

String sectorLabel(String? sector) {
  if (sector == null || sector.isEmpty) return '—';
  return switch (sector) {
    'Finance' => 'Financeiro',
    'Energy Minerals' => 'Energia',
    'Utilities' => 'Utilidades',
    'Retail Trade' => 'Varejo',
    'Health Services' => 'Saúde',
    'Technology Services' => 'Tecnologia',
    'Consumer Services' => 'Consumo',
    'Producer Manufacturing' => 'Indústria',
    'Transportation' => 'Transporte',
    'Communications' => 'Comunicações',
    'Non-Energy Minerals' => 'Mineração',
    'Process Industries' => 'Indústria proc.',
    'Electronic Technology' => 'Eletrônicos',
    'Consumer Non-Durables' => 'Consumo NC',
    'Consumer Durables' => 'Consumo dur.',
    'Distribution Services' => 'Distribuição',
    'Commercial Services' => 'Serviços com.',
    'Industrial Services' => 'Serviços ind.',
    _ => sector,
  };
}

