import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/quote_refresh_timer.dart';
import 'package:rico_investidor/core/utils/us_market_capabilities_labels.dart';
import 'package:rico_investidor/core/widgets/us_intraday_delay_chip.dart';
import 'package:rico_investidor/core/widgets/us_market_session_chip.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/core/widgets/asset_card_header.dart';
import 'package:rico_investidor/core/widgets/asset_logo.dart';
import 'package:rico_investidor/core/widgets/asset_quick_actions.dart';
import 'package:rico_investidor/core/utils/asset_magic_number.dart';
import 'package:rico_investidor/core/utils/dividend_payment_mappers.dart';
import 'package:rico_investidor/core/widgets/asset_magic_number_card.dart';
import 'package:rico_investidor/core/widgets/last_dividend_card.dart';
import 'package:rico_investidor/models/holding_currency.dart';
import 'package:rico_investidor/core/widgets/what_if_investment_card.dart';
import 'package:rico_investidor/core/utils/percent_format.dart';
import 'package:rico_investidor/features/global_markets/data/global_market_repository.dart';
import 'package:rico_investidor/features/global_markets/models/global_market_models.dart';
import 'package:rico_investidor/features/global_markets/utils/marketstack_errors.dart';
import 'package:rico_investidor/features/global_markets/screens/global_stock_compare_screen.dart';
import 'package:rico_investidor/features/global_markets/widgets/global_stock_about_card.dart';
import 'package:rico_investidor/features/global_markets/widgets/global_stock_dividends_section.dart';
import 'package:rico_investidor/features/global_markets/widgets/global_stock_quote_chart.dart';
import 'package:rico_investidor/features/quotes/widgets/stock_market_stats_card.dart';
import 'package:rico_investidor/features/global_markets/widgets/global_stock_returns_card.dart';
import 'package:rico_investidor/features/global_markets/widgets/global_stock_splits_card.dart';
import 'package:rico_investidor/features/quotes/models/stock_quote_detail.dart';
import 'package:rico_investidor/features/quotes/widgets/stock_fundamentals_card.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/features/quotes/models/market_quote_dto.dart';

class GlobalStockDetailScreen extends StatefulWidget {
  const GlobalStockDetailScreen({
    super.key,
    required this.symbol,
    required this.repository,
    this.exchange,
  });

  final String symbol;
  final GlobalMarketRepository repository;
  final String? exchange;

  @override
  State<GlobalStockDetailScreen> createState() => _GlobalStockDetailScreenState();
}

class _GlobalStockDetailScreenState extends State<GlobalStockDetailScreen> {
  late Future<GlobalStockDetailDto> _future;
  AssetItem? _actionAsset;
  AssetItem? _liveQuote;
  MarketQuoteDto? _liveQuoteMeta;
  bool _quoteLive = false;
  late final QuoteRefreshTimer _quoteRefreshTimer;
  List<GlobalStockCandleDto> _intradayCandles = const [];
  GlobalMarketCapabilitiesDto? _capabilities;

  @override
  void initState() {
    super.initState();
    _quoteRefreshTimer = QuoteRefreshTimer(onTick: _pollQuote);
    _future = _fetchDetail();
  }

  @override
  void dispose() {
    _quoteRefreshTimer.stop();
    super.dispose();
  }

