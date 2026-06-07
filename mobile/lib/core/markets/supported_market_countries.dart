import 'package:rico_investidor/services/market_preference_storage.dart';

/// País de bolsa disponível no app.
const supportedMarketCountryCodes = <String>{'US'};

/// Nome exibido na home, onboarding e preferências salvas.
const kAmericanMarketDisplayName = 'Mercado Americano';

const defaultMarketPreference = MarketPreference(
  code: 'US',
  name: kAmericanMarketDisplayName,
);

bool isSupportedMarketCountry(String code) {
  return supportedMarketCountryCodes.contains(code.toUpperCase().trim());
}

MarketPreference normalizeMarketPreference(MarketPreference preference) {
  final code = preference.code.toUpperCase();
  if (!isSupportedMarketCountry(code)) {
    return defaultMarketPreference;
  }
  return const MarketPreference(code: 'US', name: kAmericanMarketDisplayName);
}
