import 'package:rico_investidor/core/widgets/asset_country_flag.dart';
import 'package:rico_investidor/models/asset_item.dart';

/// Pontuação de relevância — maior = aparece primeiro.
int scoreAssetSearchMatch(AssetItem asset, String query) {
  final q = query.trim().toUpperCase();
  if (q.isEmpty) return 0;

  final sym = _normalizeSearchSymbol(asset.symbol);
  final name = asset.name.trim().toUpperCase();

  if (sym == q) return 1000;
  if (sym.startsWith(q)) return 850 - (sym.length - q.length);

  final root = b3TickerRoot(q);
  if (root != null && root.length == 4 && sym.startsWith(root)) {
    return 780 - (sym.length - root.length);
  }

  if (sym.contains(q)) return 650;
  if (name == q) return 600;
  if (name.startsWith(q)) return 500;
  if (name.contains(q)) return 350;

  return 0;
}

String _normalizeSearchSymbol(String symbol) {
  final upper = symbol.trim().toUpperCase();
  const suffixes = ['USDT', 'BRL', 'USD'];
  for (final suffix in suffixes) {
    if (upper.endsWith(suffix) && upper.length > suffix.length) {
      return upper.substring(0, upper.length - suffix.length);
    }
  }
  final dash = upper.indexOf('-');
  if (dash > 0) return upper.substring(0, dash);
  return upper;
}

/// Bônus quando o ativo pertence ao mercado preferido do usuário (BR/US).
const kMarketPreferenceSearchBonus = 250;

int marketPreferenceSearchBonus(AssetItem asset, String? preferredCountryCode) {
  if (preferredCountryCode == null || preferredCountryCode.trim().isEmpty) {
    return 0;
  }
  final assetCountry = countryCodeForAsset(asset);
  if (assetCountry == null) return 0;
  return assetCountry.toUpperCase() == preferredCountryCode.trim().toUpperCase()
      ? kMarketPreferenceSearchBonus
      : 0;
}

List<AssetItem> rankAndDedupeSearchResults(
  List<AssetItem> items,
  String query, {
  String? preferredCountryCode,
}) {
  if (items.isEmpty) return const [];

  final bestBySymbol = <String, AssetItem>{};
  final bestScore = <String, int>{};

  for (final asset in items) {
    final key = asset.symbol.trim().toUpperCase();
    final score = scoreAssetSearchMatch(asset, query) +
        marketPreferenceSearchBonus(asset, preferredCountryCode);
    if (score <= 0) continue;

    final previous = bestScore[key];
    if (previous == null || score > previous) {
      bestBySymbol[key] = asset;
      bestScore[key] = score;
    }
  }

  final ranked = bestBySymbol.entries.toList()
    ..sort((a, b) {
      final scoreCmp = bestScore[b.key]!.compareTo(bestScore[a.key]!);
      if (scoreCmp != 0) return scoreCmp;
      return a.key.compareTo(b.key);
    });

  return ranked.map((entry) => entry.value).toList();
}

bool looksLikeObviousCryptoTicker(String query) {
  final normalized = query.trim().toUpperCase();
  if (normalized.length < 2 || normalized.length > 12) return false;
  if (normalized.contains('-') || normalized.contains('/')) return false;
  if (RegExp(r'\d$').hasMatch(normalized) && normalized.length >= 5) return false;
  return RegExp(r'^[A-Z0-9]+$').hasMatch(normalized);
}

bool looksLikeCurrencySearchQuery(String query) {
  final upper = query.trim().toUpperCase();
  return upper.contains('-') ||
      upper.contains('/') ||
      upper.contains('BRL') ||
      upper.contains('USD') ||
      upper.contains('EUR');
}

bool looksLikeTreasurySearchQuery(String query) {
  final lower = query.trim().toLowerCase();
  return lower.contains('tesouro') || lower.startsWith('td');
}

bool looksLikeIndexSearchQuery(String query) {
  final normalized = query.trim().toUpperCase();
  if (normalized.startsWith('^')) return true;
  return {
    'IFIX',
    'IDIV',
    'SMLL',
    'IFNC',
    'IMAT',
    'INDX',
    'IMOB',
    'ICON',
    'IEE',
    'UTIL',
    'IBOV',
    'IBOVESPA',
  }.contains(normalized);
}

bool looksLikeB3TickerQuery(String query) {
  final normalized = query.trim().toUpperCase();
  return RegExp(r'^[A-Z]{4}\d{1,2}$').hasMatch(normalized);
}

/// Raiz B3 (4 letras) — KLBN, KLBN4, KLBN11 → KLBN.
String? b3TickerRoot(String query) {
  final normalized = query.trim().toUpperCase().replaceAll('.SA', '');
  final match = RegExp(r'^([A-Z]{4})').firstMatch(normalized);
  return match?.group(1);
}

bool looksLikeB3FourLetterPrefix(String query) {
  return RegExp(r'^[A-Z]{4}$').hasMatch(query.trim().toUpperCase());
}

bool shouldRunB3QuoteSearch(String query) {
  final normalized = query.trim().toUpperCase();
  if (looksLikeB3FourLetterPrefix(normalized)) return true;
  if (looksLikeB3TickerQuery(normalized)) return true;
  if (b3TickerRoot(normalized) != null) return true;
  if (!looksLikeObviousCryptoTicker(normalized)) return true;
  return normalized.length > 4;
}

bool shouldTryExactSymbolLookup(String query) {
  final normalized = query.trim().toUpperCase();
  if (looksLikeB3TickerQuery(normalized)) return true;
  if (looksLikeB3FourLetterPrefix(normalized)) return true;
  if (_looksLikeUsTickerForSearch(normalized)) return true;
  if (looksLikeObviousCryptoTicker(normalized) && !looksLikeB3FourLetterPrefix(normalized)) {
    return true;
  }
  return false;
}

bool _looksLikeUsTickerForSearch(String symbol) {
  if (symbol.endsWith('.SA')) return false;
  if (RegExp(r'^[A-Z]{4}\d{2}$').hasMatch(symbol)) return false;
  if (symbol.length >= 2) {
    final suffix = symbol.substring(symbol.length - 2);
    if ({'11', '34', '35', '39'}.contains(suffix)) return false;
  }
  return RegExp(r'^[A-Z]{1,5}([.-][A-Z])?$').hasMatch(symbol);
}
