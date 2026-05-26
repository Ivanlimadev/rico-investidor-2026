import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/features/dividends/widgets/dividend_period_chart.dart';
import 'package:rico_investidor/models/dividend_payment.dart';
import 'package:rico_investidor/state/portfolio_state.dart';

void openDividendsScreen(
  BuildContext context, {
  required PortfolioState portfolio,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => DividendsScreen(portfolio: portfolio),
    ),
  );
}

class DividendsScreen extends StatefulWidget {
  const DividendsScreen({super.key, required this.portfolio});

  final PortfolioState portfolio;

  @override
  State<DividendsScreen> createState() => _DividendsScreenState();
}

class _DividendsScreenState extends State<DividendsScreen> {
  DividendChartGranularity _granularity = DividendChartGranularity.month;

  @override
  Widget build(BuildContext context) {
    final monthTotal = widget.portfolio.monthlyDividends;
    final monthItems = widget.portfolio.dividendsThisMonth();
    final chartPoints = widget.portfolio.chartPoints(_granularity);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dividendos'),
        actions: const [ShellHomeButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total no mês',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formatBrl(monthTotal),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Histórico',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          SegmentedButton<DividendChartGranularity>(
            segments: const [
              ButtonSegment(
                value: DividendChartGranularity.day,
                label: Text('Dia'),
                icon: Icon(Icons.today_outlined, size: 18),
              ),
              ButtonSegment(
                value: DividendChartGranularity.month,
                label: Text('Mês'),
                icon: Icon(Icons.calendar_month_outlined, size: 18),
              ),
              ButtonSegment(
                value: DividendChartGranularity.year,
                label: Text('Ano'),
                icon: Icon(Icons.date_range_outlined, size: 18),
              ),
            ],
            selected: {_granularity},
            onSelectionChanged: (set) {
              setState(() => _granularity = set.first);
            },
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
              child: DividendPeriodChart(points: chartPoints),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Proventos deste mês',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          if (monthItems.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Nenhum provento registrado neste mês.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          else
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < monthItems.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _DividendTile(payment: monthItems[i]),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DividendTile extends StatelessWidget {
  const _DividendTile({required this.payment});

  final DividendPayment payment;

  @override
  Widget build(BuildContext context) {
    final date =
        '${payment.date.day.toString().padLeft(2, '0')}/'
        '${payment.date.month.toString().padLeft(2, '0')}/'
        '${payment.date.year}';

    return ListTile(
      title: Text(payment.symbol),
      subtitle: Text('${payment.name} · $date'),
      trailing: Text(
        formatBrl(payment.amount),
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.positive,
        ),
      ),
    );
  }
}
