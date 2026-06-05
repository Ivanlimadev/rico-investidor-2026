import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/core/widgets/asset_card_header.dart';
import 'package:rico_investidor/core/widgets/asset_logo.dart';
import 'package:rico_investidor/core/widgets/asset_quick_actions.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/core/widgets/asset_returns_card.dart';
import 'package:rico_investidor/core/widgets/last_dividend_card.dart';
import 'package:rico_investidor/core/widgets/what_if_investment_card.dart';
import 'package:rico_investidor/features/quotes/widgets/stock_corporate_actions_card.dart';
import 'package:rico_investidor/features/quotes/widgets/br_stock_dividends_section.dart';
import 'package:rico_investidor/features/quotes/widgets/stock_recent_dividends_card.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/features/quotes/models/stock_quote_detail.dart';
import 'package:rico_investidor/features/assets/models/related_assets.dart';
import 'package:rico_investidor/features/assets/widgets/related_assets_card.dart';
import 'package:rico_investidor/features/quotes/widgets/stock_about_card.dart';
import 'package:rico_investidor/features/quotes/widgets/stock_financials_card.dart';
import 'package:rico_investidor/features/quotes/widgets/stock_fundamental_history_card.dart';
import 'package:rico_investidor/features/quotes/widgets/stock_fundamentals_card.dart';
import 'package:rico_investidor/features/quotes/widgets/stock_macro_card.dart';
import 'package:rico_investidor/features/quotes/widgets/stock_market_stats_card.dart';
import 'package:rico_investidor/features/quotes/screens/stock_compare_screen.dart';
import 'package:rico_investidor/features/quotes/widgets/stock_quote_chart_card.dart';
import 'package:rico_investidor/core/utils/data_provider_label.dart';
import 'package:rico_investidor/models/market_category.dart';

class StockDetailScreen extends StatefulWidget {
  const StockDetailScreen({
    super.key,
    required this.ticker,
    required this.category,
    required this.repository,
    this.initialDetail,
    this.notes = const [],
  });

