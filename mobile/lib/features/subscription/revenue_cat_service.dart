import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class RevenueCatService {
  RevenueCatService._();

  static const _apiKey = String.fromEnvironment('REVENUECAT_API_KEY');

  var _configured = false;

  bool get isConfigured => _configured && _apiKey.isNotEmpty;

  String? get configurationError {
    if (_apiKey.isEmpty) {
      return 'RevenueCat API key missing. Pass --dart-define=REVENUECAT_API_KEY=... at build time.';
    }
    return null;
  }

  Future<void> configure({required String appUserId}) async {
    if (_apiKey.isEmpty) {
      _configured = false;
      return;
    }

    await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.warn);
    final config = PurchasesConfiguration(_apiKey)..appUserID = appUserId;
    await Purchases.configure(config);
    _configured = true;
  }

  Future<List<Package>> fetchOfferings() async {
    if (!isConfigured) return const [];
    final offerings = await Purchases.getOfferings();
    return offerings.current?.availablePackages ?? const [];
  }

  Future<CustomerInfo?> purchasePackage(Package package) async {
    if (!isConfigured) return null;
    return Purchases.purchasePackage(package);
  }

  Future<CustomerInfo?> restorePurchases() async {
    if (!isConfigured) return null;
    return Purchases.restorePurchases();
  }

  Future<bool> hasActiveProEntitlement() async {
    if (!isConfigured) return false;
    final info = await Purchases.getCustomerInfo();
    return info.entitlements.active.containsKey('pro');
  }
}

final revenueCatService = RevenueCatService._();
