import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/features/finances/data/finances_repository.dart';
import 'package:rico_investidor/features/finances/models/finance_models.dart';
import 'package:rico_investidor/features/finances/screens/transaction_detail_screen.dart';
import 'package:rico_investidor/features/finances/utils/finance_month.dart';
import 'package:rico_investidor/features/finances/widgets/transaction_list_tile.dart';

enum _AccountTransactionFilter { all, expenses, income }

class AccountDetailScreen extends StatefulWidget {
  const AccountDetailScreen({
    super.key,
    required this.account,
  });

  final PlaidAccount account;

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen> {
  final _repository = financesRepository;
  final _searchController = TextEditingController();

  var _loading = true;
  var _deleting = false;
  String? _error;
  List<FinanceTransaction> _transactions = const [];
  _AccountTransactionFilter _typeFilter = _AccountTransactionFilter.all;
  var _searchQuery = '';

  @override
  void initState() {
    super.initState();
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
      final items = await _repository.listTransactions(limit: 300);
      if (!mounted) return;
      setState(() {
        _transactions = items.where((tx) => tx.accountId == widget.account.id).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load transactions.';
        _loading = false;
      });
    }
  }

  List<FinanceTransaction> get _filteredTransactions {
    final query = _searchQuery.trim().toLowerCase();
    return _transactions.where((tx) {
      if (_typeFilter == _AccountTransactionFilter.expenses && !tx.isExpense) return false;
      if (_typeFilter == _AccountTransactionFilter.income && !tx.isIncome) return false;
      if (query.isEmpty) return true;
      final label = (tx.merchantName ?? tx.name).toLowerCase();
      return label.contains(query);
    }).toList();
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove account'),
        content: Text(
          'Remove ${widget.account.name} (•••• ${widget.account.mask}) from Rico Investidor?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await _repository.deleteAccount(widget.account.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not remove account')),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
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
    final account = widget.account;

    return Scaffold(
      appBar: AppBar(
        title: Text(account.name),
        actions: [
          IconButton(
            tooltip: 'Remove account',
            onPressed: _deleting ? null : _confirmDeleteAccount,
            icon: _deleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(account.institutionName, style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 4),
                    Text('•••• ${account.mask} · ${account.type}'),
                    const SizedBox(height: 12),
                    Text(
                      formatUsd(account.currentBalance),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (account.availableBalance != null)
                      Text(
                        'Available ${formatUsd(account.availableBalance!)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SegmentedButton<_AccountTransactionFilter>(
              segments: const [
                ButtonSegment(value: _AccountTransactionFilter.all, label: Text('All')),
                ButtonSegment(value: _AccountTransactionFilter.expenses, label: Text('Expenses')),
                ButtonSegment(value: _AccountTransactionFilter.income, label: Text('Income')),
              ],
              selected: {_typeFilter},
              onSelectionChanged: (value) => setState(() => _typeFilter = value.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search transactions',
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
                    child: _buildList(context),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [Text(_error!)],
      );
    }

    final items = _filteredTransactions;
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          Center(child: Text('No transactions for this account')),
        ],
      );
    }

    final grouped = <DateTime, List<FinanceTransaction>>{};
    for (final tx in items) {
      final day = DateTime(tx.date.year, tx.date.month, tx.date.day);
      grouped.putIfAbsent(day, () => []).add(tx);
    }
    final sortedDays = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: sortedDays.length,
      itemBuilder: (context, index) {
        final day = sortedDays[index];
        final dayItems = grouped[day]!;
        final dayTotal = dayItems.fold<double>(0, (sum, tx) => sum + tx.amount);
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
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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
                  for (final tx in dayItems)
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
