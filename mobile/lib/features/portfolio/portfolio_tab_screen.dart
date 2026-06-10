import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/app/main_shell_screen.dart';
import 'package:rico_investidor/features/dividends/widgets/portfolio_dividends_section.dart';
import 'package:rico_investidor/features/home/widgets/portfolio_allocation_card.dart';
import 'package:rico_investidor/features/home/widgets/portfolio_summary_row.dart';
import 'package:rico_investidor/features/portfolio/data/portfolio_repository.dart';
import 'package:rico_investidor/features/portfolio/portfolio_screen.dart';
import 'package:rico_investidor/features/portfolio/screens/transaction_history_screen.dart';
import 'package:rico_investidor/features/portfolio/widgets/portfolio_favorites_gadget.dart';
import 'package:rico_investidor/features/portfolio/widgets/confirm_remove_holding_dialog.dart';
import 'package:rico_investidor/features/portfolio/widgets/portfolio_holding_card.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/models/portfolio_holding.dart';
import 'package:rico_investidor/navigation/open_asset_detail.dart';
import 'package:rico_investidor/services/market_preference_storage.dart';
import 'package:rico_investidor/services/portfolio_price_service.dart';
import 'package:rico_investidor/state/portfolio_state.dart';

class PortfolioTabScreen extends StatefulWidget {
  const PortfolioTabScreen({
    super.key,
    required this.portfolio,
    required this.onPortfolioChanged,
    required this.preferredMarket,
    this.onPortfolioAccountReady,
  });

  final PortfolioState portfolio;
  final VoidCallback onPortfolioChanged;
  final MarketPreference preferredMarket;
  final Future<void> Function()? onPortfolioAccountReady;

  @override
  State<PortfolioTabScreen> createState() => _PortfolioTabScreenState();
}

class _PortfolioTabScreenState extends State<PortfolioTabScreen> {
  bool _refreshing = false;
  final _favoritesKey = GlobalKey<PortfolioFavoritesGadgetState>();
  final _scrollController = ScrollController();

  late final PortfolioPriceService _priceService = PortfolioPriceService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshPrices());
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshPrices() async {
    setState(() => _refreshing = true);
    PortfolioPriceRefreshResult? priceResult;
    if (widget.portfolio.holdings.isNotEmpty) {
      priceResult = await _priceService.refreshAllDetailed(widget.portfolio);
    }
    await _favoritesKey.currentState?.reload();
    if (!mounted) return;
    setState(() => _refreshing = false);
    widget.onPortfolioChanged();
    if (priceResult != null && !priceResult.isSuccess && priceResult.updated == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível atualizar os preços. Verifique sua conexão e tente novamente.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _openAddAsset() => openAddAssetScreen(
        context,
        portfolio: widget.portfolio,
        onPortfolioChanged: widget.onPortfolioChanged,
        onAccountReady: widget.onPortfolioAccountReady ?? () async {},
      );

  Future<void> _confirmRemoveHolding(PortfolioHolding holding) async {
    final confirmed = await confirmRemovePortfolioHolding(context, holding);
    if (!confirmed || !mounted) return;

    widget.portfolio.removeHolding(holding.id);
    widget.onPortfolioChanged();
    if (portfolioRepository.canSync) {
      try {
        await portfolioRepository.removeRemoteHolding(holding.id);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final holdings = widget.portfolio.holdings;
    final minEmptyHeight = MediaQuery.sizeOf(context).height * 0.28;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Portfolio'),
        actions: [
          const ShellHomeButton(),
          IconButton(
            tooltip: 'Refresh prices',
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
          label: const Text('Add'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshPrices,
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: kBottomNavContentPadding),
          cacheExtent: 1200,
          children: [
            PortfolioSummaryRow(
              portfolio: widget.portfolio,
              preferredMarket: widget.preferredMarket,
              onPortfolioTap: () {},
              showDividendsCard: false,
            ),
            PortfolioFavoritesGadget(
              key: _favoritesKey,
              searchService: widget.portfolio.searchService,
            ),
            const SizedBox(height: 12),
            if (holdings.isEmpty)
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: minEmptyHeight),
                child: _EmptyPortfolioTab(onAdd: _openAddAsset),
              )
            else ...[
              RepaintBoundary(
                child: PortfolioAllocationCard(
                  key: const ValueKey('portfolio-allocation-card'),
                  portfolio: widget.portfolio,
                  preferredMarket: widget.preferredMarket,
                  onTap: _openAddAsset,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text(
                  'Assets (${holdings.length})',
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
                      asset: _assetFromHolding(holding, widget.portfolio),
                    ),
                    onDelete: () => _confirmRemoveHolding(holding),
                    onViewHistory: portfolioRepository.canSync
                        ? () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => TransactionHistoryScreen(
                                  symbol: holding.symbol,
                                  assetName: holding.name,
                                  onHoldingsChanged: (updatedHoldings) {
                                    widget.portfolio.holdings
                                      ..clear()
                                      ..addAll(updatedHoldings);
                                    widget.onPortfolioChanged();
                                  },
                                ),
                              ),
                            )
                        : null,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: RepaintBoundary(
                  child: PortfolioDividendsSection(
                    key: const ValueKey('portfolio-dividends-section'),
                    portfolio: widget.portfolio,
                    preferredMarket: widget.preferredMarket,
                    onPortfolioChanged: widget.onPortfolioChanged,
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

AssetItem _assetFromHolding(PortfolioHolding holding, PortfolioState portfolio) {
  return AssetItem(
    symbol: holding.symbol,
    name: holding.name,
    category: portfolio.categoryForHolding(holding) ?? MarketCategory.stocks,
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
            'Build your portfolio',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Use Add to record buy and sell transactions. '
            'Your balance updates with live quotes.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add asset'),
          ),
        ],
      ),
    );
  }
}
