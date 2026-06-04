import 'package:rico_investidor/core/markets/supported_market_countries.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _countryCodeKey = 'preferred_market_country_code_v1';
const _countryNameKey = 'preferred_market_country_name_v1';

/// País de bolsa preferido do usuário — define o mercado exibido na home.
class MarketPreference {
  const MarketPreference({required this.code, required this.name});

  final String code;
  final String name;

  bool get isBrazil => code.toUpperCase() == 'BR';
}

class MarketPreferenceStorage {
  MarketPreferenceStorage._();
  static final MarketPreferenceStorage instance = MarketPreferenceStorage._();

  Future<MarketPreference?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_countryCodeKey);
    if (code == null || code.trim().isEmpty) return null;
    final name = prefs.getString(_countryNameKey) ?? code;
    return normalizeMarketPreference(
      MarketPreference(code: code.toUpperCase(), name: name),
    );
  }

  Future<void> save(MarketPreference preference) async {
    final normalized = normalizeMarketPreference(preference);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_countryCodeKey, normalized.code);
    await prefs.setString(_countryNameKey, normalized.name);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_countryCodeKey);
    await prefs.remove(_countryNameKey);
  }
}

final marketPreferenceStorage = MarketPreferenceStorage.instance;
