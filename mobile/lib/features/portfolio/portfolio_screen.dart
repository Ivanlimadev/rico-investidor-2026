import 'package:flutter/material.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/features/portfolio/add_asset_screen.dart';
import 'package:rico_investidor/features/portfolio/widgets/confirm_remove_holding_dialog.dart';
import 'package:rico_investidor/features/portfolio/widgets/portfolio_holding_card.dart';
import 'package:rico_investidor/models/portfolio_holding.dart';
import 'package:rico_investidor/services/portfolio_price_service.dart';
import 'package:rico_investidor/state/portfolio_state.dart';

void openPortfolioScreen(
  BuildContext context, {
  required PortfolioState portfolio,
  required VoidCallback onPortfolioChanged,
  FiiRepository? fiiRepository,
  QuoteRepository? quoteRepository,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PortfolioScreen(
        portfolio: portfolio,
        onPortfolioChanged: onPortfolioChanged,
        fiiRepository: fiiRepository,
        quoteRepository: quoteRepository,
      ),
    ),
  );
}

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({
    super.key,
    required this.portfolio,
    required this.onPortfolioChanged,
    this.fiiRepository,
    this.quoteRepository,
  });

  final PortfolioState portfolio;
  final VoidCallback onPortfolioChanged;
  final FiiRepository? fiiRepository;
  final QuoteRepository? quoteRepository;

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  bool _refreshing = false;

  Future<void> _refreshPrices() async {
    final fiiRepo = widget.fiiRepository;
    final quoteRepo = widget.quoteRepository;
    if (fiiRepo == null && quoteRepo == null) return;

    setState(() => _refreshing = true);
    if (quoteRepo != null) {
      await PortfolioPriceService(quoteRepository: quoteRepo).refreshAll(widget.portfolio);
    } else if (fiiRepo != null) {
      await fiiRepo.refreshPortfolioFiiPrices(widget.portfolio);
    }
    if (!mounted) return;
    setState(() => _refreshing = false);
    widget.onPortfolioChanged();
  }

  Future<void> _openAddAsset() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AddAssetScreen(portfolio: widget.portfolio),
      ),
    );
    if (added == true) {
      widget.onPortfolioChanged();
    }
  }

  Future<void> _confirmRemoveHolding(PortfolioHolding holding) async {
    final confirmed = await confirmRemovePortfolioHolding(context, holding);
    if (!confirmed || !mounted) return;

    widget.portfolio.removeHolding(holding.id);
    widget.onPortfolioChanged();
  }

  @override
  Widget build(BuildContext context) {
    final holdings = widget.portfolio.holdings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minha carteira'),
        actions: [
          if (widget.fiiRepository != null || widget.quoteRepository != null)
            IconButton(
              tooltip: 'Atualizar cotações',
              onPressed: _refreshing ? null : _refreshPrices,
              icon: _refreshing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddAsset,
        icon: const Icon(Icons.add),
        label: const Text('Adicionar ativo'),
      ),
      body: holdings.isEmpty
          ? _EmptyPortfolio(onAdd: _openAddAsset)
          : RefreshIndicator(
              onRefresh: _refreshPrices,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 88),
                children: [
                  _TotalHeader(total: widget.portfolio.totalBalance),
                  const SizedBox(height: 16),
                  Text(
                    'Ativos (${holdings.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  for (final holding in holdings) ...[
                    PortfolioHoldingCard(
                      holding: holding,
                      onDelete: () => _confirmRemoveHolding(holding),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
    );
  }
}

class _EmptyPortfolio extends StatelessWidget {
  const _EmptyPortfolio({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pie_chart_outline,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Sua carteira está vazia',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Adicione ativos informando o nome, preço médio e, se quiser, dividendos recebidos.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar ativo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalHeader extends StatelessWidget {
  const _TotalHeader({required this.total});

  final double total;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Patrimônio total (US\$)', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Text(
                    formatUsd(total),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 36,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
            ),
          ],
        ),
      ),
    );
  }
}
