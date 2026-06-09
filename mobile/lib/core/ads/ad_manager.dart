import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:rico_investidor/core/ads/ad_config.dart';
import 'package:rico_investidor/core/ads/ads_bootstrap.dart';
import 'package:rico_investidor/models/subscription_plan.dart';

class AdManager {
  AdManager._();
  static final AdManager instance = AdManager._();

  InterstitialAd? _interstitial;
  DateTime? _lastInterstitialShown;
  bool _loadingInterstitial = false;

  int get _minIntervalSeconds =>
      kDebugMode ? 45 : AdConfig.interstitialMinIntervalSeconds;

  Future<void> preloadInterstitial() async {
    if (_loadingInterstitial || _interstitial != null) return;
    await AdsBootstrap.ensureInitialized();
    if (_loadingInterstitial || _interstitial != null) return;

    _loadingInterstitial = true;
    if (kDebugMode) {
      debugPrint('[AdMob] preloading interstitial…');
    }

    await InterstitialAd.load(
      adUnitId: AdConfig.interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _loadingInterstitial = false;
          if (kDebugMode) {
            debugPrint('[AdMob] interstitial ready');
          }
        },
        onAdFailedToLoad: (error) {
          _interstitial = null;
          _loadingInterstitial = false;
          if (kDebugMode) {
            debugPrint(
              '[AdMob] interstitial load failed (${error.code}): ${error.message}',
            );
          }
        },
      ),
    );
  }

  Future<void> showInterstitialIfReady(SubscriptionPlan plan) async {
    if (plan.isPro) {
      if (kDebugMode) debugPrint('[AdMob] interstitial skipped — Pro plan');
      return;
    }

    if (_interstitial == null) {
      if (kDebugMode) {
        debugPrint('[AdMob] interstitial not ready — preloading for next time');
      }
      unawaited(preloadInterstitial());
      return;
    }

    final now = DateTime.now();
    if (_lastInterstitialShown != null) {
      final elapsed = now.difference(_lastInterstitialShown!).inSeconds;
      if (elapsed < _minIntervalSeconds) {
        if (kDebugMode) {
          debugPrint(
            '[AdMob] interstitial cooldown (${_minIntervalSeconds - elapsed}s left)',
          );
        }
        return;
      }
    }

    final ad = _interstitial!;
    _interstitial = null;
    _lastInterstitialShown = now;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        if (kDebugMode) debugPrint('[AdMob] interstitial showing');
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        unawaited(preloadInterstitial());
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        if (kDebugMode) {
          debugPrint('[AdMob] interstitial show failed: ${error.message}');
        }
        unawaited(preloadInterstitial());
      },
    );

    await ad.show();
  }
}

final adManager = AdManager.instance;
