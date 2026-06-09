import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:rico_investidor/core/ads/ad_config.dart';
import 'package:rico_investidor/core/ads/ads_bootstrap.dart';
import 'package:rico_investidor/models/subscription_plan.dart';

class RicoBannerAd extends StatefulWidget {
  const RicoBannerAd({super.key, required this.plan});

  final SubscriptionPlan plan;

  @override
  State<RicoBannerAd> createState() => _RicoBannerAdState();
}

class _RicoBannerAdState extends State<RicoBannerAd> {
  BannerAd? _bannerAd;
  var _adLoaded = false;
  var _retryCount = 0;
  String? _lastError;
  static const _maxRetries = 5;

  @override
  void initState() {
    super.initState();
    if (!widget.plan.isPro) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_loadBanner());
      });
    } else if (kDebugMode) {
      debugPrint('[AdMob] banner skipped — Pro plan');
    }
  }

  @override
  void didUpdateWidget(covariant RicoBannerAd oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plan.isPro && !widget.plan.isPro) {
      _retryCount = 0;
      unawaited(_loadBanner());
    }
    if (!oldWidget.plan.isPro && widget.plan.isPro) {
      _disposeBanner();
      setState(() {
        _adLoaded = false;
        _lastError = null;
      });
    }
  }

  Future<void> _loadBanner() async {
    if (widget.plan.isPro || !mounted) return;

    await AdsBootstrap.ensureInitialized();
    if (!mounted || widget.plan.isPro) return;

    _disposeBanner();
    setState(() {
      _adLoaded = false;
      _lastError = null;
    });

    final width = MediaQuery.sizeOf(context).width.truncate();
    final anchoredSize = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    final size = anchoredSize ?? AdSize.banner;

    final banner = BannerAd(
      adUnitId: AdConfig.bannerId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;
          setState(() {
            _bannerAd = ad as BannerAd;
            _adLoaded = true;
            _lastError = null;
          });
          if (kDebugMode) {
            debugPrint('[AdMob] banner loaded (${AdConfig.bannerId})');
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (kDebugMode) {
            debugPrint(
              '[AdMob] banner failed (${error.code}): ${error.message}',
            );
          }
          if (!mounted || widget.plan.isPro) return;
          setState(() => _lastError = '${error.code}: ${error.message}');
          if (_retryCount < _maxRetries) {
            _retryCount++;
            Future.delayed(Duration(seconds: 2 * _retryCount), () {
              if (mounted && !widget.plan.isPro) unawaited(_loadBanner());
            });
          }
        },
      ),
    );

    _bannerAd = banner;
    await banner.load();
  }

  void _disposeBanner() {
    _bannerAd?.dispose();
    _bannerAd = null;
  }

  @override
  void dispose() {
    _disposeBanner();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.plan.isPro) {
      return const SizedBox.shrink();
    }

    if (_adLoaded && _bannerAd != null) {
      return SafeArea(
        top: false,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: SizedBox(
            width: double.infinity,
            height: _bannerAd!.size.height.toDouble(),
            child: Center(child: AdWidget(ad: _bannerAd!)),
          ),
        ),
      );
    }

    if (kDebugMode) {
      return SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          height: 50,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: Text(
            _lastError == null
                ? 'Ad loading… (${AdConfig.usesTestUnits ? 'test' : 'prod'})'
                : 'Ad failed: $_lastError',
            style: Theme.of(context).textTheme.labelSmall,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
