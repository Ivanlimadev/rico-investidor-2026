import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/core/widgets/asset_card_header.dart';
import 'package:rico_investidor/core/widgets/asset_logo.dart';
import 'package:rico_investidor/features/fii/widgets/fii_history_charts.dart';
import 'package:rico_investidor/core/widgets/asset_returns_card.dart';
import 'package:rico_investidor/features/quotes/widgets/stock_corporate_actions_card.dart';
import 'package:rico_investidor/features/quotes/widgets/stock_dividends_summary_card.dart';
import 'package:rico_investidor/features/quotes/widgets/stock_recent_dividends_card.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/features/quotes/models/stock_quote_detail.dart';
import 'package:rico_investidor/features/quotes/widgets/stock_about_card.dart';
import 'package:rico_investidor/features/quotes/widgets/stock_financials_card.dart';
import 'package:rico_investidor/features/quotes/widgets/stock_fundamental_history_card.dart';
import 'package:rico_investidor/features/quotes/widgets/stock_fundamentals_card.dart';
import 'package:rico_investidor/features/quotes/widgets/stock_macro_card.dart';
import 'package:rico_investidor/features/quotes/widgets/stock_market_stats_card.dart';
import 'package:rico_investidor/features/quotes/screens/stock_compare_screen.dart';
import 'package:rico_investidor/features/quotes/widgets/stock_quote_chart_card.dart';
import 'package:rico_investidor/models/fii_models.dart';
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
  StockQuoteDetailDto? _extendedDetail;

  @override
  void initState() {
    super.initState();
    if (widget.initialDetail != null) {
      _loadFuture = Future.value(widget.initialDetail);
      _loadExtendedDetail();
      return;
    }

    _loadFuture = widget.repository.getStockDetail(widget.ticker).then((detail) {
      _loadExtendedDetail();
      return detail;
    });
  }

  Future<void> _loadExtendedDetail() async {
    try {
      final extended = await widget.repository.getStockDetail(
        widget.ticker,
        candleLimit: 1260,
        dividendLimit: 500,
      );
      if (!mounted) return;
      setState(() => _extendedDetail = extended);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.ticker),
        actions: [
          const ShellHomeButton(),
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
                child: Text(
                  'Não foi possível carregar ${widget.ticker}.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            );
          }

          final detail = snapshot.data!;
          final quote = detail.quote;
          final candles = _extendedDetail?.candles ?? detail.candles;
          final dividendPayments = _extendedDetail?.dividends.payments ?? detail.dividends.payments;
          final dy = detail.fundamentals.dividendYield12m;
          final isPositive = quote.changePercent >= 0;
          final changeColor = isPositive ? AppColors.positive : AppColors.negative;
          final logoUrl = detail.profile.logoUrl;

          return ListView(
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
                                'DY 12m ${dy.toStringAsFixed(2)}%',
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
              if (candles.isNotEmpty) ...[
                const SizedBox(height: 16),
                AssetReturnsCard(
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
                StockMacroCard(repository: widget.repository),
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
                  ticker: widget.ticker,
                  repository: widget.repository,
                ),
                const SizedBox(height: 16),
                StockFinancialsCard(
                  ticker: widget.ticker,
                  repository: widget.repository,
                ),
              ],
              const SizedBox(height: 16),
              StockMarketStatsCard(stats: detail.marketStats),
              if (detail.dividends.payments.isNotEmpty) ...[
                const SizedBox(height: 16),
                StockDividendsSummaryCard(
                  dividends: detail.dividends,
                  dividendYield12m: dy,
                ),
              ],
              if (detail.dividends.annualSummary.isNotEmpty) ...[
                const SizedBox(height: 16),
                FiiDistributionsChart(
                  annualSummary: _recentAnnualSummary(detail.dividends.annualSummary),
                ),
              ],
              if (detail.dividends.payments.isNotEmpty) ...[
                const SizedBox(height: 16),
                StockRecentDividendsCard(payments: detail.dividends.payments),
              ],
              if (detail.dividends.corporateActions.isNotEmpty) ...[
                const SizedBox(height: 16),
                StockCorporateActionsCard(actions: detail.dividends.corporateActions),
              ],
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.cloud_outlined),
                  title: const Text('Fonte de dados'),
                  subtitle: Text(quote.provider.toUpperCase()),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

List<FiiDistributionYear> _recentAnnualSummary(List<FiiDistributionYear> summary, {int limit = 12}) {
  final sorted = List<FiiDistributionYear>.from(summary)..sort((a, b) => b.year.compareTo(a.year));
  return sorted.take(limit).toList();
}
