import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/asset_investment_simulation.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/models/fii_models.dart';

enum WhatIfInvestmentCurrency { brl, usd }

class WhatIfInvestmentCard extends StatefulWidget {
  const WhatIfInvestmentCard({
    super.key,
    required this.currentPrice,
    this.candles = const [],
    this.history = const [],
    this.payments = const [],
    this.currency = WhatIfInvestmentCurrency.brl,
    this.initialAmount = 1000,
    this.unitLabel = 'ação',
  });

  final double? currentPrice;
  final List<FiiCandleBar> candles;
  final List<FiiHistoryPoint> history;
  final List<FiiDistributionPayment> payments;
  final WhatIfInvestmentCurrency currency;
  final double initialAmount;
  final String unitLabel;

  @override
  State<WhatIfInvestmentCard> createState() => _WhatIfInvestmentCardState();
}

class _WhatIfInvestmentCardState extends State<WhatIfInvestmentCard> {
  WhatIfInvestmentPeriod _period = const WhatIfInvestmentPeriod.years(5);
  bool _reinvestDividends = true;

  bool get _isUsd => widget.currency == WhatIfInvestmentCurrency.usd;

  String _money(double value) => _isUsd ? formatUsd(value) : formatBrl(value);

  String get _amountLabel => _isUsd ? 'US\$ 1.000' : 'R\$ 1.000';

  int get _availableYears => maxSimulatableYearsFromSeries(
        candles: widget.candles,
        history: widget.history,
      );

  @override
  Widget build(BuildContext context) {
    final price = widget.currentPrice;
    if (price == null || price <= 0) return const SizedBox.shrink();
    if (widget.candles.isEmpty && widget.history.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Histórico insuficiente para simular “quanto teria investido”.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    final hasDividends = hasDividendPayments(widget.payments);
    final reinvest = hasDividends ? _reinvestDividends : false;
    final availablePeriods = simulatableWhatIfPeriods(
      initialAmount: widget.initialAmount,
      currentPrice: price,
      candles: widget.candles,
      history: widget.history,
      payments: widget.payments,
      reinvestDividends: reinvest,
    );

    if (availablePeriods.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Histórico insuficiente para simular períodos completos.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    final selectedPeriod = availablePeriods.contains(_period)
        ? _period
        : defaultWhatIfPeriodOption(availablePeriods);
    if (selectedPeriod != _period) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _period = selectedPeriod);
      });
    }

    final result = simulateAssetInvestmentForPeriod(
      period: selectedPeriod,
      initialAmount: widget.initialAmount,
      currentPrice: price,
      candles: widget.candles,
      history: widget.history,
      payments: widget.payments,
      reinvestDividends: reinvest,
    );

    if (result == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Se você tivesse investido',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Simulação com $_amountLabel em cotação histórica real'
              '${hasDividends ? ' e proventos pagos' : ''}.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
            ),
            const SizedBox(height: 16),
            Text('Há quanto tempo?', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availablePeriods.map((period) {
                final selected = selectedPeriod == period;
                return FilterChip(
                  label: Text(period.label),
                  selected: selected,
                  onSelected: (_) => setState(() => _period = period),
                );
              }).toList(),
            ),
            if (_availableYears > 0 &&
                availablePeriods.length < whatIfInvestmentPeriodOptions.length) ...[
              const SizedBox(height: 8),
              Text(
                'Histórico completo: até $_availableYears '
                '${_availableYears == 1 ? 'ano' : 'anos'}.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
            if (hasDividends) ...[
              const SizedBox(height: 16),
              Text('Proventos', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Sem reinvestir')),
                  ButtonSegment(value: true, label: Text('Reinvestir DY')),
                ],
                selected: {_reinvestDividends},
                onSelectionChanged: (values) {
                  setState(() => _reinvestDividends = values.first);
                },
              ),
            ],
            const SizedBox(height: 20),
            _HeroResult(
              result: result,
              amountLabel: _amountLabel,
              money: _money,
              reinvestNote: hasDividends && reinvest,
            ),
            const SizedBox(height: 16),
            _ResultPanel(
              result: result,
              money: _money,
              unitLabel: widget.unitLabel,
            ),
            const SizedBox(height: 12),
            Text(
              'Simulação educativa (estilo Investidor10). Não inclui taxas, IR, '
              'splits/desdobramentos nem aportes extras. Passado ≠ futuro.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
            ),
          ],
        ),
      ),
    );
  }

}

