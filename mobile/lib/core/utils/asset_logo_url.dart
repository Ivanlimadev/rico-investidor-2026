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

/// Sempre usa a API local; ignora SVG/URLs externas da Brapi.
String? resolveAssetLogoUrl(String symbol, String? logoUrl, {required bool isFii}) {
  return assetLogoApiUrl(symbol, isFii: isFii);
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
