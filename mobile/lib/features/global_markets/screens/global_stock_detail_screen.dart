import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/core/config/api_config.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/core/widgets/asset_card_header.dart';
import 'package:rico_investidor/core/widgets/asset_logo.dart';
import 'package:rico_investidor/core/widgets/asset_quick_actions.dart';
import 'package:rico_investidor/features/global_markets/data/global_market_repository.dart';
import 'package:rico_investidor/features/global_markets/utils/marketstack_errors.dart';
import 'package:rico_investidor/features/global_markets/screens/global_stock_compare_screen.dart';
import 'package:rico_investidor/features/global_markets/widgets/global_stock_about_card.dart';
import 'package:rico_investidor/features/global_markets/widgets/global_stock_dividends_section.dart';
import 'package:rico_investidor/features/global_markets/widgets/global_stock_market_stats_card.dart';
import 'package:rico_investidor/features/global_markets/widgets/global_stock_quote_chart.dart';
import 'package:rico_investidor/features/global_markets/widgets/global_stock_returns_card.dart';
import 'package:rico_investidor/features/global_markets/widgets/global_stock_splits_card.dart';
import 'package:rico_investidor/features/global_markets/widgets/global_stock_fundamentals_card.dart';
import 'package:rico_investidor/features/quotes/data/quote_api_client.dart';
import 'package:rico_investidor/models/asset_item.dart';

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
  GlobalStockDetailDto? _extendedDetail;
  AssetItem? _actionAsset;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = widget.repository
        .getDetail(
          widget.symbol,
          exchange: widget.exchange,
        )
        .then((detail) {
      if (mounted) setState(() => _actionAsset = detail.quote);
      _loadExtendedDetail();
      return detail;
    });
  }

  Future<void> _loadExtendedDetail() async {
    try {
      final extended = await widget.repository.getDetail(
        widget.symbol,
        exchange: widget.exchange,
        candleLimit: GlobalMarketRepository.extendedCandleLimit,
        dividendLimit: GlobalMarketRepository.extendedDividendLimit,
      );
      if (!mounted) return;
      setState(() => _extendedDetail = extended);
    } catch (_) {}
  }

  void _retry() {
    setState(() {
      _actionAsset = null;
      _load();
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
          final display = _extendedDetail ?? detail;
          final quote = detail.quote;
          final meta = detail.quoteMeta;
          final dy = display.dividendsSummary.dividendYieldTtm ?? detail.fundamentals.dividendYield12m;
          final positive = quote.changePercent >= 0;
          final changeColor = positive ? AppColors.positive : AppColors.negative;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _HeroQuoteCard(
                quote: quote,
                meta: meta,
                detail: detail,
                changeColor: changeColor,
                positive: positive,
                dy: dy,
                onSurface: onSurface,
              ),
              if (detail.returns.isNotEmpty) ...[
                const SizedBox(height: 12),
                GlobalStockReturnsCard(returns: detail.returns),
              ],
              const SizedBox(height: 12),
              GlobalStockFundamentalsCard(fundamentals: detail.fundamentals),
              if (_hasSessionStats(meta)) ...[
                const SizedBox(height: 12),
                GlobalStockMarketStatsCard(meta: meta),
              ],
              const SizedBox(height: 12),
              GlobalStockAboutCard(company: detail.company),
              if (detail.historyLimited) ...[
                const SizedBox(height: 12),
                Text(
                  'Histórico limitado a ${detail.maxHistoryDays} dias no plano Marketstack atual.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: onSurface.withValues(alpha: 0.65),
                      ),
                ),
              ],
              const SizedBox(height: 16),
              GlobalStockQuoteChart(candles: display.candles),
              if (display.dividends.isNotEmpty ||
                  display.dividendsSummary.ttmPerShare != null ||
                  display.dividendsSummary.nextDividend != null) ...[
                const SizedBox(height: 16),
                GlobalStockDividendsSection(
                  summary: display.dividendsSummary,
                  dividends: display.dividends,
                  total: display.dividendsTotal,
                ),
              ],
              if (display.splits.isNotEmpty) ...[
                const SizedBox(height: 12),
                GlobalStockSplitsCard(splits: display.splits, total: display.splitsTotal),
              ],
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.cloud_outlined),
                  title: const Text('Fonte de dados'),
                  subtitle: Text('Marketstack · ${detail.plan.toUpperCase()} · ${detail.dataMode.toUpperCase()}'),
                  trailing: Text(
                    ApiConfig.baseUrl.replaceFirst('http://', '').replaceFirst('https://', ''),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static bool _hasSessionStats(MarketQuoteDto meta) {
    return meta.open != null ||
        meta.high != null ||
        meta.low != null ||
        meta.volume != null ||
        meta.previousClose != null ||
        meta.adjClose != null;
  }
}

class _HeroQuoteCard extends StatelessWidget {
  const _HeroQuoteCard({
    required this.quote,
    required this.meta,
    required this.detail,
    required this.changeColor,
    required this.positive,
    required this.dy,
    required this.onSurface,
  });

  final AssetItem quote;
  final MarketQuoteDto meta;
  final GlobalStockDetailDto detail;
  final Color changeColor;
  final bool positive;
  final double? dy;
  final Color onSurface;

  @override
  Widget build(BuildContext context) {
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
            Text('Cotação EOD', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: onSurface)),
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
                if (dy != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.positive.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.positive.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      'DY 12m ${dy!.toStringAsFixed(2)}%',
                      style: const TextStyle(color: AppColors.positive, fontWeight: FontWeight.w700),
                    ),
                  ),
                if (detail.ticker.hasIntraday)
                  Chip(
                    label: Text(detail.dataMode == 'realtime' ? 'Tempo real' : 'Intraday'),
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
