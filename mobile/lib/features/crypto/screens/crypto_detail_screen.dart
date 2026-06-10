import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rico_investidor/core/ads/ad_manager.dart';
import 'package:rico_investidor/core/ads/ad_subscription_plan.dart';
import 'package:rico_investidor/core/ads/banner_ad_widget.dart';
import 'package:rico_investidor/core/ads/feed_ad_widget.dart';
import 'package:rico_investidor/models/subscription_plan.dart';
import 'package:rico_investidor/core/widgets/asset_price_alert_button.dart';
import 'package:rico_investidor/core/widgets/asset_quick_actions.dart';
import 'package:rico_investidor/core/widgets/investment_disclaimer.dart';
import 'package:rico_investidor/features/crypto/widgets/crypto_hero_quote_card.dart';
import 'package:rico_investidor/features/crypto/data/crypto_price_stream.dart';
import 'package:rico_investidor/features/crypto/data/crypto_repository.dart';
import 'package:rico_investidor/features/crypto/models/crypto_models.dart';
import 'package:rico_investidor/features/crypto/utils/crypto_display_locale.dart';
import 'package:rico_investidor/features/crypto/widgets/crypto_chart_card.dart';
import 'package:rico_investidor/features/crypto/widgets/crypto_fundamentals_card.dart';
import 'package:rico_investidor/core/utils/asset_candle_mappers.dart';
import 'package:rico_investidor/core/widgets/what_if_investment_card.dart';
import 'package:rico_investidor/features/crypto/widgets/crypto_performance_row.dart';
import 'package:rico_investidor/models/asset_item.dart';

class CryptoDetailScreen extends StatefulWidget {
  const CryptoDetailScreen({
    super.key,
    required this.symbol,
    required this.plan,
    this.repository,
  });

  final String symbol;
  final SubscriptionPlan plan;
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
    unawaited(adManager.preloadInterstitial());
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await adManager.showInterstitialIfReady(kAdsSubscriptionPlan);
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(normalized),
          actions: [
            if (_actionAsset != null) AssetPriceAlertButton(asset: _actionAsset!),
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
          final showBrazilianQuotes = cryptoShowsBrazilianQuotes(context);

          final list = ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              16,
            ),
            children: [
              CryptoHeroQuoteCard(
                symbol: quote.symbol,
                name: quote.name,
                logoUrl: quote.imageUrl,
                price: displayPrice,
                currency: quote.currency,
                changePercent: change,
                brlPrice: profile?.brl.price,
                showBrazilianQuotes: showBrazilianQuotes,
                streamLive: _streamLive,
                marketCap: quote.marketCap ?? profile?.fundamentals.marketCap,
              ),
              const SizedBox(height: 12),
              CryptoChartCard(
                symbol: quote.symbol,
                repository: _repository,
                initialCandles: detail.candles,
              ),
              const SizedBox(height: 12),
              const InvestmentDisclaimer(compact: true),
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
                RicoFeedAd(plan: kAdsSubscriptionPlan, compactInsets: true),
              ],
            ],
          );

          return Column(
            children: [
              Expanded(child: list),
              RicoBannerAd(plan: kAdsSubscriptionPlan),
            ],
          );
        },
        ),
      ),
    );
  }
}
