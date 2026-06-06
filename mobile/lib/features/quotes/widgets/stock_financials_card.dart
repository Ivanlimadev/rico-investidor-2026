import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/widgets/async_section_placeholder.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/features/quotes/models/stock_financials.dart';

enum _StatementKind {
  income(
    label: 'DRE',
    fullName: 'Demonstração do Resultado',
    description: 'Receitas, custos e lucro do período',
    icon: Icons.receipt_long_outlined,
    highlightKeys: ['total_revenue', 'gross_profit', 'operating_income', 'ebitda', 'net_income'],
  ),
  balance(
    label: 'Balanço',
    fullName: 'Balanço Patrimonial',
    description: 'Ativo, passivo e patrimônio líquido',
    icon: Icons.account_balance_outlined,
    highlightKeys: [
      'total_assets',
      'total_current_assets',
      'cash',
      'total_liab',
      'total_stockholder_equity',
    ],
  ),
  cashFlow(
    label: 'Fluxo de caixa',
    fullName: 'Fluxo de Caixa',
    description: 'Entradas e saídas de caixa',
    icon: Icons.swap_vert_outlined,
    highlightKeys: [
      'operating_cash_flow',
      'investment_cash_flow',
      'financing_cash_flow',
      'free_cash_flow',
      'final_cash_balance',
    ],
  ),
  valueAdded(
    label: 'DVA',
    fullName: 'Demonstração do Valor Adicionado',
    description: 'Como o valor foi gerado e distribuído',
    icon: Icons.pie_chart_outline,
    highlightKeys: [
      'gross_added_value',
      'net_added_value',
      'added_value_to_distribute',
      'team_remuneration',
      'taxes',
    ],
  );

  const _StatementKind({
    required this.label,
    required this.fullName,
    required this.description,
    required this.icon,
    required this.highlightKeys,
  });

  final String label;
  final String fullName;
  final String description;
  final IconData icon;
  final List<String> highlightKeys;

  List<FinancialPeriodDto> periods(StockFinancialsDto financials) {
    return switch (this) {
      _StatementKind.income => financials.incomeStatement,
      _StatementKind.balance => financials.balanceSheet,
      _StatementKind.cashFlow => financials.cashFlow,
      _StatementKind.valueAdded => financials.valueAdded,
    };
  }
}

class StockFinancialsCard extends StatefulWidget {
  const StockFinancialsCard({
    super.key,
    required this.ticker,
    required this.repository,
  });

  final String ticker;
  final QuoteRepository repository;

  @override
  State<StockFinancialsCard> createState() => _StockFinancialsCardState();
}

class _StockFinancialsCardState extends State<StockFinancialsCard> {
  late Future<StockFinancialsDto> _loadFuture;
  int _periodIndex = 0;
  String _period = 'quarterly';
  _StatementKind _statement = _StatementKind.income;
  bool _showAllLines = false;

  @override
  void initState() {
    super.initState();
    _loadFuture = _fetchFinancials();
  }

  Future<StockFinancialsDto> _fetchFinancials() {
    return widget.repository.getStockFinancials(widget.ticker, period: _period);
  }

  void _setPeriod(String period) {
    if (_period == period) return;
    setState(() {
      _period = period;
      _periodIndex = 0;
      _showAllLines = false;
      _loadFuture = _fetchFinancials();
    });
  }

  void _selectStatement(_StatementKind kind) {
    if (_statement == kind) return;
    setState(() {
      _statement = kind;
      _periodIndex = 0;
      _showAllLines = false;
    });
  }

  void _shiftPeriod(int delta, int maxLength) {
    if (maxLength <= 0) return;
    setState(() {
      _periodIndex = (_periodIndex + delta).clamp(0, maxLength - 1);
      _showAllLines = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StockFinancialsDto>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return AsyncSectionPlaceholder(
            title: 'Demonstrações financeiras',
            message: 'Não foi possível carregar as demonstrações.',
            onRetry: () => setState(() => _loadFuture = _fetchFinancials()),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const AsyncSectionPlaceholder(
            title: 'Demonstrações financeiras',
            message: 'Demonstrações indisponíveis para este ativo.',
          );
        }

        final financials = snapshot.data!;
        final isAnnual = financials.isAnnual;
        final activePeriods = _statement.periods(financials);
        final safeIndex = activePeriods.isEmpty
            ? 0
            : _periodIndex.clamp(0, activePeriods.length - 1);

        if (safeIndex != _periodIndex && activePeriods.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _periodIndex = safeIndex);
          });
        }

