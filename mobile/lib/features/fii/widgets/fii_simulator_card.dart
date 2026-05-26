import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/core/utils/parse_decimal.dart';
import 'package:rico_investidor/features/fii/utils/fii_simulation.dart';
import 'package:rico_investidor/models/fii_models.dart';

class FiiSimulatorCard extends StatefulWidget {
  const FiiSimulatorCard({
    super.key,
    required this.detail,
    required this.history,
    required this.payments,
  });

  final FiiDetail detail;
  final List<FiiHistoryPoint> history;
  final List<FiiDistributionPayment> payments;

  @override
  State<FiiSimulatorCard> createState() => _FiiSimulatorCardState();
}

class _FiiSimulatorCardState extends State<FiiSimulatorCard> {
  final _amountController = TextEditingController(text: '10000');
  int _years = 3;
  bool _reinvestDividends = false;
  FiiSimulationResult? _result;

  @override
  void initState() {
    super.initState();
    _recalculate();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  static const _yearOptions = [1, 2, 3, 5, 10, 15];

  int get _historyYears {
    final max = maxSimulatableYears(widget.history);
    if (max <= 0) return 1;
    return max;
  }

  void _recalculate() {
    final amount = parseDecimalInput(_amountController.text) ?? 0;
    setState(() {
      _result = simulateFiiInvestment(
        amount: amount,
        years: _years,
        detail: widget.detail,
        history: widget.history,
        payments: widget.payments,
        reinvestDividends: _reinvestDividends,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.history.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Histórico insuficiente para simular investimentos passados.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    if (!_yearOptions.contains(_years)) {
      _years = _yearOptions.last;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Simule quanto teria hoje se tivesse investido no passado. '
              'Usa cotação histórica mensal + proventos reais pagos no período.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d,.]'))],
              decoration: const InputDecoration(
                labelText: 'Valor investido (R\$)',
                border: OutlineInputBorder(),
                prefixText: 'R\$ ',
              ),
              onChanged: (_) => _recalculate(),
            ),
            const SizedBox(height: 16),
            Text('Há quanto tempo?', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _yearOptions.map((y) {
                final selected = _years == y;
                return FilterChip(
                  label: Text('${y}a'),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _years = y);
                    _recalculate();
                  },
                );
              }).toList(),
            ),
            if (_historyYears < 15) ...[
              const SizedBox(height: 8),
              Text(
                'Cotação histórica disponível: até $_historyYears '
                '${_historyYears == 1 ? 'ano' : 'anos'}. '
                'Períodos maiores usam o máximo disponível.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            Text('Proventos', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Sem reinvestir')),
                ButtonSegment(value: true, label: Text('Reinvestir')),
              ],
              selected: {_reinvestDividends},
              onSelectionChanged: (values) {
                setState(() => _reinvestDividends = values.first);
                _recalculate();
              },
            ),
            const SizedBox(height: 4),
            Text(
              _reinvestDividends
                  ? 'Cada provento compra mais cotas na cotação do mês do pagamento.'
                  : 'Proventos acumulados em caixa, sem comprar novas cotas.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_result != null) ...[
              const SizedBox(height: 20),
              _ResultPanel(result: _result!),
            ],
            const SizedBox(height: 12),
            Text(
              'Simulação educativa. Não inclui taxas, IR, compras fracionadas '
              'ou aportes extras. Passado não garante resultados futuros.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.result});

  final FiiSimulationResult result;

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
          _Row(
            label: 'Compra em ${_formatDate(result.startDate)}',
            value: '${formatBrl(result.entryPrice)}/cota · ${result.shares.toStringAsFixed(2)} cotas',
          ),
          if (result.reinvestDividends && (result.finalShares - result.shares).abs() > 0.01) ...[
            _Row(
              label: 'Cotas finais (com reinvest.)',
              value: result.finalShares.toStringAsFixed(2),
            ),
          ],
          const SizedBox(height: 8),
          _Row(label: 'Valor hoje (cota)', value: formatBrl(result.currentValue)),
          _Row(
            label: result.reinvestDividends ? 'Proventos gerados' : 'Proventos recebidos',
            value: '${formatBrl(result.dividendsReceived)} (${result.paymentCount} pagtos)',
            valueColor: AppColors.positive,
          ),
          const Divider(height: 20),
          _Row(
            label: 'Total estimado',
            value: formatBrl(result.totalValue),
            bold: true,
          ),
          _Row(
            label: 'Lucro / prejuízo',
            value: '${positive ? '+' : ''}${formatBrl(result.profit)} (${result.returnPct.toStringAsFixed(1)}%)',
            valueColor: color,
            bold: true,
          ),
          const SizedBox(height: 10),
          _BreakdownBar(
            pricePct: result.priceReturnPct,
            dividendPct: result.dividendReturnPct,
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

class _Row extends StatelessWidget {
  const _Row({
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
                Expanded(flex: priceFlex, child: Container(color: AppColors.positive.withValues(alpha: 0.7))),
                Expanded(flex: divFlex, child: Container(color: const Color(0xFF2196F3))),
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
