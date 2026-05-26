import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/app/main_shell_screen.dart';
import 'package:rico_investidor/features/dividends/dividends_screen.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/home/widgets/portfolio_allocation_card.dart';
import 'package:rico_investidor/features/home/widgets/portfolio_summary_row.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/features/open_finance/widgets/connect_investments_card.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/features/fii/utils/fii_ticker.dart';
import 'package:rico_investidor/features/portfolio/add_asset_screen.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/models/portfolio_holding.dart';
import 'package:rico_investidor/navigation/open_asset_detail.dart';
import 'package:rico_investidor/state/portfolio_state.dart';

class PortfolioTabScreen extends StatefulWidget {
  const PortfolioTabScreen({
    super.key,
    required this.portfolio,
    required this.onPortfolioChanged,
    required this.fiiRepository,
    required this.quoteRepository,
  });

  final PortfolioState portfolio;
  final VoidCallback onPortfolioChanged;
  final FiiRepository fiiRepository;
  final QuoteRepository quoteRepository;

  @override
  State<PortfolioTabScreen> createState() => _PortfolioTabScreenState();
}

class _PortfolioTabScreenState extends State<PortfolioTabScreen> {
  bool _refreshing = false;

  Future<void> _refreshPrices() async {
    setState(() => _refreshing = true);
    await widget.fiiRepository.refreshPortfolioFiiPrices(widget.portfolio);
    await widget.quoteRepository.refreshPortfolioStockPrices(widget.portfolio);
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
    if (added == true) widget.onPortfolioChanged();
  }

  @override
  Widget build(BuildContext context) {
    final holdings = widget.portfolio.holdings;
    final minEmptyHeight = MediaQuery.sizeOf(context).height * 0.28;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carteira'),
        actions: [
          const ShellHomeButton(),
          IconButton(
            tooltip: 'Atualizar cotações FIIs',
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
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: kBottomNavFabPadding),
        child: FloatingActionButton.extended(
          onPressed: _openAddAsset,
          icon: const Icon(Icons.add),
          label: const Text('Adicionar'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: holdings.isEmpty ? () async {} : _refreshPrices,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: kBottomNavContentPadding),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: ConnectInvestmentsCard(),
            ),
            const SizedBox(height: 12),
            if (holdings.isEmpty)
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: minEmptyHeight),
                child: _EmptyPortfolioTab(onAdd: _openAddAsset),
              )
            else ...[
              PortfolioSummaryRow(
                summary: widget.portfolio.buildSummary(),
                onPortfolioTap: () {},
                onDividendsTap: () => openDividendsScreen(
                  context,
                  portfolio: widget.portfolio,
                ),
              ),
              PortfolioAllocationCard(
                portfolio: widget.portfolio,
                onTap: _openAddAsset,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text(
                  'Ativos (${holdings.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 8),
              for (final holding in holdings)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: _HoldingCard(
                    holding: holding,
                    onTap: () => openAssetDetail(
                      context,
                      asset: _assetFromHolding(holding),
                      fiiRepository: widget.fiiRepository,
                      quoteRepository: widget.quoteRepository,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

AssetItem _assetFromHolding(PortfolioHolding holding) {
  return AssetItem(
    symbol: holding.symbol,
    name: holding.name,
    category: isFiiTicker(holding.symbol) ? MarketCategory.fiis : MarketCategory.acoesBr,
    price: holding.currentPrice,
    changePercent: 0,
  );
}

class _EmptyPortfolioTab extends StatelessWidget {
  const _EmptyPortfolioTab({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 72,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.45),
          ),
          const SizedBox(height: 16),
          Text(
            'Monte sua carteira',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Use Adicionar para incluir ativos manualmente. '
            'Carteira automática chega em breve.',
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
    );
  }
}

class _HoldingCard extends StatelessWidget {
  const _HoldingCard({required this.holding, required this.onTap});

  final PortfolioHolding holding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final profitColor = holding.profit >= 0 ? AppColors.positive : AppColors.negative;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
                  _InfoChip(label: 'PM', value: formatBrl(holding.averagePrice)),
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