        return Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isAnnual ? 'Demonstrações anuais' : 'Demonstrações trimestrais',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'quarterly', label: Text('Trim.')),
                        ButtonSegment(value: 'annual', label: Text('Anual')),
                      ],
                      selected: {_period},
                      onSelectionChanged: (selection) => _setPeriod(selection.first),
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _ExplainerBanner(statement: _statement),
                const SizedBox(height: 12),
                _StatementTypePicker(
                  selected: _statement,
                  financials: financials,
                  onSelected: _selectStatement,
                ),
                const SizedBox(height: 14),
                if (activePeriods.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'Sem dados de ${_statement.label} neste recorte.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                else ...[
                  _PeriodNavigator(
                    label: formatFinancialPeriod(
                      activePeriods[safeIndex].endDate,
                      annual: isAnnual,
                    ),
                    index: safeIndex,
                    total: activePeriods.length,
                    isAnnual: isAnnual,
                    onPrevious: safeIndex > 0 ? () => _shiftPeriod(-1, activePeriods.length) : null,
                    onNext: safeIndex < activePeriods.length - 1
                        ? () => _shiftPeriod(1, activePeriods.length)
                        : null,
                    onSelectIndex: (index) => setState(() {
                      _periodIndex = index;
                      _showAllLines = false;
                    }),
                    periods: activePeriods,
                  ),
                  const SizedBox(height: 12),
                  _StatementBody(
                    kind: _statement,
                    period: activePeriods[safeIndex],
                    isAnnual: isAnnual,
                    showAllLines: _showAllLines,
                    onToggleExpand: () => setState(() => _showAllLines = !_showAllLines),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ExplainerBanner extends StatelessWidget {
  const _ExplainerBanner({required this.statement});

  final _StatementKind statement;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.touch_app_outlined, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Toque em uma demonstração para trocar a visão. '
              'Depois use «Ver todas as linhas» para abrir o detalhamento completo de ${statement.label}.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.82),
                    height: 1.35,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatementTypePicker extends StatelessWidget {
  const _StatementTypePicker({
    required this.selected,
    required this.financials,
    required this.onSelected,
  });

  final _StatementKind selected;
  final StockFinancialsDto financials;
  final ValueChanged<_StatementKind> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _StatementKind.values.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final kind = _StatementKind.values[index];
          final periods = kind.periods(financials);
          final isSelected = kind == selected;
          final hasData = periods.isNotEmpty;
          final lineCount = hasData
              ? periods.first.lines.where((line) => line.value != null).length
              : 0;

          return _StatementTypeTile(
            kind: kind,
            isSelected: isSelected,
            hasData: hasData,
            periodCount: periods.length,
            lineCount: lineCount,
            onTap: () => onSelected(kind),
          );
        },
      ),
    );
  }
}

class _StatementTypeTile extends StatelessWidget {
  const _StatementTypeTile({
    required this.kind,
    required this.isSelected,
    required this.hasData,
    required this.periodCount,
    required this.lineCount,
    required this.onTap,
  });

  final _StatementKind kind;
  final bool isSelected;
  final bool hasData;
  final int periodCount;
  final int lineCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderColor = isSelected ? AppColors.primary : scheme.outlineVariant.withValues(alpha: 0.7);
    final bg = isSelected
        ? AppColors.primary.withValues(alpha: 0.1)
        : scheme.surfaceContainerHighest.withValues(alpha: 0.45);