class _HeroResult extends StatelessWidget {
  const _HeroResult({
    required this.result,
    required this.amountLabel,
    required this.money,
    required this.reinvestNote,
  });

  final AssetInvestmentSimulationResult result;
  final String amountLabel;
  final String Function(double value) money;
  final bool reinvestNote;

  @override
  Widget build(BuildContext context) {
    final positive = result.profit >= 0;
    final color = positive ? AppColors.positive : AppColors.negative;
    final periodLabel = result.periodDisplayLabel;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Investindo $amountLabel há $periodLabel',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                ),
          ),
          const SizedBox(height: 10),
          Text(
            'hoje você teria',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            money(result.totalValue),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '${positive ? '+' : ''}${result.returnPct.toStringAsFixed(1)}% '
            '(${positive ? '+' : ''}${money(result.profit)})',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
          ),
          if (reinvestNote) ...[
            const SizedBox(height: 8),
            Text(
              '* O valor considera o reinvestimento dos dividendos.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({
    required this.result,
    required this.money,
    required this.unitLabel,
  });

  final AssetInvestmentSimulationResult result;
  final String Function(double value) money;
  final String unitLabel;

  @override
  Widget build(BuildContext context) {
    final positive = result.profit >= 0;
    final color = positive ? AppColors.positive : AppColors.negative;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (result.usedPartialHistory)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Dados completos só a partir de ${_formatDate(result.startDate)} — '
                'período efetivo: ${result.effectiveYears.toStringAsFixed(1)} anos.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ),
          _DetailRow(
            label: 'Compra em ${_formatDate(result.startDate)}',
            value:
                '${money(result.entryPrice)}/$unitLabel · ${result.shares.toStringAsFixed(2)} un.',
          ),
          if (result.reinvestDividends &&
              (result.finalShares - result.shares).abs() > 0.01) ...[
            _DetailRow(
              label: 'Posição final (com reinvest.)',
              value: '${result.finalShares.toStringAsFixed(2)} un.',
            ),
          ],
          const SizedBox(height: 8),
          _DetailRow(label: 'Valor hoje ($unitLabel)', value: money(result.currentValue)),
          if (result.dividendsReceived > 0)
            _DetailRow(
              label: result.reinvestDividends ? 'Proventos gerados' : 'Proventos recebidos',
              value: '${money(result.dividendsReceived)} (${result.paymentCount} pagtos)',
              valueColor: AppColors.positive,
            ),
          const Divider(height: 20),
          _DetailRow(
            label: 'Total estimado',
            value: money(result.totalValue),
            bold: true,
          ),
          _DetailRow(
            label: 'Lucro / prejuízo',
            value:
                '${positive ? '+' : ''}${money(result.profit)} (${result.returnPct.toStringAsFixed(1)}%)',
            valueColor: color,
            bold: true,
          ),
          if (result.dividendsReceived > 0) ...[
            const SizedBox(height: 10),
            _BreakdownBar(
              pricePct: result.priceReturnPct,
              dividendPct: result.dividendReturnPct,
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color: valueColor,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 8),
          Text(value, style: style, textAlign: TextAlign.end),
        ],
      ),
    );
  }
}

class _BreakdownBar extends StatelessWidget {
  const _BreakdownBar({required this.pricePct, required this.dividendPct});

  final double pricePct;
  final double dividendPct;

  @override
  Widget build(BuildContext context) {
    final total = (pricePct.abs() + dividendPct.abs()).clamp(0.001, double.infinity);
    final priceFlex = (pricePct.abs() / total * 100).round().clamp(1, 10000);
    final divFlex = (dividendPct.abs() / total * 100).round().clamp(1, 10000);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Composição do retorno', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                Expanded(
                  flex: priceFlex,
                  child: Container(color: AppColors.positive.withValues(alpha: 0.7)),
                ),
                Expanded(
                  flex: divFlex,
                  child: Container(color: const Color(0xFF2196F3)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                'Valorização ${pricePct.toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Text(
              'Proventos ${dividendPct.toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}