  Future<GlobalStockDetailDto> _fetchDetail() async {
    final detail = await widget.repository.getDetail(
      widget.symbol,
      exchange: widget.exchange,
      candleLimit: GlobalMarketRepository.extendedCandleLimit,
      dividendLimit: GlobalMarketRepository.extendedDividendLimit,
    );
    final caps = await widget.repository.getCapabilities();
    var intraday = const <GlobalStockCandleDto>[];
    if (detail.dataMode == 'realtime') {
      try {
        final response = await widget.repository.getIntradayCandles(
          widget.symbol,
          exchange: widget.exchange,
        );
        intraday = response.candles;
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _actionAsset = detail.quote;
        _capabilities = caps;
        _intradayCandles = intraday;
      });
      _startQuotePolling(detail);
    }
    return detail;
  }

  void _startQuotePolling(GlobalStockDetailDto detail) {
    _quoteRefreshTimer.stop();
    _liveQuote = null;
    _liveQuoteMeta = null;
    _quoteLive = false;
    if (detail.dataMode != 'realtime') return;
    _quoteRefreshTimer.start(
      refreshSeconds: detail.refreshSeconds ?? 60,
      enabled: true,
    );
  }

  Future<void> _pollQuote() async {
    final meta = await widget.repository.refreshQuote(
      widget.symbol,
      exchange: widget.exchange,
    );
    if (!mounted) return;
    final category = meta.category == 'reits' ? MarketCategory.reits : MarketCategory.stocks;
    var intraday = _intradayCandles;
    if (_capabilities?.usMarketOpen == true) {
      try {
        intraday = (await widget.repository.getIntradayCandles(
          widget.symbol,
          exchange: widget.exchange,
        ))
            .candles;
      } catch (_) {}
    }
    setState(() {
      _liveQuoteMeta = meta;
      _liveQuote = meta.toUsAssetItem(category: category);
      _quoteLive = true;
      _actionAsset = _liveQuote;
      _intradayCandles = intraday;
    });
  }

  void _retry() {
    _quoteRefreshTimer.stop();
    setState(() {
      _actionAsset = null;
      _liveQuote = null;
      _liveQuoteMeta = null;
      _quoteLive = false;
      _future = _fetchDetail();
    });
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.symbol.toUpperCase()),
        actions: [
          const ShellHomeButton(),
          if (_actionAsset != null) ...AssetQuickActions.appBarActions(context, _actionAsset!),
          IconButton(
            tooltip: 'Comparar',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => GlobalStockCompareScreen(
                  repository: widget.repository,
                  initialTickers: [widget.symbol],
                ),
              ),
            ),
            icon: const Icon(Icons.compare_arrows),
          ),
        ],
      ),
      body: FutureBuilder<GlobalStockDetailDto>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    marketstackErrorMessage(
                      snapshot.error,
                      fallback: 'Não foi possível carregar o ativo.',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: isMarketstackQuotaError(snapshot.error) ? null : _retry,
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            );
          }

          final detail = snapshot.data!;
          final quote = _liveQuote ?? detail.quote;
          final meta = _liveQuoteMeta ?? detail.quoteMeta;
          final dy = detail.dividendsSummary.dividendYieldTtm ?? detail.fundamentals.dividendYield12m;
          final positive = quote.changePercent >= 0;
          final changeColor = positive ? AppColors.positive : AppColors.negative;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              if (_capabilities != null) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    UsMarketSessionChip(capabilities: _capabilities!),
                    UsIntradayDelayChip(capabilities: _capabilities!),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              _HeroQuoteCard(
                quote: quote,
                meta: meta,
                detail: detail,
                capabilities: _capabilities,
                changeColor: changeColor,
                positive: positive,
                dy: dy,
                onSurface: onSurface,
                quoteLive: _quoteLive,
              ),
              if (detail.dividends.isNotEmpty) ...[
                const SizedBox(height: 12),
                LastDividendCard.global(
                  dividends: detail.dividends,
                  dividendYield12m: dy,
                ),
              ],
              if (detail.returns.any((r) => r.returnPct != null)) ...[
                const SizedBox(height: 12),
                GlobalStockReturnsCard(returns: detail.returns),
              ],
              if (quote.price > 0) ...[
                const SizedBox(height: 12),
                WhatIfInvestmentCard(
                  currentPrice: quote.price,
                  candles: candleBarsFromGlobal(detail.candles),
                  payments: paymentsFromGlobalDividends(detail.dividends),
                  currency: WhatIfInvestmentCurrency.usd,
                ),
              ],
              if (magicNumberFromGlobalStock(
                    price: quote.price,
                    dividends: detail.dividends,
                    summary: detail.dividendsSummary,
                    dividendYieldPercent: dy,
                  ) case final magic?) ...[
                const SizedBox(height: 12),
                AssetMagicNumberCard(
                  result: magic,
                  unitLabel: 'ação',
                  unitPlural: 'ações',
                  currency: HoldingCurrency.usd,
                  dividendLabel: 'Dividendo médio/mês',
                ),
              ],
              const SizedBox(height: 16),
              StockFundamentalsCard(
                fundamentals: detail.fundamentals,
                currency: FundamentalsDisplayCurrency.usd,
              ),
              if (_isFundamentalsSparse(detail.fundamentals)) ...[
                const SizedBox(height: 12),
                _DetailNoticeCard(
                  message: 'Alguns indicadores podem estar indisponíveis para este ativo.',
                ),
              ],
              const SizedBox(height: 16),
              GlobalStockQuoteChart(
                candles: detail.candles,
                intradayCandles: _intradayCandles,
                intradayInterval: detail.intradayInterval ?? '5min',
                maxHistoryDays: detail.maxHistoryDays,
                realtimeEnabled: detail.realtimeEnabled || detail.dataMode == 'realtime',
              ),
              const SizedBox(height: 16),
              GlobalStockAboutCard(company: detail.company),
              const SizedBox(height: 16),
              StockMarketStatsCard(
                stats: detail.marketStats,
                useUsd: true,
                title: 'Pregão e indicadores',
                hideValuationMetrics: true,
                quotePrice: meta.price,
                quoteAdjClose: meta.adjClose,
              ),
              if (detail.dividends.isNotEmpty ||
                  detail.dividendsSummary.ttmPerShare != null ||
                  detail.dividendsSummary.nextDividend != null) ...[
                const SizedBox(height: 16),
                GlobalStockDividendsSection(
                  summary: detail.dividendsSummary,
                  dividends: detail.dividends,
                  total: detail.dividendsTotal,
                ),
              ],
              if (detail.splits.isNotEmpty) ...[
                const SizedBox(height: 16),
                GlobalStockSplitsCard(splits: detail.splits, total: detail.splitsTotal),
              ],
            ],
          );
        },
      ),
    );
  }

}

