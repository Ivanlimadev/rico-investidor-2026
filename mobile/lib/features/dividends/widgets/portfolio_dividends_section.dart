import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/features/dividends/widgets/dividend_compact_card.dart';
import 'package:rico_investidor/features/dividends/widgets/dividend_period_chart.dart';
import 'package:rico_investidor/models/dividend_payment.dart';
import 'package:rico_investidor/services/portfolio_dividend_service.dart';
import 'package:rico_investidor/services/portfolio_storage.dart';
import 'package:rico_investidor/state/portfolio_state.dart';

class PortfolioDividendsSection extends StatefulWidget {
  const PortfolioDividendsSection({
    super.key,
    required this.portfolio,
    this.onPortfolioChanged,
  });

  final PortfolioState portfolio;
  final VoidCallback? onPortfolioChanged;

  @override
  State<PortfolioDividendsSection> createState() => _PortfolioDividendsSectionState();
}

class _PortfolioDividendsSectionState extends State<PortfolioDividendsSection> {
  DividendChartGranularity _granularity = DividendChartGranularity.month;
  bool _syncing = false;
  String? _syncError;

  @override
  void initState() {
    super.initState();
    _syncDividends();
  }

  Future<void> _syncDividends() async {
    setState(() {
      _syncing = true;
      _syncError = null;
    });

    final ok = await portfolioDividendService.syncPortfolioDividends(widget.portfolio);
    if (!mounted) return;

    setState(() {
      _syncing = false;
      if (!ok && widget.portfolio.holdings.isNotEmpty) {
        _syncError = 'Não foi possível carregar todos os proventos.';
      }
    });

    if (ok) {
      widget.onPortfolioChanged?.call();
      await PortfolioStorage().save(
        holdings: widget.portfolio.holdings,
        dividends: widget.portfolio.dividends,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthTotal = widget.portfolio.monthlyDividends;
    final monthItems = widget.portfolio.dividendsThisMonth();
    final chartPoints = widget.portfolio.chartPoints(_granularity);
    final chartTitle = _granularity == DividendChartGranularity.month
        ? 'Total por mês'
        : 'Total por ano';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Dividendos',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Atualizar proventos',
              onPressed: _syncing ? null : _syncDividends,
              icon: _syncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 22),
            ),
          ],
        ),
        const SizedBox(height: 8),
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
                  formatUsd(monthTotal),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Total convertido para US\$ (ativos BR via câmbio USD/BRL). '
                  'Proventos reais (API) × quantidade na carteira.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                ),
              ],
            ),
          ),
        ),
        if (_syncError != null) ...[
          const SizedBox(height: 12),
          Text(
            _syncError!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          chartTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 10),
        SegmentedButton<DividendChartGranularity>(
          segments: const [
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
        const SizedBox(height: 20),
        Text(
          'Proventos deste mês',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 10),
        if (_syncing && monthItems.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (monthItems.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Nenhum provento registrado neste mês para os ativos da carteira.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.88,
            ),
            itemCount: monthItems.length,
            itemBuilder: (context, index) {
              return DividendCompactCard(payment: monthItems[index]);
            },
          ),
      ],
    );
  }
}
