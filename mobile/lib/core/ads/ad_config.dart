import 'dart:io';

import 'package:flutter/foundation.dart';

/// Google AdMob IDs — Rico Investidor.
/// Debug builds use Google test units (always fill).
/// Release builds use production units.
abstract final class AdConfig {
  static const String appIdAndroid = 'ca-app-pub-7113858977365190~5603278090';
  static const String appIdIOS = 'ca-app-pub-7113858977365190~7653353211';

  // Production
  static const String _bannerAndroid = 'ca-app-pub-7113858977365190/8117760795';
  static const String _bannerIOS = 'ca-app-pub-7113858977365190/6464394622';
  static const String _interstitialAndroid = 'ca-app-pub-7113858977365190/5028563028';
  static const String _interstitialIOS = 'ca-app-pub-7113858977365190/9897746328';
  static const String _nativeAndroid = 'ca-app-pub-7113858977365190/4496706831';
  static const String _nativeIOS = 'ca-app-pub-7113858977365190/7271582986';

  // Google official test units (guaranteed fill in development)
  static const String _testBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testBannerIOS = 'ca-app-pub-3940256099942544/2934735716';
  static const String _testInterstitialAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testInterstitialIOS = 'ca-app-pub-3940256099942544/4411468910';
  static const String _testNativeAndroid = 'ca-app-pub-3940256099942544/2247696110';
  static const String _testNativeIOS = 'ca-app-pub-3940256099942544/3986624511';

  static bool get usesTestUnits => kDebugMode;

  static String get bannerId => _pick(
        productionAndroid: _bannerAndroid,
        productionIOS: _bannerIOS,
        testAndroid: _testBannerAndroid,
        testIOS: _testBannerIOS,
      );

  static String get interstitialId => _pick(
        productionAndroid: _interstitialAndroid,
        productionIOS: _interstitialIOS,
        testAndroid: _testInterstitialAndroid,
        testIOS: _testInterstitialIOS,
      );

  static String get nativeId => _pick(
        productionAndroid: _nativeAndroid,
        productionIOS: _nativeIOS,
        testAndroid: _testNativeAndroid,
        testIOS: _testNativeIOS,
      );

  static String _pick({
    required String productionAndroid,
    required String productionIOS,
    required String testAndroid,
    required String testIOS,
  }) {
    if (kDebugMode) {
      return Platform.isIOS ? testIOS : testAndroid;
    }
    return Platform.isIOS ? productionIOS : productionAndroid;
  }

  static const int interstitialMinIntervalSeconds = 180;
}
