import 'package:rico_investidor/core/config/api_config.dart';
import 'package:rico_investidor/core/utils/crypto_ticker_utils.dart';

/// Tickers com PNG embarcado em `assets/logos/` (offline).
const bundledLogoSymbols = {
  'ABEV3',
  'B3SA3',
  'BBAS3',
  'BBDC4',
  'BOVA11',
  'ELET3',
  'GGBR4',
  'HGLG11',
  'ITUB4',
  'IVVB11',
  'MGLU3',
  'PETR4',
  'PRIO3',
  'RENT3',
  'SUZB3',
  'VALE3',
  'WEGE3',
};

bool hasBundledLogo(String symbol) {
  return bundledLogoSymbols.contains(symbol.trim().toUpperCase());
}

String? localLogoAssetPath(String symbol) {
  final normalized = symbol.trim().toUpperCase();
  if (normalized.isEmpty || !hasBundledLogo(normalized)) return null;
  return 'assets/logos/$normalized.png';
}

String cryptoIconPngUrlFor(String symbol) {
  final slug = symbol.trim().toLowerCase();
  return 'https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/128/color/$slug.png';
}

String cryptoIconSvgUrlFor(String symbol) {
  final slug = symbol.trim().toLowerCase();
  return 'https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/svg/color/$slug.svg';
}

bool isCryptoIconUrl(String? url) {
  if (url == null || url.isEmpty) return false;
  return url.contains('cryptocurrency-icons') || url.contains('coincap.io');
}

bool looksLikeCryptoSymbol(String symbol) => isKnownCryptoTicker(symbol);

String? globalMarketLogoApiUrl(String symbol) {
  final normalized = symbol.trim().toUpperCase();
  if (normalized.isEmpty) return null;
  return '${ApiConfig.baseUrl}/v1/global-markets/${Uri.encodeComponent(normalized)}/logo.png';
}

String? cryptoLogoApiUrl(String symbol) {
  final normalized = symbol.trim().toUpperCase();
  if (normalized.isEmpty) return null;
  return '${ApiConfig.baseUrl}/v1/crypto/${Uri.encodeComponent(normalized)}/logo.png';
}

bool isUsExternalLogoUrl(String? url) {
  if (url == null || url.isEmpty) return false;
  return url.contains('financialmodelingprep.com') ||
      url.contains('parqet.com') ||
      url.contains('marketstack.com');
}

/// Fallback direto FMP — mesmo host usado pelo proxy do backend.
String? usLogoDirectUrl(String symbol) {
  final normalized = symbol.trim().toUpperCase().trim();
  if (normalized.isEmpty) return null;
  final fmpSymbol = _fmpApiSymbol(normalized);
  return 'https://financialmodelingprep.com/image-stock/$fmpSymbol.png';
}

String _fmpApiSymbol(String symbol) {
  if (symbol.contains('.')) {
    final dot = symbol.lastIndexOf('.');
    final base = symbol.substring(0, dot);
    final suffix = symbol.substring(dot + 1);
    if (suffix.length == 1 && suffix.contains(RegExp(r'^[A-Z]$'))) {
      return '$base.$suffix';
    }
    return base;
  }
  if (symbol.contains('-')) {
    final dash = symbol.lastIndexOf('-');
    final base = symbol.substring(0, dash);
    final suffix = symbol.substring(dash + 1);
    if (suffix.length == 1 && suffix.contains(RegExp(r'^[A-Z]$'))) {
      return '$base.$suffix';
    }
    return symbol;
  }
  return symbol;
}

String? resolveAssetLogoUrl(String symbol, String? logoUrl) {
  if (isApiLogoUrl(logoUrl)) {
    return logoUrl;
  }

  if (isUsExternalLogoUrl(logoUrl)) {
    return globalMarketLogoApiUrl(symbol);
  }

  if (logoUrl != null && logoUrl.isNotEmpty && isCryptoIconUrl(logoUrl)) {
    return cryptoLogoApiUrl(symbol);
  }

  if (looksLikeCryptoSymbol(symbol)) {
    return cryptoLogoApiUrl(symbol);
  }

  if (logoUrl != null && logoUrl.isNotEmpty && isRasterLogoUrl(logoUrl)) {
    if (looksLikeCryptoSymbol(symbol)) {
      return cryptoLogoApiUrl(symbol);
    }
    return globalMarketLogoApiUrl(symbol);
  }

  if (hasBundledLogo(symbol)) {
    return null;
  }

  if (!looksLikeCryptoSymbol(symbol)) {
    return globalMarketLogoApiUrl(symbol);
  }

  return null;
}

List<String> logoDownloadCandidates({
  required String symbol,
  String? resolvedUrl,
  String? originalLogoUrl,
}) {
  final seen = <String>{};
  final urls = <String>[];

  void add(String? url) {
    if (url == null || url.isEmpty || !seen.add(url)) return;
    if (!isApiLogoUrl(url) && !isRasterLogoUrl(url)) return;
    urls.add(url);
  }

  add(resolvedUrl);
  add(originalLogoUrl);

  if (looksLikeCryptoSymbol(symbol)) {
    add(cryptoLogoApiUrl(symbol));
    add(cryptoIconPngUrlFor(symbol));
  } else {
    add(globalMarketLogoApiUrl(symbol));
    add(usLogoDirectUrl(symbol));
  }

  return urls;
}

bool isSvgLogoUrl(String? url) {
  if (url == null || url.isEmpty) return false;
  final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
  return path.endsWith('.svg');
}

bool isRasterLogoUrl(String? url) {
  if (url == null || url.isEmpty) return false;
  final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
  return path.endsWith('.png') ||
      path.endsWith('.jpg') ||
      path.endsWith('.jpeg') ||
      path.endsWith('.webp');
}

bool isApiLogoUrl(String? url) {
  if (url == null || url.isEmpty) return false;
  return url.contains('/logo.png');
}

bool isLocalApiLogoUrl(String? url) {
  if (url == null || url.isEmpty) return false;
  return isApiLogoUrl(url) && url.startsWith(ApiConfig.baseUrl);
}
