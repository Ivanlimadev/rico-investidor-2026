import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/widgets/asset_card_header.dart';
import 'package:rico_investidor/core/widgets/asset_quick_actions.dart';
import 'package:rico_investidor/features/crypto/data/crypto_price_stream.dart';
import 'package:rico_investidor/features/crypto/data/crypto_repository.dart';
import 'package:rico_investidor/features/crypto/models/crypto_models.dart';
import 'package:rico_investidor/features/crypto/utils/crypto_display_locale.dart';
import 'package:rico_investidor/features/assets/models/related_assets.dart';
import 'package:rico_investidor/features/assets/widgets/related_assets_card.dart';
import 'package:rico_investidor/features/crypto/widgets/crypto_chart_card.dart';
import 'package:rico_investidor/features/crypto/widgets/crypto_fundamentals_card.dart';
import 'package:rico_investidor/core/utils/asset_candle_mappers.dart';
import 'package:rico_investidor/core/widgets/what_if_investment_card.dart';
import 'package:rico_investidor/features/crypto/widgets/crypto_performance_row.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/market_category.dart';

class CryptoDetailScreen extends StatefulWidget {
  const CryptoDetailScreen({
    super.key,
    required this.symbol,
    this.repository,
  });

  final String symbol;
  final CryptoRepository? repository;

  @override
  State<CryptoDetailScreen> createState() => _CryptoDetailScreenState();
}

class _CryptoDetailScreenState extends State<CryptoDetailScreen> {
  late Future<CryptoDetailDto> _loadFuture;
  CryptoPriceStream? _priceStream;
  double? _livePrice;
  bool _streamLive = false;
  AssetItem? _actionAsset;
  List<CryptoCandleDto> _simulationCandles = const [];

  CryptoRepository get _repository => widget.repository ?? cryptoRepository;

  @override
  void initState() {
    super.initState();
    _loadFuture = _repository.getDetail(widget.symbol).then((detail) {
      if (mounted) {
        setState(() => _actionAsset = detail.quote.toAssetItem());
      }
      _startLivePrice(detail.quote.symbol);
      _loadSimulationCandles(detail.quote.symbol);
      return detail;
    });
  }

  Future<void> _loadSimulationCandles(String symbol) async {
    try {
      final response = await _repository.getCandles(symbol, preset: '1y');
      if (!mounted) return;
      setState(() => _simulationCandles = response.candles);
    } catch (_) {}
  }

  @override
  void dispose() {
    _priceStream?.close();
    super.dispose();
  }

  void _startLivePrice(String symbol) {
    _priceStream?.close();
    _priceStream = CryptoPriceStream(
      symbol: symbol,
      onTrade: (trade) {
        if (!mounted) return;
        setState(() {
          _livePrice = trade.price;
          _streamLive = true;
        });
      },
    )..connect();
  }

  @override
  Widget build(BuildContext context) {
    final normalized = normalizeCryptoSymbol(widget.symbol);

    return Scaffold(
      appBar: AppBar(
        title: Text(normalized),
        actions: [
          const ShellHomeButton(),
          if (_actionAsset != null) ...AssetQuickActions.appBarActions(context, _actionAsset!),
        ],
      ),
      body: FutureBuilder<CryptoDetailDto>(
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
                  'Não foi possível carregar $normalized.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            );
          }

          final detail = snapshot.data!;
          final quote = detail.quote;
          final profile = detail.profile;
          final displayPrice = _livePrice ?? quote.price;
          final change = quote.changePercent;
          final isPositive = change >= 0;
          final changeColor = isPositive ? AppColors.positive : AppColors.negative;
          final showBrazilianQuotes = cryptoShowsBrazilianQuotes(context);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              AssetCardHeader(
                symbol: quote.symbol,
                name: quote.name,
                logoUrl: quote.imageUrl,
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatCryptoPrice(displayPrice, currency: quote.currency),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (showBrazilianQuotes && profile?.brl.price != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        formatCryptoPrice(profile!.brl.price!, currency: 'BRL'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${isPositive ? '+' : ''}${change.toStringAsFixed(2)}% em 24h',
                    style: TextStyle(color: changeColor, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  if (_streamLive) ...[
                    const SizedBox(width: 10),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: AppColors.positive, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Ao vivo',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.positive,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ],
              ),
              if (displayPrice > 0) ...[
                const SizedBox(height: 12),
                WhatIfInvestmentCard(
                  currentPrice: displayPrice,
                  candles: candleBarsFromCrypto(
                    _simulationCandles.isNotEmpty ? _simulationCandles : detail.candles,
                  ),
                  currency: WhatIfInvestmentCurrency.usd,
                  unitLabel: 'moeda',
                ),
              ],
              if (profile != null) ...[
                const SizedBox(height: 14),
                CryptoPerformanceRow(performance: profile.performance),
                const SizedBox(height: 16),
                CryptoFundamentalsCard(
                  fundamentals: profile.fundamentals,
                  brl: profile.brl,
                  showBrazilianQuotes: showBrazilianQuotes,
                ),
              ],
              const SizedBox(height: 16),
              CryptoChartCard(
                symbol: quote.symbol,
                repository: _repository,
                initialCandles: detail.candles,
              ),
              const SizedBox(height: 12),
              RelatedAssetsCard(
                ticker: quote.symbol,
                market: relatedMarketSlug(MarketCategory.cripto),
              ),
            ],
          );
        },
      ),
    );
  }
}
