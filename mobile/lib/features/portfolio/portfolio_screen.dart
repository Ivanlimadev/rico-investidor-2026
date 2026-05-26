import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/portfolio/add_asset_screen.dart';
import 'package:rico_investidor/models/portfolio_holding.dart';
import 'package:rico_investidor/state/portfolio_state.dart';

void openPortfolioScreen(
  BuildContext context, {
  required PortfolioState portfolio,
  required VoidCallback onPortfolioChanged,
  FiiRepository? fiiRepository,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PortfolioScreen(
        portfolio: portfolio,
        onPortfolioChanged: onPortfolioChanged,
        fiiRepository: fiiRepository,
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
  });

  final PortfolioState portfolio;
  final VoidCallback onPortfolioChanged;
  final FiiRepository? fiiRepository;

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  bool _refreshing = false;

  Future<void> _refreshFiiPrices() async {
    final repo = widget.fiiRepository;
    if (repo == null) return;
    setState(() => _refreshing = true);
    await repo.refreshPortfolioFiiPrices(widget.portfolio);
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

  @override
  Widget build(BuildContext context) {
    final holdings = widget.portfolio.holdings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minha carteira'),
        actions: [
          if (widget.fiiRepository != null)
            IconButton(
              tooltip: 'Atualizar cotações FIIs',
              onPressed: _refreshing ? null : _refreshFiiPrices,
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
              onRefresh: _refreshFiiPrices,
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
                    _HoldingCard(holding: holding),
                    const SizedBox(height: 10),
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
                  Text('Patrimônio total', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Text(
                    formatBrl(total),
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

class _HoldingCard extends StatelessWidget {
  const _HoldingCard({required this.holding});

  final PortfolioHolding holding;

  @override
  Widget build(BuildContext context) {
    final profitColor = holding.profit >= 0 ? AppColors.positive : AppColors.negative;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(holding.symbol, style: Theme.of(context).textTheme.titleMedium),
                      Text(holding.name, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Text(
                  formatBrl(holding.marketValue),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _InfoChip(
                  label: 'Qtd',
                  value: holding.quantity.toStringAsFixed(
                    holding.quantity.truncateToDouble() == holding.quantity ? 0 : 2,
                  ),
                ),
                const SizedBox(width: 8),
                _InfoChip(label: 'Preço médio', value: formatBrl(holding.averagePrice)),
                const SizedBox(width: 8),
                _InfoChip(label: 'Atual', value: formatBrl(holding.currentPrice)),
                const Spacer(),
                Text(
                  '${holding.profit >= 0 ? '+' : ''}${holding.profitPercent.toStringAsFixed(2)}%',
                  style: TextStyle(color: profitColor, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label: $value', style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