bool _isValidRatio(double? value) => value != null && value > 0 && value <= 500;

bool _isFundamentalsSparse(StockFundamentalsDto fundamentals) {
  final metrics = [
    fundamentals.priceEarnings,
    fundamentals.priceToBook,
    fundamentals.returnOnEquity,
    fundamentals.totalRevenue,
    fundamentals.ebitda,
    fundamentals.beta,
  ];
  return metrics.every((value) => value == null);
}

class _DetailNoticeCard extends StatelessWidget {
  const _DetailNoticeCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
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
            Expanded(
              child: Text(message, style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
      ),
    );
  }
}

double? _returnPctForLabel(List<GlobalStockReturnPeriodDto> returns, String label) {
  for (final item in returns) {
    if (item.label == label && item.returnPct != null) return item.returnPct;
  }
  return null;
}

class _HeroQuoteCard extends StatelessWidget {
  const _HeroQuoteCard({
    required this.quote,
    required this.meta,
    required this.detail,
    required this.capabilities,
    required this.changeColor,
    required this.positive,
    required this.dy,
    required this.onSurface,
    required this.quoteLive,
  });

  final AssetItem quote;
  final MarketQuoteDto meta;
  final GlobalStockDetailDto detail;
  final GlobalMarketCapabilitiesDto? capabilities;
  final Color changeColor;
  final bool positive;
  final double? dy;
  final Color onSurface;
  final bool quoteLive;

  @override
  Widget build(BuildContext context) {
    final return12m = _returnPctForLabel(detail.returns, '1A');
    final pe = detail.fundamentals.priceEarnings;
    final pb = detail.fundamentals.priceToBook;

    return Card(
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
                  symbol: quote.symbol,
                  logoUrl: quote.logoUrl,
                  size: kAssetLogoSizeList,
                  borderRadius: kAssetLogoBorderRadius,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quote.symbol,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: onSurface,
                            ),
                      ),
                      if (quote.name.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          quote.name,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: onSurface.withValues(alpha: 0.75),
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              detail.dataMode == 'realtime'
                  ? usRealtimeQuoteCaption(capabilities, quoteLive: quoteLive)
                  : 'Cotação de fechamento',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: onSurface),
            ),
            const SizedBox(height: 4),
            Text(
              formatUsd(quote.price),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: onSurface,
                  ),
            ),
            if (meta.sessionDate != null && meta.sessionDate!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Pregão: ${_formatDate(meta.sessionDate!)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: onSurface.withValues(alpha: 0.65),
                    ),
              ),
            ],
            const SizedBox(height: 10),
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
                        positive ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 14,
                        color: changeColor,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${positive ? '+' : ''}${quote.changePercent.toStringAsFixed(2)}%',
                        style: TextStyle(color: changeColor, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                if (return12m != null) _HeroMetricChip(label: '12m', value: formatPct(return12m)),
                if (dy != null && dy! > 0) _HeroMetricChip(label: 'DY 12m', value: formatPct(dy!)),
                if (_isValidRatio(pe)) _HeroMetricChip(label: 'P/L', value: pe!.toStringAsFixed(2)),
                if (_isValidRatio(pb)) _HeroMetricChip(label: 'P/VP', value: pb!.toStringAsFixed(2)),
                if (detail.dataMode == 'realtime' || detail.ticker.hasIntraday)
                  Chip(
                    label: Text(
                      usRealtimeQuoteChipLabel(capabilities, quoteLive: quoteLive),
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                if (quote.exchangeMic != null && quote.exchangeMic!.isNotEmpty)
                  Chip(
                    label: Text(quote.exchangeMic!),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(String raw) {
    if (raw.length >= 10) return raw.substring(0, 10);
    return raw;
  }
}

class _HeroMetricChip extends StatelessWidget {
  const _HeroMetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        '$label $value',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
