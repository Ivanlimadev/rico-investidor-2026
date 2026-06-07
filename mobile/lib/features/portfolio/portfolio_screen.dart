import 'package:flutter/material.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/features/portfolio/portfolio_auth_gate.dart';
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
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PortfolioScreen(
        portfolio: portfolio,
        onPortfolioChanged: onPortfolioChanged,
      ),
    ),
  );
}

/// Abre o formulário de busca + posição (sem passar pela tela intermediária vazia).
Future<void> openAddAssetScreen(
  BuildContext context, {
  required PortfolioState portfolio,
  required VoidCallback onPortfolioChanged,
  Future<void> Function()? onAccountReady,
}) async {
  final allowed = await ensureRegisteredForPortfolio(
    context,
    onAccountReady: onAccountReady ?? () async {},
  );
  if (!allowed || !context.mounted) return;

  final added = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => AddAssetScreen(portfolio: portfolio),
    ),
  );
  if (added == true) onPortfolioChanged();
}

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({
    super.key,
    required this.portfolio,
    required this.onPortfolioChanged,
  });

  final PortfolioState portfolio;
  final VoidCallback onPortfolioChanged;


  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  bool _refreshing = false;

  Future<void> _refreshPrices() async {
    setState(() => _refreshing = true);
    await PortfolioPriceService().refreshAll(widget.portfolio);
    if (!mounted) return;
    setState(() => _refreshing = false);
    widget.onPortfolioChanged();
  }

  Future<void> _openAddAsset() => openAddAssetScreen(
        context,
        portfolio: widget.portfolio,
        onPortfolioChanged: widget.onPortfolioChanged,
      );

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
                  _TotalHeader(total: widget.portfolio.patrimonioTotalUsd),
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
    final color = Theme.of(context).colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                'US\$',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Patrimônio total', style: Theme.of(context).textTheme.labelLarge),
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
          ],
        ),
      ),
    );
  }
}
