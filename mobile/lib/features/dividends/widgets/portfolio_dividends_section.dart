import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/core/markets/supported_market_countries.dart';
import 'package:rico_investidor/features/dividends/widgets/dividend_compact_card.dart';
import 'package:rico_investidor/features/dividends/widgets/dividend_period_chart.dart';
import 'package:rico_investidor/models/dividend_payment.dart';
import 'package:rico_investidor/models/holding_currency.dart';
import 'package:rico_investidor/services/market_preference_storage.dart';
import 'package:rico_investidor/services/portfolio_dividend_service.dart';
import 'package:rico_investidor/services/portfolio_storage.dart';
import 'package:rico_investidor/state/portfolio_state.dart';

class PortfolioDividendsSection extends StatefulWidget {
  const PortfolioDividendsSection({
    super.key,
    required this.portfolio,
    required this.preferredMarket,
    this.onPortfolioChanged,
  });

  final PortfolioState portfolio;
  final MarketPreference preferredMarket;
  final VoidCallback? onPortfolioChanged;

  @override
  State<PortfolioDividendsSection> createState() => _PortfolioDividendsSectionState();
}

class _PortfolioDividendsSectionState extends State<PortfolioDividendsSection> {
  DividendChartGranularity _granularity = DividendChartGranularity.month;
  bool _syncing = false;
  String? _syncError;
  int _syncGeneration = 0;

  @override
  void initState() {
    super.initState();
    final hasCached = widget.portfolio.dividends.isNotEmpty;
    _syncDividends(showBlockingLoader: !hasCached);
  }

  @override
  void didUpdateWidget(PortfolioDividendsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_holdingsSignature(oldWidget.portfolio) != _holdingsSignature(widget.portfolio)) {
      _syncDividends(showBlockingLoader: widget.portfolio.dividends.isEmpty);
    }
  }

  String _holdingsSignature(PortfolioState portfolio) {
    final parts = portfolio.holdings
        .map((h) => '${h.symbol}:${h.quantity}')
        .toList()
      ..sort();
    return parts.join('|');
  }

  Future<void> _syncDividends({bool showBlockingLoader = false}) async {
    final generation = ++_syncGeneration;

    if (showBlockingLoader) {
      setState(() {
        _syncing = true;
        _syncError = null;
      });
    } else {
      setState(() => _syncError = null);
    }

    try {
      final result = await portfolioDividendService.syncPortfolioDividends(widget.portfolio);
      if (!mounted || generation != _syncGeneration) return;

      final holdingsCount = widget.portfolio.holdings.length;
      final allFailed = holdingsCount > 0 && result.failedSymbols.length >= holdingsCount;

      setState(() {
        _syncing = false;
        if (allFailed) {
          _syncError = 'Não foi possível carregar os proventos. Verifique a conexão e tente de novo.';
        } else if (result.failedSymbols.isNotEmpty) {
          _syncError =
              'Proventos parciais: não foi possível atualizar ${result.failedSymbols.join(', ')}.';
        } else {
          _syncError = null;
        }
      });

      if (result.completed) {
        widget.onPortfolioChanged?.call();
        await PortfolioStorage().save(
          holdings: widget.portfolio.holdings,
          dividends: widget.portfolio.dividends,
        );
      }
    } catch (_) {
      if (!mounted || generation != _syncGeneration) return;
      setState(() {
        _syncing = false;
        _syncError = 'Não foi possível carregar os proventos. Verifique a conexão e tente de novo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.preferredMarket.isBrazil
        ? HoldingCurrency.brl
        : HoldingCurrency.usd;
    final monthTotal = widget.portfolio.monthlyDividendsFor(widget.preferredMarket);
    final monthItems = widget.portfolio.dividendsThisMonth();
    final chartPoints = widget.portfolio.chartPointsFor(_granularity, widget.preferredMarket);
    final breakdown = widget.portfolio.computeBalanceBreakdown();
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
              onPressed: _syncing ? null : () => _syncDividends(showBlockingLoader: false),
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
                  currency.format(monthTotal),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.preferredMarket.isBrazil
                      ? 'Total de proventos × quantidade na carteira. BDRs e B3 em reais; '
                          'ativos EUA convertidos pelo USD/BRL.'
                      : 'Dividend totals × shares held. US assets in US\$; '
                          'Brazil holdings converted at USD/BRL.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                ),
                if (breakdown.hasInternational && widget.preferredMarket.isBrazil) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Internacional (US\$): ${formatUsd(widget.portfolio.monthlyDividendsFor(defaultMarketPreference))}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1565C0),
                        ),
                  ),
                ],
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
        if (monthItems.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                _syncing
                    ? 'Atualizando proventos da carteira…'
                    : 'Nenhum provento registrado neste mês para os ativos da carteira.',
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
