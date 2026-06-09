import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/features/finances/data/finances_repository.dart';
import 'package:rico_investidor/features/finances/models/finance_models.dart';
import 'package:rico_investidor/features/finances/screens/transaction_detail_screen.dart';
import 'package:rico_investidor/features/finances/utils/finance_category_mapper.dart';
import 'package:rico_investidor/features/finances/utils/finance_month.dart';
import 'package:rico_investidor/features/finances/widgets/transaction_list_tile.dart';

enum _TransactionTypeFilter { all, expenses, income }

enum _TransactionPeriodFilter { thisMonth, lastMonth, last3Months }

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({
    super.key,
    this.initialCategory,
    this.initialMonth,
  });

  final String? initialCategory;
  final String? initialMonth;

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _repository = financesRepository;
  final _searchController = TextEditingController();

  var _loading = true;
  String? _error;
  List<FinanceTransaction> _transactions = const [];

  late String _month;
  late String? _category;
  _TransactionTypeFilter _typeFilter = _TransactionTypeFilter.all;
  _TransactionPeriodFilter _periodFilter = _TransactionPeriodFilter.thisMonth;
  var _filtersExpanded = false;
  var _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _month = widget.initialMonth ?? currentFinanceMonthKey;
    _category = widget.initialCategory;
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final month = _periodFilter == _TransactionPeriodFilter.last3Months ? null : _month;
      final items = await _repository.listTransactions(
        month: month,
        category: _category,
        limit: 300,
      );
      if (!mounted) return;
      setState(() {
        _transactions = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível carregar as transações.';
        _loading = false;
      });
    }
  }

  void _applyPeriod(_TransactionPeriodFilter period) {
    setState(() {
      _periodFilter = period;
      _month = switch (period) {
        _TransactionPeriodFilter.thisMonth => currentFinanceMonthKey,
        _TransactionPeriodFilter.lastMonth => shiftFinanceMonth(currentFinanceMonthKey, -1),
        _TransactionPeriodFilter.last3Months => currentFinanceMonthKey,
      };
      _filtersExpanded = false;
    });
    _load();
  }

  List<FinanceTransaction> get _filteredTransactions {
    final query = _searchQuery.trim().toLowerCase();
    return _transactions.where((tx) {
      if (_typeFilter == _TransactionTypeFilter.expenses && !tx.isExpense) return false;
      if (_typeFilter == _TransactionTypeFilter.income && !tx.isIncome) return false;
      if (_periodFilter == _TransactionPeriodFilter.last3Months) {
        final cutoff = financeMonthDate(shiftFinanceMonth(currentFinanceMonthKey, -2));
        if (tx.date.isBefore(DateTime(cutoff.year, cutoff.month, 1))) return false;
      }
      if (query.isEmpty) return true;
      final label = (tx.merchantName ?? tx.name).toLowerCase();
      return label.contains(query);
    }).toList();
  }

  Map<DateTime, List<FinanceTransaction>> get _groupedByDay {
    final grouped = <DateTime, List<FinanceTransaction>>{};
    for (final tx in _filteredTransactions) {
      final day = DateTime(tx.date.year, tx.date.month, tx.date.day);
      grouped.putIfAbsent(day, () => []).add(tx);
    }
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final key in sortedKeys) key: grouped[key]!};
  }

  Future<void> _openDetail(FinanceTransaction transaction) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TransactionDetailScreen(transaction: transaction),
      ),
    );
    if (changed == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transações'),
        actions: [
          IconButton(
            tooltip: 'Filtros',
            onPressed: () => setState(() => _filtersExpanded = !_filtersExpanded),
            icon: Icon(_filtersExpanded ? Icons.filter_alt : Icons.filter_alt_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_filtersExpanded) _FiltersPanel(
            month: _month,
            category: _category,
            typeFilter: _typeFilter,
            periodFilter: _periodFilter,
            onPeriodChanged: _applyPeriod,
            onCategoryChanged: (value) {
              setState(() => _category = value);
              _load();
            },
            onTypeChanged: (value) => setState(() => _typeFilter = value),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar merchant ou descrição',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _buildList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(_error!),
          ),
        ],
      );
    }

    final grouped = _groupedByDay;
    if (grouped.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          Center(child: Text('Nenhuma transação encontrada')),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final day = grouped.keys.elementAt(index);
        final items = grouped[day]!;
        final dayTotal = items.fold<double>(0, (sum, tx) => sum + tx.amount);
        final totalColor = dayTotal >= 0 ? AppColors.positive : Theme.of(context).colorScheme.error;
        final totalPrefix = dayTotal >= 0 ? '+' : '';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      financeDayHeader(day),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  Text(
                    '$totalPrefix${formatUsd(dayTotal.abs())}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: totalColor,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final tx in items)
                    FinanceTransactionListTile(
                      transaction: tx,
                      onTap: () => _openDetail(tx),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

class _FiltersPanel extends StatelessWidget {
  const _FiltersPanel({
    required this.month,
    required this.category,
    required this.typeFilter,
    required this.periodFilter,
    required this.onPeriodChanged,
    required this.onCategoryChanged,
    required this.onTypeChanged,
  });

  final String month;
  final String? category;
  final _TransactionTypeFilter typeFilter;
  final _TransactionPeriodFilter periodFilter;
  final ValueChanged<_TransactionPeriodFilter> onPeriodChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<_TransactionTypeFilter> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Período', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Este mês'),
                  selected: periodFilter == _TransactionPeriodFilter.thisMonth,
                  onSelected: (_) => onPeriodChanged(_TransactionPeriodFilter.thisMonth),
                ),
                ChoiceChip(
                  label: const Text('Mês passado'),
                  selected: periodFilter == _TransactionPeriodFilter.lastMonth,
                  onSelected: (_) => onPeriodChanged(_TransactionPeriodFilter.lastMonth),
                ),
                ChoiceChip(
                  label: const Text('3 meses'),
                  selected: periodFilter == _TransactionPeriodFilter.last3Months,
                  onSelected: (_) => onPeriodChanged(_TransactionPeriodFilter.last3Months),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(financeMonthLabel(month), style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Text('Tipo', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<_TransactionTypeFilter>(
              segments: const [
                ButtonSegment(value: _TransactionTypeFilter.all, label: Text('Todos')),
                ButtonSegment(value: _TransactionTypeFilter.expenses, label: Text('Gastos')),
                ButtonSegment(value: _TransactionTypeFilter.income, label: Text('Receitas')),
              ],
              selected: {typeFilter},
              onSelectionChanged: (value) => onTypeChanged(value.first),
            ),
            const SizedBox(height: 12),
            Text('Categoria', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              initialValue: category,
              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todas')),
                for (final info in selectableFinanceCategories)
                  DropdownMenuItem(value: info.key, child: Text(info.label)),
              ],
              onChanged: onCategoryChanged,
            ),
          ],
        ),
      ),
    );
  }
}
