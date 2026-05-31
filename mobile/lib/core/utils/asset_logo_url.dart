import 'package:rico_investidor/core/config/api_config.dart';

String? b3IconPngUrlFor(String symbol) {
  final normalized = symbol.trim().toUpperCase();
  if (normalized.isEmpty) return null;
  return 'https://raw.githubusercontent.com/thefintz/icones-b3/main/icones/$normalized.png';
}

/// Logo via API local — mesmo host da cotação (funciona no simulador/dispositivo).
String? assetLogoApiUrl(String symbol, {required bool isFii}) {
  final normalized = symbol.trim().toUpperCase();
  if (normalized.isEmpty) return null;
  final base = ApiConfig.baseUrl;
  if (isFii) {
    return '$base/v1/fiis/$normalized/logo.png';
  }
  return '$base/v1/quotes/$normalized/logo.png';
}

/// Tickers com PNG embarcado no app — carregam offline, sem depender da API.
const bundledLogoSymbols = {
  'PETR4',
  'VALE3',
  'ITUB4',
  'MGLU3',
  'BBDC4',
  'ABEV3',
  'WEGE3',
  'BBAS3',
  'RENT3',
  'HGLG11',
};

bool hasBundledLogo(String symbol) {
  return bundledLogoSymbols.contains(symbol.trim().toUpperCase());
}

String? localLogoAssetPath(String symbol) {
  final normalized = symbol.trim().toUpperCase();
  if (normalized.isEmpty || !hasBundledLogo(normalized)) return null;
  return 'assets/logos/$normalized.png';
}

/// Legado Brapi — SVG quebra no flutter_svg.
String? brapiLogoUrlFor(String symbol) {
  final normalized = symbol.trim().toUpperCase();
  if (normalized.isEmpty) return null;
  return 'https://icons.brapi.dev/icons/$normalized.svg';
}

/// Ícones raster — mais rápidos que SVG em listas pequenas.
String cryptoIconPngUrlFor(String symbol) {
  final slug = symbol.trim().toLowerCase();
  return 'https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/32@2x/icon/$slug.png';
}

/// SVG colorido — legado / detalhes grandes.
String cryptoIconSvgUrlFor(String symbol) {
  final slug = symbol.trim().toLowerCase();
  return 'https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/svg/color/$slug.svg';
}

bool isCryptoIconUrl(String? url) {
  if (url == null || url.isEmpty) return false;
  return url.contains('cryptocurrency-icons');
}

bool looksLikeCryptoSymbol(String symbol) {
  final normalized = symbol.trim().toUpperCase();
  if (normalized.contains('-') || normalized.contains('/')) return false;
  if (normalized.length < 2 || normalized.length > 12) return false;
  if (RegExp(r'\d$').hasMatch(normalized) && normalized.length >= 5) return false;
  return RegExp(r'^[A-Z0-9]+$').hasMatch(normalized);
}

/// Logo via API local — ações americanas (Marketstack).
String? globalMarketLogoApiUrl(String symbol) {
  final normalized = symbol.trim().toUpperCase();
  if (normalized.isEmpty) return null;
  return '${ApiConfig.baseUrl}/v1/global-markets/${Uri.encodeComponent(normalized)}/logo.png';
}

bool isUsExternalLogoUrl(String? url) {
  if (url == null || url.isEmpty) return false;
  return url.contains('financialmodelingprep.com') || url.contains('parqet.com');
}

bool looksLikeB3Ticker(String symbol) {
  final normalized = symbol.trim().toUpperCase();
  return RegExp(r'^[A-Z]{4}\d{1,2}$').hasMatch(normalized);
}

/// Sempre usa a API local para FII; B3 usa PNG direto (icones-b3); cripto usa CDN.
String? resolveAssetLogoUrl(String symbol, String? logoUrl, {required bool isFii}) {
  if (isFii) {
    return assetLogoApiUrl(symbol, isFii: true);
  }

  // URL já resolvida para o proxy local (ex.: /v1/global-markets/NVDA/logo.png).
  // Sem este short-circuit, tickers como NVDA/AAPL/TM caem no ramo de cripto
  // (heurística looksLikeCryptoSymbol) e a logo correta é descartada.
  if (isApiLogoUrl(logoUrl)) {
    return logoUrl;
  }

  if (isUsExternalLogoUrl(logoUrl)) {
    return globalMarketLogoApiUrl(symbol);
  }

  if (logoUrl != null && logoUrl.isNotEmpty && isCryptoIconUrl(logoUrl)) {
    return cryptoIconPngUrlFor(symbol);
  }

  if (looksLikeCryptoSymbol(symbol)) {
    return cryptoIconPngUrlFor(symbol);
  }

  if (looksLikeB3Ticker(symbol)) {
    if (logoUrl != null && logoUrl.isNotEmpty && isRasterLogoUrl(logoUrl)) {
      return logoUrl;
    }
    return b3IconPngUrlFor(symbol);
  }

  return assetLogoApiUrl(symbol, isFii: false);
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