  final String ticker;
  final MarketCategory category;
  final QuoteRepository repository;
  final StockQuoteDetailDto? initialDetail;
  final List<String> notes;

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> {
  late Future<StockQuoteDetailDto> _loadFuture;
  AssetItem? _actionAsset;
  int _refreshGeneration = 0;

  AssetItem _actionAssetFrom(StockQuoteDetailDto detail) {
    final quote = detail.quote;
    return AssetItem(
      symbol: widget.ticker,
      name: quote.name,
      category: widget.category,
      price: quote.price,
      changePercent: quote.changePercent,
      logoUrl: detail.profile.logoUrl,
      dividendYield12m:
          detail.dividends.displayDividendYield ?? detail.fundamentals.dividendYield12m,
    );
  }

  void _applyActionAsset(StockQuoteDetailDto detail) {
    final asset = _actionAssetFrom(detail);
    if (_actionAsset?.symbol == asset.symbol &&
        _actionAsset?.price == asset.price) {
      return;
    }
    setState(() => _actionAsset = asset);
  }

  Future<StockQuoteDetailDto> _fetchDetail() {
    return widget.repository
        .getStockDetail(
          widget.ticker,
          candleLimit: QuoteRepository.extendedCandleLimit,
          dividendLimit: QuoteRepository.extendedDividendLimit,
        )
        .then((detail) {
      if (mounted) _applyActionAsset(detail);
      return detail;
    });
  }

  void _retry() {
    setState(() {
      _actionAsset = null;
      _loadFuture = _fetchDetail();
    });
  }

  Future<void> _onRefresh() async {
    widget.repository.invalidateStockDetail(widget.ticker);
    setState(() {
      _refreshGeneration++;
      _loadFuture = _fetchDetail();
    });
    await _loadFuture;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialDetail != null) {
      _actionAsset = _actionAssetFrom(widget.initialDetail!);
      _loadFuture = Future.value(widget.initialDetail!);
    } else {
      _loadFuture = _fetchDetail();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.ticker),
        actions: [
          const ShellHomeButton(),
          if (_actionAsset != null) ...AssetQuickActions.appBarActions(context, _actionAsset!),
          IconButton(
            tooltip: 'Comparar',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => StockCompareScreen(
                  repository: widget.repository,
                  initialTickers: [widget.ticker],
                ),
              ),
            ),
            icon: const Icon(Icons.compare_arrows),
          ),
        ],
      ),
      body: FutureBuilder<StockQuoteDetailDto>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Não foi possível carregar ${widget.ticker}.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _retry,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            );
          }

          final detail = snapshot.data!;
          final quote = detail.quote;
          final candles = detail.candles;
          final dividendPayments = detail.dividends.payments;
          final dividendsDto = detail.dividends;
          final dy =
              dividendsDto.displayDividendYield ?? detail.fundamentals.dividendYield12m;
          final showBrDividendsSection = widget.category == MarketCategory.acoesBr;
          final isPositive = quote.changePercent >= 0;
          final changeColor = isPositive ? AppColors.positive : AppColors.negative;
          final logoUrl = detail.profile.logoUrl;

          return RefreshIndicator(
            onRefresh: _onRefresh,
            child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              if (widget.notes.isNotEmpty) ...[
                for (final note in widget.notes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(note, style: Theme.of(context).textTheme.bodySmall)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
              Card(
                clipBehavior: Clip.antiAlias,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.55),
                        Theme.of(context).colorScheme.surface,
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AssetLogo(
                            symbol: widget.ticker,
                            logoUrl: logoUrl,
                            size: kAssetLogoSizeList,
                            borderRadius: kAssetLogoBorderRadius,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Cotação', style: Theme.of(context).textTheme.labelLarge),
                                const SizedBox(height: 4),
                                Text(
                                  formatBrl(quote.price),
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: changeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                                  size: 14,
                                  color: changeColor,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${quote.changePercent.abs().toStringAsFixed(2)}%',
                                  style: TextStyle(
                                    color: changeColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (dy != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.positive.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.positive.withValues(alpha: 0.25)),
                              ),
                              child: Text(
                                '${showBrDividendsSection ? 'DY atual' : 'DY 12m'} ${dy.toStringAsFixed(2)}%',
                                style: TextStyle(
                                  color: AppColors.positive,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(quote.name, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        widget.category.title,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.65),
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              if (lastPaidPayment(dividendPayments) != null) ...[
                const SizedBox(height: 12),
                LastDividendCard(
                  payments: dividendPayments,
                  dividendYield12m: dy,
                ),
              ],
              if (candles.isNotEmpty) ...[
                const SizedBox(height: 16),
                AssetReturnsCard(
                  currentPrice: quote.price,
                  candles: candles,
                  payments: dividendPayments,
                ),
              ],
              if (quote.price > 0) ...[
                const SizedBox(height: 12),
                WhatIfInvestmentCard(
                  currentPrice: quote.price,
                  candles: candles,
                  payments: dividendPayments,
                ),
              ],
              const SizedBox(height: 16),
              StockFundamentalsCard(
                fundamentals: detail.fundamentals,
                repository: widget.repository,
              ),
              if (widget.category == MarketCategory.acoesBr) ...[
                const SizedBox(height: 16),
                StockMacroCard(
                  key: ValueKey('macro_$_refreshGeneration'),
                  repository: widget.repository,
                ),
              ],
              const SizedBox(height: 16),
              StockQuoteChartCard(
                ticker: widget.ticker,
                repository: widget.repository,
                initialCandles: candles,
              ),
              const SizedBox(height: 16),
              StockAboutCard(profile: detail.profile),
              if (widget.category == MarketCategory.acoesBr) ...[
                const SizedBox(height: 16),
                StockFundamentalHistoryCard(
                  key: ValueKey('fund_hist_$_refreshGeneration'),
                  ticker: widget.ticker,
                  repository: widget.repository,
                ),
                const SizedBox(height: 16),
                StockFinancialsCard(
                  key: ValueKey('financials_$_refreshGeneration'),
                  ticker: widget.ticker,
                  repository: widget.repository,
                ),
              ],
              const SizedBox(height: 16),
              StockMarketStatsCard(stats: detail.marketStats),
              if (showBrDividendsSection &&
                  (dividendsDto.payments.isNotEmpty || dividendsDto.displayDividendYield != null)) ...[
                const SizedBox(height: 16),
                BrStockDividendsSection(
                  dividends: dividendsDto,
                  dividendYield12m: dy,
                ),
              ] else if (dividendsDto.payments.isNotEmpty) ...[
                const SizedBox(height: 16),
                StockRecentDividendsCard(payments: dividendsDto.payments),
              ],
              if (detail.dividends.corporateActions.isNotEmpty) ...[
                const SizedBox(height: 16),
                StockCorporateActionsCard(actions: detail.dividends.corporateActions),
              ],
              const SizedBox(height: 16),
              RelatedAssetsCard(
                key: ValueKey('related_$_refreshGeneration'),
                ticker: widget.ticker,
                market: relatedMarketSlug(widget.category),
                sector: detail.profile.sector,
                industry: detail.profile.industry,
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.cloud_outlined),
                  title: const Text('Fonte de dados'),
                  subtitle: Text(formatDataProvider(detail.provider)),
                ),
              ),
            ],
            ),
          );
        },
      ),
    );
  }
}

