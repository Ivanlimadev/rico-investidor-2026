import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:rico_investidor/core/ads/ad_config.dart';
import 'package:rico_investidor/core/ads/ads_bootstrap.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/models/subscription_plan.dart';

class RicoNativeAd extends StatefulWidget {
  const RicoNativeAd({super.key, required this.plan});

  final SubscriptionPlan plan;

  @override
  State<RicoNativeAd> createState() => _RicoNativeAdState();
}

class _RicoNativeAdState extends State<RicoNativeAd> {
  NativeAd? _nativeAd;
  var _adLoaded = false;
  var _loading = false;
  var _retryCount = 0;
  String? _lastError;
  static const _maxRetries = 5;

  @override
  void initState() {
    super.initState();
    if (!widget.plan.isPro) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_loadNative());
      });
    }
  }

  @override
  void didUpdateWidget(covariant RicoNativeAd oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plan.isPro && !widget.plan.isPro) {
      _retryCount = 0;
      unawaited(_loadNative());
    }
    if (!oldWidget.plan.isPro && widget.plan.isPro) {
      _nativeAd?.dispose();
      _nativeAd = null;
      setState(() {
        _adLoaded = false;
        _lastError = null;
      });
    }
  }

  Future<void> _loadNative() async {
    if (widget.plan.isPro || _loading || !mounted) return;
    _loading = true;

    await AdsBootstrap.ensureInitialized();
    if (!mounted || widget.plan.isPro) {
      _loading = false;
      return;
    }

    _nativeAd?.dispose();
    setState(() {
      _adLoaded = false;
      _lastError = null;
    });

    final theme = Theme.of(context);
    final native = NativeAd(
      adUnitId: AdConfig.nativeId,
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          _loading = false;
          if (!mounted) return;
          setState(() => _adLoaded = true);
          if (kDebugMode) {
            debugPrint('[AdMob] native loaded (${AdConfig.nativeId})');
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _loading = false;
          if (kDebugMode) {
            debugPrint(
              '[AdMob] native failed (${error.code}): ${error.message}',
            );
          }
          if (!mounted || widget.plan.isPro) return;
          setState(() => _lastError = '${error.code}: ${error.message}');
          if (_retryCount < _maxRetries) {
            _retryCount++;
            Future.delayed(Duration(seconds: 2 * _retryCount), () {
              if (mounted && !widget.plan.isPro) unawaited(_loadNative());
            });
          }
        },
      ),
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: theme.cardColor,
        cornerRadius: 16,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: AppColors.primary,
          style: NativeTemplateFontStyle.bold,
          size: 14,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: theme.colorScheme.onSurface,
          style: NativeTemplateFontStyle.bold,
          size: 14,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          style: NativeTemplateFontStyle.normal,
          size: 12,
        ),
      ),
    );

    _nativeAd = native;
    await native.load();
    _loading = false;
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.plan.isPro) {
      return const SizedBox.shrink();
    }

    if (_adLoaded && _nativeAd != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: double.infinity,
            height: 300,
            child: AdWidget(ad: _nativeAd!),
          ),
        ),
      );
    }

    if (kDebugMode) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Container(
          width: double.infinity,
          height: 120,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            _lastError == null
                ? 'Native ad loading… (${AdConfig.usesTestUnits ? 'test' : 'prod'})'
                : 'Native ad failed: $_lastError',
            style: Theme.of(context).textTheme.labelSmall,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