    return SizedBox(
      width: 132,
      height: 108,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: isSelected ? 1.6 : 1),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        kind.icon,
                        size: 18,
                        color: isSelected ? AppColors.primary : scheme.onSurfaceVariant,
                      ),
                      const Spacer(),
                      if (isSelected)
                        Icon(Icons.check_circle, size: 16, color: AppColors.primary),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    kind.label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: isSelected ? AppColors.primary : null,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Expanded(
                    child: Text(
                      kind.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.62),
                            height: 1.2,
                          ),
                    ),
                  ),
                  Text(
                    hasData
                        ? '$periodCount período${periodCount == 1 ? '' : 's'} · $lineCount linhas'
                        : 'Sem dados',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: hasData
                              ? scheme.onSurface.withValues(alpha: 0.55)
                              : scheme.error.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PeriodNavigator extends StatelessWidget {
  const _PeriodNavigator({
    required this.label,
    required this.index,
    required this.total,
    required this.isAnnual,
    required this.onPrevious,
    required this.onNext,
    required this.onSelectIndex,
    required this.periods,
  });

  final String label;
  final int index;
  final int total;
  final bool isAnnual;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<int> onSelectIndex;
  final List<FinancialPeriodDto> periods;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Período',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            IconButton(
              tooltip: 'Período anterior',
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left),
              visualDensity: VisualDensity.compact,
            ),
            Expanded(
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: () => _openPeriodSheet(context),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.expand_more,
                          size: 20,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Próximo período',
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        Center(
          child: Text(
            '${index + 1} de $total',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                ),
          ),
        ),
      ],
    );
  }

  Future<void> _openPeriodSheet(BuildContext context) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  'Escolha o período',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: periods.length,
                  itemBuilder: (context, i) {
                    final periodLabel = formatFinancialPeriod(periods[i].endDate, annual: isAnnual);
                    final selected = i == index;
                    return ListTile(
                      leading: Icon(
                        selected ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: selected ? AppColors.primary : null,
                      ),
                      title: Text(periodLabel),
                      subtitle: Text(
                        '${periods[i].lines.where((l) => l.value != null).length} linhas com valor',
                      ),
                      onTap: () => Navigator.pop(context, i),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
    if (picked != null) onSelectIndex(picked);
  }
}

class _StatementBody extends StatelessWidget {
  const _StatementBody({
    required this.kind,
    required this.period,
    required this.isAnnual,
    required this.showAllLines,
    required this.onToggleExpand,
  });

  final _StatementKind kind;
  final FinancialPeriodDto period;
  final bool isAnnual;
  final bool showAllLines;
  final VoidCallback onToggleExpand;

  List<FinancialLineDto> get _visibleLines =>
      period.lines.where((line) => line.value != null).toList();

  List<FinancialLineDto> _highlightLines() {
    final lines = _visibleLines;
    if (lines.isEmpty) return const [];

    final byKey = {for (final line in lines) line.key: line};
    final picked = <FinancialLineDto>[];
    for (final key in kind.highlightKeys) {
      final line = byKey[key];
      if (line != null) picked.add(line);
    }
    if (picked.length >= 3) return picked;

    return lines.take(4).toList();
  }

  List<FinancialLineDto> _remainingLines(List<FinancialLineDto> highlights) {
    final highlightKeys = highlights.map((line) => line.key).toSet();
    return _visibleLines.where((line) => !highlightKeys.contains(line.key)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final visibleLines = _visibleLines;
    if (visibleLines.isEmpty) {
      return Text(
        isAnnual ? 'Sem valores neste exercício.' : 'Sem valores neste trimestre.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    final highlights = _highlightLines();
    final remaining = _remainingLines(highlights);
    final hasMore = remaining.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(kind.icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                kind.fullName,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Principais indicadores',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              for (var i = 0; i < highlights.length; i++) ...[
                _StatementRow(line: highlights[i], emphasized: true),
                if (i < highlights.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
        if (hasMore) ...[
          const SizedBox(height: 10),
          Material(
            color: showAllLines
                ? AppColors.primary.withValues(alpha: 0.08)
                : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: onToggleExpand,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      showAllLines ? Icons.unfold_less : Icons.unfold_more,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            showAllLines
                                ? 'Ocultar linhas detalhadas'
                                : 'Ver todas as ${visibleLines.length} linhas',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                          ),
                          Text(
                            showAllLines
                                ? 'Mostrando o detalhamento completo'
                                : 'Mais ${remaining.length} conta${remaining.length == 1 ? '' : 's'} além do resumo',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.65),
                                ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      showAllLines ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        if (showAllLines && hasMore) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.6),
              ),
            ),
            child: Column(
              children: [
                for (var i = 0; i < remaining.length; i++) ...[
                  _StatementRow(line: remaining[i]),
                  if (i < remaining.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StatementRow extends StatelessWidget {
  const _StatementRow({required this.line, this.emphasized = false});

  final FinancialLineDto line;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final valueStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: emphasized ? AppColors.primaryDark : null,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              line.label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: emphasized ? FontWeight.w600 : FontWeight.w400,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Text(formatFinancialValue(line.value), style: valueStyle, textAlign: TextAlign.end),
        ],
      ),
    );
  }
}
