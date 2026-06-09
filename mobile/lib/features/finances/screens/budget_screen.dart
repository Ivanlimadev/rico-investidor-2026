import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/features/finances/data/finances_repository.dart';
import 'package:rico_investidor/features/finances/models/finance_models.dart';
import 'package:rico_investidor/features/finances/screens/transactions_screen.dart';
import 'package:rico_investidor/features/finances/utils/finance_category_mapper.dart';
import 'package:rico_investidor/features/finances/utils/finance_month.dart';
import 'package:rico_investidor/features/finances/widgets/budget_setup_wizard.dart';
import 'package:rico_investidor/features/finances/widgets/category_icon.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key, this.initialMonth});

  final String? initialMonth;

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final _repository = financesRepository;

  late String _month = widget.initialMonth ?? currentFinanceMonthKey;
  var _loading = true;
  String? _error;
  FinanceBudget? _budget;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final budget = await _repository.loadBudget(month: _month);
      if (!mounted) return;
      setState(() {
        _budget = budget;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível carregar o orçamento.';
        _loading = false;
      });
    }
  }

  void _shiftMonth(int delta) {
    setState(() => _month = shiftFinanceMonth(_month, delta));
    _load();
  }

  Future<void> _openWizard() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BudgetSetupWizard(
        month: _month,
        suggestedCategories: _budget?.categories ?? const [],
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _editLimit(FinanceBudgetCategory item) async {
    final controller = TextEditingController(
      text: item.limit > 0 ? item.limit.toStringAsFixed(2) : '',
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Limite — ${financeCategoryInfo(item.category).label}'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          decoration: const InputDecoration(
            prefixText: '\$ ',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (saved != true) return;

    final limit = double.tryParse(controller.text.replaceAll(',', '.')) ?? 0;
    final categories = List<FinanceBudgetCategory>.from(_budget?.categories ?? const []);
    final index = categories.indexWhere((c) => c.category == item.category);
    if (index >= 0) {
      categories[index] = FinanceBudgetCategory(
        category: item.category,
        limit: limit,
        spent: item.spent,
      );
    } else {
      categories.add(FinanceBudgetCategory(category: item.category, limit: limit, spent: item.spent));
    }

    try {
      final budget = await _repository.saveBudget(month: _month, categories: categories);
      if (!mounted) return;
      setState(() => _budget = budget);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao salvar limite')),
      );
    }
  }

  void _openCategoryTransactions(String category) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TransactionsScreen(initialCategory: category, initialMonth: _month),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = _budget?.categories ?? const [];
    final hasBudget = categories.any((item) => item.limit > 0);
    final totalLimit = categories.fold<double>(0, (sum, item) => sum + item.limit);
    final totalSpent = categories.fold<double>(0, (sum, item) => sum + item.spent);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orçamento'),
        actions: [
          IconButton(
            tooltip: 'Configurar',
            onPressed: _openWizard,
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openWizard,
        icon: const Icon(Icons.auto_fix_high),
        label: Text(hasBudget ? 'Reconfigurar' : 'Definir orçamento'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
                children: [
                  Row(
                    children: [
                      IconButton(onPressed: () => _shiftMonth(-1), icon: const Icon(Icons.chevron_left)),
                      Expanded(
                        child: Text(
                          financeMonthLabel(_month),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(onPressed: () => _shiftMonth(1), icon: const Icon(Icons.chevron_right)),
                    ],
                  ),
                  if (_error != null) ...[
                    Text(_error!),
                    const SizedBox(height: 12),
                  ],
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Você usou ${formatUsd(totalSpent)} de ${formatUsd(totalLimit)}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              minHeight: 10,
                              value: totalLimit > 0 ? (totalSpent / totalLimit).clamp(0, 1) : 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!hasBudget)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Text('Nenhum orçamento configurado para este mês.'),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _openWizard,
                              child: const Text('Iniciar assistente'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...categories.map((item) => _BudgetCategoryCard(
                          item: item,
                          onEditLimit: () => _editLimit(item),
                          onTap: () => _openCategoryTransactions(item.category),
                        )),
                ],
              ),
            ),
    );
  }
}

class _BudgetCategoryCard extends StatelessWidget {
  const _BudgetCategoryCard({
    required this.item,
    required this.onEditLimit,
    required this.onTap,
  });

  final FinanceBudgetCategory item;
  final VoidCallback onEditLimit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final info = financeCategoryInfo(item.category);
    final percent = item.limit > 0 ? (item.spent / item.limit).clamp(0.0, 1.2) : 0.0;
    final barColor = item.isOverBudget
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  FinanceCategoryIcon(category: item.category, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(info.label, style: Theme.of(context).textTheme.titleSmall),
                  ),
                  IconButton(
                    tooltip: 'Editar limite',
                    onPressed: onEditLimit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                  ),
                ],
              ),
              Text(
                '${formatUsd(item.spent)} / ${formatUsd(item.limit)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: item.isOverBudget ? Theme.of(context).colorScheme.error : null,
                      fontWeight: item.isOverBudget ? FontWeight.w700 : null,
                    ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: percent,
                  color: barColor,
                  backgroundColor: AppColors.positive.withValues(alpha: 0.12),
                ),
              ),
              if (item.isOverBudget)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Passou do limite em ${formatUsd(item.spent - item.limit)}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
