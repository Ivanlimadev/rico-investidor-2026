import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:rico_investidor/core/ads/ad_config.dart';
import 'package:rico_investidor/core/ads/ads_bootstrap.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/models/subscription_plan.dart';

/// In-feed ad: tries native template first, falls back to medium-rectangle banner.
class RicoFeedAd extends StatefulWidget {
  const RicoFeedAd({
    super.key,
    required this.plan,
    this.compactInsets = false,
  });

  final SubscriptionPlan plan;
  /// When true, omits horizontal padding (for use inside pre-padded scroll views).
  final bool compactInsets;

  @override
  State<RicoFeedAd> createState() => _RicoFeedAdState();
}

enum _FeedAdMode { loading, native, rectangle }

class _RicoFeedAdState extends State<RicoFeedAd> {
  NativeAd? _nativeAd;
  BannerAd? _rectangleAd;
  _FeedAdMode _mode = _FeedAdMode.loading;
  String? _lastError;
  var _started = false;

  @override
  void initState() {
    super.initState();
    if (!widget.plan.isPro) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_start());
      });
    }
  }

  @override
  void didUpdateWidget(covariant RicoFeedAd oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plan.isPro && !widget.plan.isPro) {
      _disposeAds();
      _mode = _FeedAdMode.loading;
      _started = false;
      unawaited(_start());
    }
    if (!oldWidget.plan.isPro && widget.plan.isPro) {
      _disposeAds();
      setState(() => _mode = _FeedAdMode.loading);
    }
  }

  Future<void> _start() async {
    if (_started || widget.plan.isPro || !mounted) return;
    _started = true;

    await AdsBootstrap.ensureInitialized();
    if (!mounted || widget.plan.isPro) return;

    await _loadNative();
  }

  Future<void> _loadNative() async {
    if (!mounted || widget.plan.isPro) return;

    _nativeAd?.dispose();
    _nativeAd = null;

    final theme = Theme.of(context);
    final native = NativeAd(
      adUnitId: AdConfig.nativeId,
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;
          setState(() {
            _mode = _FeedAdMode.native;
            _lastError = null;
          });
          if (kDebugMode) {
            debugPrint('[AdMob] feed native loaded');
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (kDebugMode) {
            debugPrint(
              '[AdMob] feed native failed (${error.code}): ${error.message} — trying rectangle',
            );
          }
          if (!mounted || widget.plan.isPro) return;
          unawaited(_loadRectangle());
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
  }

  Future<void> _loadRectangle() async {
    if (!mounted || widget.plan.isPro) return;

    _rectangleAd?.dispose();

    final rectangle = BannerAd(
      adUnitId: AdConfig.bannerId,
      size: AdSize.mediumRectangle,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;
          setState(() {
            _rectangleAd = ad as BannerAd;
            _mode = _FeedAdMode.rectangle;
            _lastError = null;
          });
          if (kDebugMode) {
            debugPrint('[AdMob] feed rectangle loaded');
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) return;
          setState(() => _lastError = '${error.code}: ${error.message}');
          if (kDebugMode) {
            debugPrint('[AdMob] feed rectangle failed: ${error.message}');
          }
        },
      ),
    );

    await rectangle.load();
  }

  void _disposeAds() {
    _nativeAd?.dispose();
    _nativeAd = null;
    _rectangleAd?.dispose();
    _rectangleAd = null;
  }

  @override
  void dispose() {
    _disposeAds();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.plan.isPro) {
      return const SizedBox.shrink();
    }

    final horizontal = widget.compactInsets ? 0.0 : 20.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 0),
      child: switch (_mode) {
        _FeedAdMode.native when _nativeAd != null => ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: double.infinity,
              height: 320,
              child: AdWidget(ad: _nativeAd!),
            ),
          ),
        _FeedAdMode.rectangle when _rectangleAd != null => Center(
            child: SizedBox(
              width: _rectangleAd!.size.width.toDouble(),
              height: _rectangleAd!.size.height.toDouble(),
              child: AdWidget(ad: _rectangleAd!),
            ),
          ),
        _ => _buildPlaceholder(context),
      },
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    if (!kDebugMode) {
      return const SizedBox(height: 1);
    }

    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Text(
        _lastError == null
            ? 'Feed ad loading…'
            : 'Feed ad failed: $_lastError',
        style: Theme.of(context).textTheme.labelSmall,
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Alias kept for existing imports.
typedef RicoNativeAd = RicoFeedAd;
