import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/features/portfolio/data/portfolio_repository.dart';
import 'package:rico_investidor/features/portfolio/models/portfolio_transaction.dart';
import 'package:rico_investidor/models/holding_currency.dart';
import 'package:rico_investidor/models/portfolio_holding.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({
    super.key,
    required this.symbol,
    required this.assetName,
    required this.onHoldingsChanged,
  });

  final String symbol;
  final String assetName;
  final void Function(List<PortfolioHolding> updatedHoldings) onHoldingsChanged;

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  bool _loading = true;
  List<PortfolioTransaction> _transactions = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await portfolioRepository.fetchTransactions(symbol: widget.symbol);
      if (!mounted) return;
      setState(() {
        _transactions = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _confirmDelete(PortfolioTransaction tx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction'),
        content: const Text(
          'Delete this transaction? The position will be recalculated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final holdings = await portfolioRepository.deleteTransaction(tx.id);
      widget.onHoldingsChanged(holdings);
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete transaction.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = HoldingCurrency.usd;
    final entries = _buildGroupedEntries(_transactions);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.symbol} — Transactions'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _transactions.isEmpty
              ? const Center(child: Text('No transactions recorded'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    if (entry.isHeader) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Text(
                          entry.header!,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      );
                    }

                    final tx = entry.transaction!;
                    final color = tx.isBuy ? AppColors.positive : AppColors.negative;
                    final sharesLabel = tx.quantity.truncateToDouble() == tx.quantity
                        ? tx.quantity.toStringAsFixed(0)
                        : tx.quantity.toStringAsFixed(2);

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.15),
                        child: Text(
                          tx.isBuy ? 'B' : 'S',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      title: Text('${tx.isBuy ? 'Buy' : 'Sell'} $sharesLabel shares'),
                      subtitle: Text(
                        '${_formatDate(tx.date)}'
                        '${tx.broker != null && tx.broker!.isNotEmpty ? ' · ${tx.broker}' : ''}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${currency.format(tx.pricePerUnit)}/share'),
                          Text(
                            'Total: ${currency.format(tx.totalCost)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      onLongPress: () => _confirmDelete(tx),
                    );
                  },
                ),
    );
  }
}

class _GroupedEntry {
  const _GroupedEntry.header(this.header) : transaction = null;
  const _GroupedEntry.transaction(this.transaction) : header = null;

  final String? header;
  final PortfolioTransaction? transaction;

  bool get isHeader => header != null;
}

List<_GroupedEntry> _buildGroupedEntries(List<PortfolioTransaction> transactions) {
  final entries = <_GroupedEntry>[];
  String? lastHeader;
  for (final tx in transactions) {
    final header = _monthYearHeader(tx.date);
    if (header != lastHeader) {
      entries.add(_GroupedEntry.header(header));
      lastHeader = header;
    }
    entries.add(_GroupedEntry.transaction(tx));
  }
  return entries;
}

String _formatDate(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$d/$m/${date.year}';
}

String _monthYearHeader(DateTime date) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[date.month - 1]} ${date.year}';
}
