import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/app/main_shell_screen.dart';
import 'package:rico_investidor/features/dividends/widgets/portfolio_dividends_section.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/home/widgets/portfolio_allocation_card.dart';
import 'package:rico_investidor/features/home/widgets/portfolio_summary_row.dart';
import 'package:rico_investidor/features/open_finance/widgets/connect_investments_card.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/features/fii/utils/fii_ticker.dart';
import 'package:rico_investidor/features/portfolio/add_asset_screen.dart';
import 'package:rico_investidor/features/portfolio/widgets/portfolio_favorites_gadget.dart';
import 'package:rico_investidor/features/portfolio/widgets/confirm_remove_holding_dialog.dart';
import 'package:rico_investidor/features/portfolio/widgets/portfolio_holding_card.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/models/portfolio_holding.dart';
import 'package:rico_investidor/navigation/open_asset_detail.dart';
import 'package:rico_investidor/services/portfolio_fx_service.dart';
import 'package:rico_investidor/services/portfolio_price_service.dart';
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
  final _favoritesKey = GlobalKey<PortfolioFavoritesGadgetState>();

  late final PortfolioPriceService _priceService = PortfolioPriceService(
    quoteRepository: widget.quoteRepository,
  );

  Future<void> _refreshPrices() async {
    setState(() => _refreshing = true);
    final rate = await portfolioFxService.fetchUsdBrlRate();
    if (rate != null) {
      widget.portfolio.usdBrlRate = rate;
    }
    if (widget.portfolio.holdings.isNotEmpty) {
      await _priceService.refreshAll(widget.portfolio);
    }
    await _favoritesKey.currentState?.reload();
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

  Future<void> _confirmRemoveHolding(PortfolioHolding holding) async {
    final confirmed = await confirmRemovePortfolioHolding(context, holding);
    if (!confirmed || !mounted) return;

    widget.portfolio.removeHolding(holding.id);
    widget.onPortfolioChanged();
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
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: kBottomNavFabPadding),
        child: FloatingActionButton.extended(
          onPressed: _openAddAsset,
          icon: const Icon(Icons.add),
          label: const Text('Adicionar'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshPrices,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: kBottomNavContentPadding),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: ConnectInvestmentsCard(),
            ),
            PortfolioFavoritesGadget(
              key: _favoritesKey,
              searchService: widget.portfolio.searchService,
              fiiRepository: widget.fiiRepository,
              quoteRepository: widget.quoteRepository,
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
                showDividendsCard: false,
              ),
              if (widget.portfolio.usdBrlRate != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: Text(
                    'Carteira em US\$ · USD/BRL ${widget.portfolio.usdBrlRate!.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
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
              const SizedBox(height: 6),
              for (final holding in holdings)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: PortfolioHoldingCard(
                    holding: holding,
                    showDayChange: true,
                    onTap: () => openAssetDetail(
                      context,
                      asset: _assetFromHolding(holding),
                      fiiRepository: widget.fiiRepository,
                      quoteRepository: widget.quoteRepository,
                    ),
                    onDelete: () => _confirmRemoveHolding(holding),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: PortfolioDividendsSection(
                  portfolio: widget.portfolio,
                  onPortfolioChanged: widget.onPortfolioChanged,
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
    changePercent: holding.changePercent,
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
