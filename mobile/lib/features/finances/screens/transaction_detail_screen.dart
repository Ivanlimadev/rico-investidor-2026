import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/features/finances/models/finance_models.dart';
import 'package:rico_investidor/features/finances/utils/finance_category_mapper.dart';
import 'package:rico_investidor/features/finances/widgets/category_icon.dart';
import 'package:rico_investidor/features/finances/widgets/edit_transaction_sheet.dart';

class TransactionDetailScreen extends StatefulWidget {
  const TransactionDetailScreen({
    super.key,
    required this.transaction,
  });

  final FinanceTransaction transaction;

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  late FinanceTransaction _transaction = widget.transaction;

  Future<void> _edit() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => EditTransactionSheet(transaction: _transaction),
    );
    if (saved == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = financeCategoryInfo(_transaction.category);
    final label = _transaction.merchantName ?? _transaction.name;
    final amountColor =
        _transaction.isIncome ? AppColors.positive : Theme.of(context).colorScheme.error;
    final amountPrefix = _transaction.isIncome ? '+' : '−';
    final dateLabel =
        '${_transaction.date.day.toString().padLeft(2, '0')}/${_transaction.date.month.toString().padLeft(2, '0')}/${_transaction.date.year}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhe'),
        actions: [
          IconButton(
            tooltip: 'Editar',
            onPressed: _edit,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              FinanceCategoryIcon(category: _transaction.category, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, style: Theme.of(context).textTheme.headlineSmall),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '$amountPrefix${formatUsd(_transaction.amount.abs())}',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: amountColor,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 24),
          _DetailRow(label: 'Data', value: dateLabel),
          _DetailRow(label: 'Categoria', value: info.label),
          if (_transaction.accountName != null)
            _DetailRow(label: 'Conta', value: _transaction.accountName!),
          if (_transaction.isPending)
            _DetailRow(label: 'Status', value: 'Pendente'),
          if (_transaction.isManual)
            _DetailRow(label: 'Origem', value: 'Manual'),
          if ((_transaction.note ?? '').isNotEmpty)
            _DetailRow(label: 'Nota', value: _transaction.note!),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _edit,
            icon: const Icon(Icons.category_outlined),
            label: const Text('Editar categoria e nota'),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
