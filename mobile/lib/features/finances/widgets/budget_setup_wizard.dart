import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/features/finances/data/finances_repository.dart';
import 'package:rico_investidor/features/finances/models/finance_models.dart';
import 'package:rico_investidor/features/finances/utils/finance_category_mapper.dart';
import 'package:rico_investidor/features/finances/utils/finance_month.dart';

class BudgetSetupWizard extends StatefulWidget {
  const BudgetSetupWizard({
    super.key,
    required this.month,
    this.suggestedCategories = const [],
  });

  final String month;
  final List<FinanceBudgetCategory> suggestedCategories;

  @override
  State<BudgetSetupWizard> createState() => _BudgetSetupWizardState();
}

class _BudgetSetupWizardState extends State<BudgetSetupWizard> {
  final _incomeController = TextEditingController();
  final _fixedController = TextEditingController();
  var _step = 0;
  var _savingsPercent = 10.0;
  var _saving = false;

  @override
  void dispose() {
    _incomeController.dispose();
    _fixedController.dispose();
    super.dispose();
  }

  double? get _income => double.tryParse(_incomeController.text.replaceAll(',', '.'));

  Future<void> _finish() async {
    final income = _income;
    if (income == null || income <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe uma renda mensal válida')),
      );
      return;
    }

    final fixed = double.tryParse(_fixedController.text.replaceAll(',', '.')) ?? 0;
    final savings = income * (_savingsPercent / 100);
    final variablePool = (income - fixed - savings).clamp(0, income);

    final categories = <FinanceBudgetCategory>[];
    if (fixed > 0) {
      categories.add(FinanceBudgetCategory(category: 'housing', limit: fixed * 0.6, spent: 0));
      categories.add(FinanceBudgetCategory(category: 'fees', limit: fixed * 0.2, spent: 0));
      categories.add(FinanceBudgetCategory(category: 'entertainment', limit: fixed * 0.2, spent: 0));
    }

    final variableKeys = ['food_drink', 'transportation', 'shopping', 'health', 'other'];
    final perCategory = variablePool / variableKeys.length;
    for (final key in variableKeys) {
      categories.add(FinanceBudgetCategory(category: key, limit: perCategory, spent: 0));
    }

    if (savings > 0) {
      categories.add(FinanceBudgetCategory(category: 'income', limit: savings, spent: 0));
    }

    for (final suggested in widget.suggestedCategories) {
      final index = categories.indexWhere((item) => item.category == suggested.category);
      if (index >= 0) {
        categories[index] = FinanceBudgetCategory(
          category: suggested.category,
          limit: suggested.spent > 0 ? suggested.spent * 1.1 : categories[index].limit,
          spent: suggested.spent,
        );
      }
    }

    setState(() => _saving = true);
    try {
      await financesRepository.saveBudget(month: widget.month, categories: categories);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao salvar orçamento')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.86;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Configurar orçamento',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                financeMonthLabel(widget.month),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: (_step + 1) / 3),
              const SizedBox(height: 20),
              Expanded(child: _buildStep()),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (_step > 0)
                    TextButton(
                      onPressed: _saving ? null : () => setState(() => _step--),
                      child: const Text('Voltar'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _saving
                        ? null
                        : () {
                            if (_step < 2) {
                              setState(() => _step++);
                              return;
                            }
                            _finish();
                          },
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_step < 2 ? 'Continuar' : 'Salvar orçamento'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    return switch (_step) {
      0 => _StepIncome(controller: _incomeController),
      1 => _StepFixedCosts(controller: _fixedController, income: _income),
      _ => _StepSavings(
          income: _income ?? 0,
          percent: _savingsPercent,
          onChanged: (value) => setState(() => _savingsPercent = value),
        ),
    };
  }
}

class _StepIncome extends StatelessWidget {
  const _StepIncome({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Qual é sua renda mensal?', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          decoration: const InputDecoration(
            prefixText: '\$ ',
            labelText: 'Renda mensal',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
      ],
    );
  }
}

class _StepFixedCosts extends StatelessWidget {
  const _StepFixedCosts({required this.controller, required this.income});

  final TextEditingController controller;
  final double? income;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Seus gastos fixos', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Aluguel, internet, assinaturas e contas recorrentes.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          decoration: const InputDecoration(
            prefixText: '\$ ',
            labelText: 'Total de fixos',
            border: OutlineInputBorder(),
          ),
        ),
        if (income != null) ...[
          const SizedBox(height: 12),
          Text(
            'Sobra ${formatUsd((income! - (double.tryParse(controller.text.replaceAll(',', '.')) ?? 0)).clamp(0, income!))} para variáveis e poupança',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _StepSavings extends StatelessWidget {
  const _StepSavings({
    required this.income,
    required this.percent,
    required this.onChanged,
  });

  final double income;
  final double percent;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final savings = income * (percent / 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quanto quer poupar?', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Slider(
          value: percent,
          min: 0,
          max: 50,
          divisions: 10,
          label: '${percent.round()}%',
          onChanged: onChanged,
        ),
        Text(
          'Meta de poupança: ${formatUsd(savings)} (${percent.round()}% da renda)',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        Text(
          'Sugerimos limites por categoria com base nos seus gastos recentes.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        for (final info in selectableFinanceCategories.take(4))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Text(info.emoji),
            title: Text(info.label),
          ),
      ],
    );
  }
}
