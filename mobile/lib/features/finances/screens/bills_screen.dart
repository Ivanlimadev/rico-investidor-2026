import 'package:flutter/material.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/features/finances/data/finances_repository.dart';
import 'package:rico_investidor/features/finances/models/finance_models.dart';
import 'package:rico_investidor/features/finances/utils/finance_category_mapper.dart';

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  final _repository = financesRepository;

  var _loading = true;
  String? _error;
  FinanceBills? _bills;

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
      final bills = await _repository.loadBills();
      if (!mounted) return;
      setState(() {
        _bills = bills;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load recurring bills.';
        _loading = false;
      });
    }
  }

  String _frequencyLabel(String frequency) {
    return switch (frequency.toLowerCase()) {
      'weekly' => 'Weekly',
      'yearly' || 'annual' => 'Yearly',
      _ => 'Monthly',
    };
  }

  String _nextDateLabel(RecurringBill bill) {
    final next = bill.nextDate;
    if (next == null) return 'Next date unknown';
    return 'Next: ${next.month}/${next.day}/${next.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recurring bills')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _buildBody(context),
            ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [Text(_error!)],
      );
    }

    final bills = _bills;
    if (bills == null) {
      return const SizedBox.shrink();
    }

    if (bills.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          Center(child: Text('No recurring bills detected yet')),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Card(
          child: ListTile(
            title: const Text('Estimated monthly total'),
            trailing: Text(
              formatUsd(bills.monthlyTotal),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final bill in bills.items) ...[
          Card(
            child: ListTile(
              leading: Text(financeCategoryInfo(bill.category).emoji),
              title: Text(bill.merchantName),
              subtitle: Text('${_frequencyLabel(bill.frequency)} · ${_nextDateLabel(bill)}'),
              trailing: Text(formatUsd(bill.amount)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
