import 'package:flutter/material.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/features/quotes/models/stock_financials.dart';

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

class _StockFinancialsCardState extends State<StockFinancialsCard>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late Future<StockFinancialsDto> _loadFuture;
  int _periodIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _periodIndex = 0);
      }
    });
    _loadFuture = widget.repository.getStockFinancials(widget.ticker);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final financials = snapshot.data!;
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Demonstrações trimestrais', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: const [
                    Tab(text: 'DRE'),
                    Tab(text: 'Balanço'),
                    Tab(text: 'Fluxo de caixa'),
                  ],
                ),
                const SizedBox(height: 8),
                AnimatedBuilder(
                  animation: _tabController,
                  builder: (context, _) {
                    final periods = switch (_tabController.index) {
                      0 => financials.incomeStatement,
                      1 => financials.balanceSheet,
                      _ => financials.cashFlow,
                    };
                    if (periods.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Sem dados para esta demonstração.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      );
                    }

                    final safeIndex = _periodIndex.clamp(0, periods.length - 1);
                    if (safeIndex != _periodIndex) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _periodIndex = safeIndex);
                      });
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 36,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: periods.length,
                            separatorBuilder: (context, index) => const SizedBox(width: 6),
                            itemBuilder: (context, index) {
                              final period = periods[index];
                              return FilterChip(
                                label: Text(formatFinancialPeriod(period.endDate)),
                                selected: safeIndex == index,
                                onSelected: (_) => setState(() => _periodIndex = index),
                                visualDensity: VisualDensity.compact,
                                showCheckmark: false,
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        _StatementTable(period: periods[safeIndex]),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatementTable extends StatelessWidget {
  const _StatementTable({required this.period});

  final FinancialPeriodDto period;

  @override
  Widget build(BuildContext context) {
    final visibleLines = period.lines.where((line) => line.value != null).toList();
    if (visibleLines.isEmpty) {
      return Text(
        'Sem valores neste trimestre.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return Column(
      children: [
        for (var i = 0; i < visibleLines.length; i++) ...[
          _StatementRow(line: visibleLines[i]),
          if (i < visibleLines.length - 1) const Divider(height: 1),
        ],
      ],
    );
  }
}

class _StatementRow extends StatelessWidget {
  const _StatementRow({required this.line});

  final FinancialLineDto line;

  @override
  Widget build(BuildContext context) {
    final valueStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(line.label, style: Theme.of(context).textTheme.bodyMedium)),
          const SizedBox(width: 12),
          Text(formatFinancialValue(line.value), style: valueStyle, textAlign: TextAlign.end),
        ],
      ),
    );
  }
}
