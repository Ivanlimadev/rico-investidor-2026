import 'package:rico_investidor/services/market_preference_storage.dart';

/// Países de bolsa disponíveis no app (temporário: só EUA e Brasil).
const supportedMarketCountryCodes = <String>{'US', 'BR'};

const defaultMarketPreference = MarketPreference(
  code: 'US',
  name: 'Estados Unidos',
);

bool isSupportedMarketCountry(String code) {
  return supportedMarketCountryCodes.contains(code.toUpperCase().trim());
}

/// Corrige preferência salva de mercados que foram desativados.
MarketPreference normalizeMarketPreference(MarketPreference preference) {
  if (isSupportedMarketCountry(preference.code)) {
    return MarketPreference(
      code: preference.code.toUpperCase(),
      name: preference.name,
    );
  }
  return defaultMarketPreference;
}
