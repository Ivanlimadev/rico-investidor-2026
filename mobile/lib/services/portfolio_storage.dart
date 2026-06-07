import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:rico_investidor/core/auth/secure_storage_config.dart';
import 'package:rico_investidor/models/dividend_payment.dart';
import 'package:rico_investidor/models/portfolio_holding.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _holdingsKey = 'portfolio_holdings_v1';
const _dividendsKey = 'portfolio_dividends_v1';

class PortfolioStorage {
  PortfolioStorage({
    FlutterSecureStorage? storage,
    Map<String, String>? memoryStore,
  })  : _storage = storage ?? secureStorage,
        _memoryStore = memoryStore;

  final FlutterSecureStorage _storage;
  final Map<String, String>? _memoryStore;

  Future<void> save({
    required List<PortfolioHolding> holdings,
    required List<DividendPayment> dividends,
  }) async {
    await _writeSecure(
      _holdingsKey,
      jsonEncode(holdings.map((h) => h.toJson()).toList()),
    );
    await _writeSecure(
      _dividendsKey,
      jsonEncode(dividends.map((d) => d.toJson()).toList()),
    );
  }

  Future<void> clear() async {
    if (_memoryStore != null) {
      _memoryStore!.remove(_holdingsKey);
      _memoryStore!.remove(_dividendsKey);
      return;
    }
    await _storage.delete(key: _holdingsKey);
    await _storage.delete(key: _dividendsKey);
  }

  Future<({List<PortfolioHolding> holdings, List<DividendPayment> dividends})?> load() async {
    final secureHoldings = await _readSecure(_holdingsKey);
    if (secureHoldings != null) {
      final secureDividends = await _readSecure(_dividendsKey);
      return _decodePortfolio(holdingsRaw: secureHoldings, dividendsRaw: secureDividends);
    }

    return _migrateFromLegacyPrefs();
  }

  Future<({List<PortfolioHolding> holdings, List<DividendPayment> dividends})?> _migrateFromLegacyPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final legacyHoldings = prefs.getString(_holdingsKey);
    if (legacyHoldings == null) return null;

    final legacyDividends = prefs.getString(_dividendsKey);
    final decoded = _decodePortfolio(holdingsRaw: legacyHoldings, dividendsRaw: legacyDividends);
    if (decoded == null) return null;

    await save(holdings: decoded.holdings, dividends: decoded.dividends);
    await prefs.remove(_holdingsKey);
    await prefs.remove(_dividendsKey);
    return decoded;
  }

  static ({List<PortfolioHolding> holdings, List<DividendPayment> dividends})? _decodePortfolio({
    required String holdingsRaw,
    String? dividendsRaw,
  }) {
    final holdingsJson = jsonDecode(holdingsRaw) as List<dynamic>;
    final dividendsJson = dividendsRaw == null
        ? const <dynamic>[]
        : jsonDecode(dividendsRaw) as List<dynamic>;

    return (
      holdings: holdingsJson
          .map((e) => PortfolioHolding.fromJson(e as Map<String, dynamic>))
          .toList(),
      dividends: dividendsJson
          .map((e) => DividendPayment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<void> _writeSecure(String key, String value) async {
    if (_memoryStore != null) {
      _memoryStore[key] = value;
      return;
    }
    await _storage.write(key: key, value: value);
  }

  Future<String?> _readSecure(String key) async {
    if (_memoryStore != null) {
      return _memoryStore[key];
    }
    return _storage.read(key: key);
  }
}
