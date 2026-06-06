import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/asset_investment_simulation.dart';
import 'package:rico_investidor/core/utils/asset_returns.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/core/utils/parse_decimal.dart';
import 'package:rico_investidor/models/fii_models.dart';

enum WhatIfInvestmentCurrency { brl, usd }

const _defaultAmount = 1000.0;
const _amountPresets = [1000.0, 5000.0, 10000.0];

class WhatIfInvestmentCard extends StatefulWidget {
  const WhatIfInvestmentCard({
    super.key,
    required this.currentPrice,
    this.candles = const [],
    this.history = const [],
    this.payments = const [],
    this.currency = WhatIfInvestmentCurrency.brl,
    this.initialAmount = _defaultAmount,
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
  late final TextEditingController _amountController;

  AssetPriceTimeline? _timeline;
  List<WhatIfInvestmentPeriod> _availablePeriods = const [];
  AssetInvestmentSimulationResult? _resultWithoutReinvest;
  AssetInvestmentSimulationResult? _resultWithReinvest;

  bool get _isUsd => widget.currency == WhatIfInvestmentCurrency.usd;

  String get _currencyPrefix => _isUsd ? 'US\$ ' : 'R\$ ';

  double get _simulationAmount {
    final parsed = parseDecimalInput(_amountController.text);
    if (parsed == null || parsed <= 0) return widget.initialAmount;
    return parsed;
  }

  String _money(double value) => _isUsd ? formatUsd(value) : formatBrl(value);

  int get _availableYears => maxSimulatableYearsFromSeries(
        candles: widget.candles,
        history: widget.history,
      );

  @override
  void initState() {
    super.initState();
    final initial = widget.initialAmount > 0 ? widget.initialAmount : _defaultAmount;
    _amountController = TextEditingController(
      text: initial == initial.roundToDouble()
          ? initial.toInt().toString()
          : initial.toStringAsFixed(2),
    );
    _rebuildSimulation();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant WhatIfInvestmentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPrice != widget.currentPrice ||
        oldWidget.candles != widget.candles ||
        oldWidget.history != widget.history ||
        oldWidget.payments != widget.payments) {
      setState(_rebuildSimulation);
    }
  }

  bool get _hasDividends => hasDividendPayments(widget.payments);

  void _rebuildSimulation() {
    final price = widget.currentPrice;
    final amount = _simulationAmount;
    if (price == null || price <= 0 || amount <= 0) {
      _timeline = null;
      _availablePeriods = const [];
      _resultWithoutReinvest = null;
      _resultWithReinvest = null;
      return;
    }
    if (widget.candles.isEmpty && widget.history.isEmpty) {
      _timeline = null;
      _availablePeriods = const [];
      _resultWithoutReinvest = null;
      _resultWithReinvest = null;
      return;
    }

    final timeline = AssetPriceTimeline.from(
      candles: widget.candles,
      history: widget.history,
    );
    if (timeline.isEmpty) {
      _timeline = null;
      _availablePeriods = const [];
      _resultWithoutReinvest = null;
      _resultWithReinvest = null;
      return;
    }

    final periods = simulatableWhatIfPeriods(
      initialAmount: amount,
      currentPrice: price,
      candles: widget.candles,
      history: widget.history,
      payments: widget.payments,
      reinvestDividends: false,
    );

    final selectedPeriod = periods.contains(_period)
        ? _period
        : defaultWhatIfPeriodOption(periods);

    _timeline = timeline;
    _availablePeriods = periods;
    _period = selectedPeriod;
    _applyResults(selectedPeriod, price, timeline, amount);
  }

  void _applyResults(
    WhatIfInvestmentPeriod period,
    double price,
    AssetPriceTimeline timeline,
    double amount,
  ) {
    _resultWithoutReinvest = _simulate(
      period: period,
      amount: amount,
      price: price,
      timeline: timeline,
      reinvestDividends: false,
    );
    _resultWithReinvest = _hasDividends
        ? _simulate(
            period: period,
            amount: amount,
            price: price,
            timeline: timeline,
            reinvestDividends: true,
          )
        : null;
  }

  AssetInvestmentSimulationResult? _simulate({
    required WhatIfInvestmentPeriod period,
    required double amount,
    required double price,
    required AssetPriceTimeline timeline,
    required bool reinvestDividends,
  }) {
    return simulateAssetInvestmentForPeriod(
      period: period,
      initialAmount: amount,
      currentPrice: price,
      candles: widget.candles,
      history: widget.history,
      payments: widget.payments,
      reinvestDividends: reinvestDividends,
      timeline: timeline,
    );
  }

  void _onPeriodChanged(WhatIfInvestmentPeriod period) {
    final price = widget.currentPrice;
    final timeline = _timeline;
    final amount = _simulationAmount;
    if (price == null || timeline == null || amount <= 0) return;
    setState(() {
      _period = period;
      _applyResults(period, price, timeline, amount);
    });
  }

  void _onAmountChanged() => setState(_rebuildSimulation);

  void _applyPreset(double value) {
    _amountController.text = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
    _onAmountChanged();
  }

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

    final availablePeriods = _availablePeriods;
    final cashResult = _resultWithoutReinvest;
    final reinvestResult = _resultWithReinvest;

    if (availablePeriods.isEmpty || cashResult == null) {
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
              'Simulação com cotação histórica real'
              '${_hasDividends ? ' e proventos pagos no período' : ''}. '
              'Compare o patrimônio com e sem reinvestir proventos.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
            ),
            const SizedBox(height: 16),
            Text('Quanto investir?', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d,.]'))],
              decoration: InputDecoration(
                labelText: _isUsd ? 'Valor em dólares' : 'Valor em reais',
                border: const OutlineInputBorder(),
                prefixText: _currencyPrefix,
                isDense: true,
              ),
              onChanged: (_) => _onAmountChanged(),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _amountPresets.map((preset) {
                final selected = _simulationAmount == preset;
                final label = _money(preset);
                return FilterChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) => _applyPreset(preset),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text('Há quanto tempo?', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availablePeriods.map((period) {
                final selected = _period == period;
                return ChoiceChip(
                  label: Text(period.label),
                  selected: selected,
                  onSelected: (value) {
                    if (value) _onPeriodChanged(period);
                  },
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
            const SizedBox(height: 16),
            _PurchaseContextBanner(
              result: cashResult,
              money: _money,
              unitLabel: widget.unitLabel,
              investedAmount: _simulationAmount,
            ),
            const SizedBox(height: 14),
            if (_hasDividends && reinvestResult != null) ...[
              _ScenarioCard(
                title: 'Sem reinvestir',
                subtitle: 'Proventos ficam em caixa, separados das ações',
                result: cashResult,
                money: _money,
                unitLabel: widget.unitLabel,
                showCashBreakdown: true,
              ),
              const SizedBox(height: 12),
              _ScenarioCard(
                title: 'Reinvestindo proventos',
                subtitle: 'Cada provento compra mais ${widget.unitLabel}s na data do pagamento',
                result: reinvestResult,
                money: _money,
                unitLabel: widget.unitLabel,
                showCashBreakdown: false,
              ),
            ] else
              _ScenarioCard(
                title: 'Resultado hoje',
                subtitle: 'Valorização da posição no período',
                result: cashResult,
                money: _money,
                unitLabel: widget.unitLabel,
                showCashBreakdown: false,
              ),
            const SizedBox(height: 12),
            Text(
              'Simulação educativa com histórico ajustado quando disponível. '
              'Não inclui taxas, IR nem novos aportes. Passado ≠ futuro.',
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

class _PurchaseContextBanner extends StatelessWidget {
  const _PurchaseContextBanner({
    required this.result,
    required this.money,
    required this.unitLabel,
    required this.investedAmount,
  });

  final AssetInvestmentSimulationResult result;
  final String Function(double value) money;
  final String unitLabel;
  final double investedAmount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Cenário: ${money(investedAmount)} há ${result.heroPeriodLabel}',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (result.usedPartialHistory) ...[
            const SizedBox(height: 4),
            Text(
              'Histórico disponível só a partir de ${_formatDate(result.startDate)}.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Em ${_formatDate(result.startDate)} você compraria '
            '${result.shares.toStringAsFixed(2)} ${unitLabel}s a '
            '${money(result.entryPrice)} cada.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                ),
          ),
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

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({
    required this.title,
    required this.subtitle,
    required this.result,
    required this.money,
    required this.unitLabel,
    required this.showCashBreakdown,
  });

  final String title;
  final String subtitle;
  final AssetInvestmentSimulationResult result;
  final String Function(double value) money;
  final String unitLabel;
  final bool showCashBreakdown;

  @override
  Widget build(BuildContext context) {
    final positive = result.profit >= 0;
    final color = positive ? AppColors.positive : AppColors.negative;
    final extraShares = result.finalShares - result.shares;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                ),
          ),
          const SizedBox(height: 14),
          if (showCashBreakdown) ...[
            _LineItem(
              label: 'Valor das ${unitLabel}s hoje',
              value: money(result.currentValue),
              hint: '${result.shares.toStringAsFixed(2)} un. × ${money(result.currentPrice)}',
            ),
            if (result.dividendsReceived > 0)
              _LineItem(
                label: 'Proventos em caixa',
                value: money(result.dividendsReceived),
                hint: '${result.paymentCount} pagamentos no período',
                valueColor: AppColors.positive,
              ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1),
            ),
            _LineItem(
              label: 'Patrimônio total',
              value: money(result.totalValue),
              hint: 'Ações + proventos em caixa',
              emphasized: true,
            ),
          ] else if (result.reinvestDividends) ...[
            _LineItem(
              label: 'Posição inicial → final',
              value:
                  '${result.shares.toStringAsFixed(2)} → ${result.finalShares.toStringAsFixed(2)} un.',
              hint: extraShares > 0.01
                  ? '+${extraShares.toStringAsFixed(2)} un. com reinvestimento'
                  : null,
            ),
            if (result.dividendsReceived > 0)
              _LineItem(
                label: 'Proventos reinvestidos',
                value: money(result.dividendsReceived),
                hint: 'Somados à posição, não ficam em caixa',
                valueColor: AppColors.positive,
              ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1),
            ),
            _LineItem(
              label: 'Patrimônio total',
              value: money(result.totalValue),
              hint: 'Só o valor das ${unitLabel}s (proventos já viraram cotas)',
              emphasized: true,
            ),
          ] else ...[
            _LineItem(
              label: 'Valor das ${unitLabel}s hoje',
              value: money(result.currentValue),
              hint: '${result.shares.toStringAsFixed(2)} un. × ${money(result.currentPrice)}',
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1),
            ),
            _LineItem(
              label: 'Patrimônio total',
              value: money(result.totalValue),
              emphasized: true,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Lucro / prejuízo',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              Text(
                '${positive ? '+' : ''}${money(result.profit)} '
                '(${result.returnPct.toStringAsFixed(1)}%)',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
              ),
            ],
          ),
          if (showCashBreakdown && result.dividendsReceived > 0) ...[
            const SizedBox(height: 12),
            _BreakdownBar(
              pricePct: result.priceReturnPct,
              dividendPct: result.dividendReturnPct,
            ),
          ],
        ],
      ),
    );
  }
}

class _LineItem extends StatelessWidget {
  const _LineItem({
    required this.label,
    required this.value,
    this.hint,
    this.valueColor,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final String? hint;
  final Color? valueColor;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final valueStyle = emphasized
        ? Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: valueColor ?? Theme.of(context).colorScheme.primary,
            )
        : Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor,
            );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              Text(value, style: valueStyle, textAlign: TextAlign.end),
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(
              hint!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
            ),
          ],
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
        Text('De onde veio o retorno', style: Theme.of(context).textTheme.labelMedium),
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
