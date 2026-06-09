import 'package:flutter/material.dart';
import 'package:rico_investidor/core/auth/auth_session.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/app/main_shell_screen.dart';
import 'package:rico_investidor/core/network/api_exception.dart';
import 'package:rico_investidor/features/finances/data/finances_repository.dart';
import 'package:rico_investidor/features/finances/data/plaid_link_service.dart';
import 'package:rico_investidor/features/finances/models/finance_models.dart';
// HIDDEN: contas bancárias — import kept for Plaid integration
// import 'package:rico_investidor/features/finances/widgets/accounts_mini_card.dart';
import 'package:rico_investidor/features/finances/widgets/add_transaction_sheet.dart';
import 'package:rico_investidor/features/finances/widgets/bills_card.dart';
import 'package:rico_investidor/features/finances/widgets/budget_progress_card.dart';
import 'package:rico_investidor/features/finances/widgets/category_spending_card.dart';
import 'package:rico_investidor/features/finances/widgets/finance_summary_card.dart';
import 'package:rico_investidor/features/finances/widgets/plaid_link_screen.dart';
import 'package:rico_investidor/features/finances/widgets/plaid_success_sheet.dart';
import 'package:rico_investidor/features/finances/screens/accounts_screen.dart';
import 'package:rico_investidor/features/finances/screens/bills_screen.dart';
import 'package:rico_investidor/features/finances/screens/budget_screen.dart';
import 'package:rico_investidor/features/finances/screens/cash_flow_screen.dart';
import 'package:rico_investidor/features/finances/screens/transaction_detail_screen.dart';
import 'package:rico_investidor/features/finances/screens/transactions_screen.dart';
import 'package:rico_investidor/features/finances/widgets/recent_transactions_card.dart';
import 'package:rico_investidor/models/user_profile.dart';

class FinancesTabScreen extends StatefulWidget {
  const FinancesTabScreen({
    super.key,
    required this.profile,
    required this.onLogin,
    required this.onRegister,
  });

  final UserProfile profile;
  final VoidCallback onLogin;
  final VoidCallback onRegister;

  @override
  State<FinancesTabScreen> createState() => _FinancesTabScreenState();
}

class _FinancesTabScreenState extends State<FinancesTabScreen> {
  final _repository = financesRepository;

  bool _loading = true;
  String? _error;
  FinancesDashboardData? _dashboard;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant FinancesTabScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.isAnonymous != widget.profile.isAnonymous ||
        oldWidget.profile.isRegistered != widget.profile.isRegistered) {
      _load();
    }
  }

  bool get _requiresRegistration =>
      widget.profile.isAnonymous && !authSession.isRegisteredSession;

  Future<void> _load({bool forceRefresh = false}) async {
    if (_requiresRegistration) {
      setState(() {
        _loading = false;
        _dashboard = null;
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _repository.loadDashboard(forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        _dashboard = data;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível carregar suas finanças.';
        _loading = false;
      });
    }
  }

  // ignore: unused_element
  Future<void> _connectBank() async {
    final result = await Navigator.of(context).push<PlaidLinkConnectResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PlaidLinkScreen(onRequireAuth: widget.onLogin),
      ),
    );
    if (!mounted || result == null) return;
    await showPlaidSuccessSheet(context, result: result);
    await _load(forceRefresh: true);
  }

  Future<void> _addTransaction() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const AddTransactionSheet(),
    );
    if (saved == true) {
      await _load(forceRefresh: true);
    }
  }

  void _openCashFlow() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CashFlowScreen()),
    );
  }

  void _openBills() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BillsScreen()),
    );
  }

  // ignore: unused_element
  void _openAccounts() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AccountsScreen(onRequireAuth: widget.onLogin),
      ),
    );
  }

  Future<void> _openTransactions({String? category}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TransactionsScreen(initialCategory: category),
      ),
    );
    if (changed == true) await _load(forceRefresh: true);
  }

  Future<void> _openBudget() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const BudgetScreen()),
    );
    if (changed == true) await _load(forceRefresh: true);
  }

  Future<void> _openTransactionDetail(FinanceTransaction transaction) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TransactionDetailScreen(transaction: transaction),
      ),
    );
    if (changed == true) await _load(forceRefresh: true);
  }

  String? get _cacheLabel {
    final fetchedAt = _dashboard?.fetchedAt;
    if (fetchedAt == null) return null;
    final hour = fetchedAt.hour.toString().padLeft(2, '0');
    final minute = fetchedAt.minute.toString().padLeft(2, '0');
    return 'Atualizado às $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finanças'),
        actions: [
          if (!_requiresRegistration)
            IconButton(
              tooltip: 'Atualizar',
              onPressed: _loading ? null : () => _load(forceRefresh: true),
              icon: const Icon(Icons.refresh),
            ),
          const ShellHomeButton(),
        ],
      ),
      floatingActionButton: _requiresRegistration || _loading
          ? null
          : FloatingActionButton(
              onPressed: _addTransaction,
              child: const Icon(Icons.add),
            ),
      body: _requiresRegistration
          ? _AnonymousGate(
              onLogin: widget.onLogin,
              onRegister: widget.onRegister,
            )
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => _load(forceRefresh: true),
                  child: _buildBody(context),
                ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final data = _dashboard;
    if (data == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          if (_error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!),
              ),
            ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, kBottomNavContentPadding + 72),
      children: [
        if (_error != null) ...[
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (_cacheLabel != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_cacheLabel!, style: Theme.of(context).textTheme.bodySmall),
          ),
        // HIDDEN: conectar banco (Plaid) — aguardando integração
        FinanceSummaryCard(
          summary: data.summary,
          onTap: _openCashFlow,
        ),
        const SizedBox(height: 12),
        BudgetProgressCard(
          budget: data.budget,
          onTap: _openBudget,
          onSetBudget: _openBudget,
        ),
        const SizedBox(height: 12),
        CategorySpendingCard(
          items: data.topCategorySpending(),
          onViewAll: _openTransactions,
        ),
        const SizedBox(height: 12),
        RecentTransactionsCard(
          transactions: data.transactions,
          onViewAll: _openTransactions,
          onTransactionTap: _openTransactionDetail,
        ),
        const SizedBox(height: 12),
        BillsCard(
          bills: data.bills,
          onTap: _openBills,
        ),
        // HIDDEN: contas bancárias — aguardando integração Plaid
      ],
    );
  }
}

// ignore: unused_element
class _ConnectBankEmptyState extends StatelessWidget {
  const _ConnectBankEmptyState({
    required this.requiresRegistration,
    required this.onConnect,
  });

  final bool requiresRegistration;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.account_balance_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Conecte sua conta bancária',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Veja seus gastos, orçamento e contas num só lugar. Conexão segura via Plaid.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (requiresRegistration) ...[
              const SizedBox(height: 8),
              Text(
                'Requer conta registrada',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onConnect,
              icon: const Icon(Icons.link),
              label: const Text('Conectar banco'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnonymousGate extends StatelessWidget {
  const _AnonymousGate({
    required this.onLogin,
    required this.onRegister,
  });

  final VoidCallback onLogin;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, kBottomNavContentPadding),
      child: Column(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Personal Finance',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Create an account to track your expenses, set budgets and monitor your spending.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: onLogin, child: const Text('Sign in')),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onRegister, child: const Text('Create account')),
        ],
      ),
    );
  }
}
