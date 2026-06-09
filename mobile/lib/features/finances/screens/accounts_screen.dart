import 'package:flutter/material.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/features/finances/data/finances_repository.dart';
import 'package:rico_investidor/features/finances/data/plaid_link_service.dart';
import 'package:rico_investidor/features/finances/models/finance_models.dart';
import 'package:rico_investidor/features/finances/screens/account_detail_screen.dart';
import 'package:rico_investidor/features/finances/widgets/plaid_link_screen.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({
    super.key,
    this.onRequireAuth,
  });

  final VoidCallback? onRequireAuth;

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final _repository = financesRepository;

  var _loading = true;
  String? _error;
  List<PlaidAccount> _accounts = const [];

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
      final accounts = await _repository.listAccounts();
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load accounts.';
        _loading = false;
      });
    }
  }

  Map<String, List<PlaidAccount>> get _groupedByInstitution {
    final grouped = <String, List<PlaidAccount>>{};
    for (final account in _accounts) {
      grouped.putIfAbsent(account.institutionName, () => []).add(account);
    }
    final sortedKeys = grouped.keys.toList()..sort();
    return {for (final key in sortedKeys) key: grouped[key]!};
  }

  Future<void> _connectBank() async {
    final result = await Navigator.of(context).push<PlaidLinkConnectResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PlaidLinkScreen(onRequireAuth: widget.onRequireAuth ?? () {}),
      ),
    );
    if (result != null) {
      await _load();
    }
  }

  Future<void> _openAccount(PlaidAccount account) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AccountDetailScreen(account: account),
      ),
    );
    if (changed == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      floatingActionButton: FloatingActionButton(
        onPressed: _connectBank,
        child: const Icon(Icons.add),
      ),
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

    if (_accounts.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 40),
          Icon(Icons.account_balance_outlined, size: 56, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'No linked accounts',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Connect a bank account to see balances and transactions.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Center(
            child: FilledButton.icon(
              onPressed: _connectBank,
              icon: const Icon(Icons.link),
              label: const Text('Connect bank'),
            ),
          ),
        ],
      );
    }

    final grouped = _groupedByInstitution;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        for (final entry in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Text(
              entry.key,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Card(
            child: Column(
              children: [
                for (final account in entry.value)
                  ListTile(
                    leading: const Icon(Icons.account_balance_wallet_outlined),
                    title: Text(account.name),
                    subtitle: Text('•••• ${account.mask} · ${account.type}'),
                    trailing: Text(
                      formatUsd(account.currentBalance),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    onTap: () => _openAccount(account),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
