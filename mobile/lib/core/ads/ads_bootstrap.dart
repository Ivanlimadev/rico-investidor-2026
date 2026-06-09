import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:rico_investidor/core/ads/ad_manager.dart';

/// Ensures [MobileAds.instance.initialize] completes before any ad loads.
class AdsBootstrap {
  AdsBootstrap._();

  static Future<void>? _future;
  static var _ready = false;

  static bool get isReady => _ready;

  static Future<void> ensureInitialized() {
    return _future ??= _initialize();
  }

  static Future<void> _initialize() async {
    try {
      final status = await MobileAds.instance.initialize();
      _ready = true;
      if (kDebugMode) {
        debugPrint('[AdMob] SDK ready: $status');
      }

      unawaited(adManager.preloadInterstitial());

      final params = ConsentRequestParameters();
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          if (await ConsentInformation.instance.isConsentFormAvailable()) {
            await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
          }
        },
        (error) {
          if (kDebugMode) {
            debugPrint('[AdMob] consent update failed: $error');
          }
        },
      );
    } catch (error, stack) {
      if (kDebugMode) {
        debugPrint('[AdMob] initialize failed: $error\n$stack');
      }
    }
  }
}
