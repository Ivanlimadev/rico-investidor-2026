import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:rico_investidor/core/auth/auth_session.dart';
import 'package:rico_investidor/core/utils/asset_logo_url.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/models/market_category_theme.dart';

enum AssetLogoStyle {
  /// Moldura neutra — listas e detalhes.
  standard,

  /// Logo colorido em tela cheia + brilho — carteira.
  vibrant,
}

final _svgCache = <String, String>{};
final _rasterCache = <String, Uint8List>{};
final _inFlightSvg = <String, Future<String?>>{};
final _inFlightRaster = <String, Future<Uint8List?>>{};
const _networkTimeout = Duration(seconds: 6);
const _svgTimeout = Duration(seconds: 8);
const _maxLogoCacheEntries = 512;

void _trimLogoCache<K, V>(Map<K, V> cache) {
  if (cache.length <= _maxLogoCacheEntries) return;
  cache.remove(cache.keys.first);
}

Future<String?> loadAssetLogoSvg(String url) {
  final cached = _svgCache[url];
  if (cached != null) return Future.value(cached);

  return _inFlightSvg.putIfAbsent(url, () async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(_svgTimeout);
      final body = response.body;
      if (response.statusCode == 200 && body.contains('<svg')) {
        _svgCache[url] = body;
        _trimLogoCache(_svgCache);
        return body;
      }
    } catch (_) {}
    return null;
  }).whenComplete(() => _inFlightSvg.remove(url));
}

bool _isValidRasterBytes(Uint8List bytes) {
  if (bytes.length < 12) return false;
  // PNG
  if (bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return true;
  }
  // JPEG
  if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
    return true;
  }
  // WEBP (RIFF....WEBP)
  if (bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return true;
  }
  return false;
}

Future<Uint8List?> loadAssetLogoRaster(String url, {Map<String, String>? headers}) async {
  final cached = _rasterCache[url];
  if (cached != null) {
    if (_isValidRasterBytes(cached)) return Future.value(cached);
    _rasterCache.remove(url);
  }

  return _inFlightRaster.putIfAbsent(url, () async {
    try {
      final response = await http
          .get(Uri.parse(url), headers: headers ?? const {})
          .timeout(_networkTimeout);
      final bytes = response.bodyBytes;
      if (response.statusCode == 200 && bytes.length > 64 && _isValidRasterBytes(bytes)) {
        _rasterCache[url] = bytes;
        _trimLogoCache(_rasterCache);
        return bytes;
      }
    } catch (_) {}
    return null;
  }).whenComplete(() => _inFlightRaster.remove(url));
}

Map<String, String> _logoRequestHeaders(String url) {
  if (!isLocalApiLogoUrl(url)) return const {};
  final token = authSession.accessToken;
  if (token == null || token.isEmpty) return const {};
  return {'Authorization': 'Bearer $token'};
}

Future<void> warmAssetLogoSymbols(Iterable<String> symbols) async {
  await Future.wait(
    symbols.map((symbol) async {
      if (hasBundledLogo(symbol)) return;
      final isFii = looksLikeFiiTicker(symbol);
      final resolved = resolveAssetLogoUrl(symbol, null, isFii: isFii);
      for (final url in logoDownloadCandidates(
        symbol: symbol,
        isFii: isFii,
        resolvedUrl: resolved,
      )) {
        final bytes = await loadAssetLogoRaster(url, headers: _logoRequestHeaders(url));
        if (bytes != null) return;
      }
    }),
    eagerError: false,
  );
}

Future<void> precacheCryptoLogos(Iterable<String> symbols) async {
  final urls = symbols
      .where(looksLikeCryptoSymbol)
      .map(cryptoLogoApiUrl)
      .whereType<String>()
      .toSet();
  if (urls.isEmpty) return;

  await Future.wait(
    urls.map((url) => loadAssetLogoRaster(url, headers: _logoRequestHeaders(url))),
    eagerError: false,
  );
}

class AssetLogo extends StatelessWidget {
  const AssetLogo({
    super.key,
    required this.symbol,
    this.logoUrl,
    this.size = 40,
    this.borderRadius = 8,
    this.style = AssetLogoStyle.vibrant,
  });

  final String symbol;
  final String? logoUrl;
  final double size;
  final double borderRadius;
  final AssetLogoStyle style;

  @override
  Widget build(BuildContext context) {
    final isFii = looksLikeFiiTicker(symbol);

    if (hasBundledLogo(symbol)) {
      return SizedBox(
        width: size,
        height: size,
        child: _BundledAssetLogo(
          symbol: symbol,
          size: size,
          borderRadius: borderRadius,
          isFii: isFii,
          style: style,
        ),
      );
    }

    final resolvedUrl = resolveAssetLogoUrl(symbol, logoUrl, isFii: isFii);

    if (looksLikeCryptoSymbol(symbol) &&
        resolvedUrl != null &&
        !isApiLogoUrl(resolvedUrl) &&
        isRasterLogoUrl(resolvedUrl)) {
      return SizedBox(
        width: size,
        height: size,
        child: _CryptoNetworkLogo(
          url: resolvedUrl,
          symbol: symbol,
          size: size,
          borderRadius: borderRadius,
          isFii: isFii,
          style: style,
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: resolvedUrl == null
          ? _TickerFallback(
              symbol: symbol,
              size: size,
              borderRadius: borderRadius,
              isFii: isFii,
              style: style,
            )
          : _RemoteAssetLogo(
              url: resolvedUrl,
              symbol: symbol,
              size: size,
              borderRadius: borderRadius,
              isFii: isFii,
              style: style,
            ),
    );
  }
}

class _CryptoNetworkLogo extends StatelessWidget {
  const _CryptoNetworkLogo({
    required this.url,
    required this.symbol,
    required this.size,
    required this.borderRadius,
    required this.isFii,
    required this.style,
  });

  final String url;
  final String symbol;
  final double size;
  final double borderRadius;
  final bool isFii;
  final AssetLogoStyle style;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheSize = (size * dpr).round().clamp(32, 128);
    final vibrant = style == AssetLogoStyle.vibrant;
    final innerSize = vibrant ? size : size * 0.84;

    Widget placeholder({bool loading = false}) {
      return _TickerFallback(
        symbol: symbol,
        size: size,
        borderRadius: borderRadius,
        isFii: isFii,
        style: style,
        loading: loading,
      );
    }

    final image = Image.network(
      url,
      width: innerSize,
      height: innerSize,
      fit: vibrant ? BoxFit.cover : BoxFit.contain,
      cacheWidth: cacheSize,
      cacheHeight: cacheSize,
      gaplessPlayback: true,
      filterQuality: FilterQuality.low,
      errorBuilder: (context, error, stackTrace) => placeholder(),
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return placeholder();
      },
    );

    return _LogoImageShell(
      symbol: symbol,
      size: size,
      borderRadius: borderRadius,
      isFii: isFii,
      style: style,
      child: vibrant
          ? image
          : Padding(padding: EdgeInsets.all(size * 0.08), child: image),
    );
  }
}

class _BundledAssetLogo extends StatelessWidget {
  const _BundledAssetLogo({
    required this.symbol,
    required this.size,
    required this.borderRadius,
    required this.isFii,
    required this.style,
  });

  final String symbol;
  final double size;
  final double borderRadius;
  final bool isFii;
  final AssetLogoStyle style;

  @override
  Widget build(BuildContext context) {
    final assetPath = localLogoAssetPath(symbol);
    if (assetPath == null) {
      return _TickerFallback(
        symbol: symbol,
        size: size,
        borderRadius: borderRadius,
        isFii: isFii,
        style: style,
      );
    }

    return _LogoImageShell(
      symbol: symbol,
      size: size,
      borderRadius: borderRadius,
      isFii: isFii,
      style: style,
      image: AssetImage(assetPath),
    );
  }
}

class _RemoteAssetLogo extends StatefulWidget {
  const _RemoteAssetLogo({
    required this.url,
    required this.symbol,
    required this.size,
    required this.borderRadius,
    required this.isFii,
    required this.style,
  });

  final String url;
  final String symbol;
  final double size;
  final double borderRadius;
  final bool isFii;
  final AssetLogoStyle style;

  @override
  State<_RemoteAssetLogo> createState() => _RemoteAssetLogoState();
}

class _RemoteAssetLogoState extends State<_RemoteAssetLogo> {
  Uint8List? _bytes;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _RemoteAssetLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _bytes = null;
      _finished = false;
      _load();
    }
  }

  Future<void> _load() async {
    if (isSvgLogoUrl(widget.url) && !isApiLogoUrl(widget.url)) {
      if (mounted) setState(() => _finished = true);
      return;
    }

    final candidates = logoDownloadCandidates(
      symbol: widget.symbol,
      isFii: widget.isFii,
      resolvedUrl: widget.url,
    );

    Uint8List? bytes;
    for (final url in candidates) {
      bytes = await loadAssetLogoRaster(url, headers: _logoRequestHeaders(url));
      if (bytes != null) break;
    }

    if (!mounted) return;
    setState(() {
      _bytes = bytes;
      _finished = true;
    });
  }

  Widget _fallback({bool loading = false}) {
    return _TickerFallback(
      symbol: widget.symbol,
      size: widget.size,
      borderRadius: widget.borderRadius,
      isFii: widget.isFii,
      style: widget.style,
      loading: loading,
    );
  }

  Widget _buildCryptoPng() {
    final pngUrl = cryptoIconPngUrlFor(widget.symbol);
    return FutureBuilder<Uint8List?>(
      future: loadAssetLogoRaster(pngUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _fallback(loading: true);
        }

        final bytes = snapshot.data;
        if (bytes != null) {
          return _LogoImageShell(
            symbol: widget.symbol,
            size: widget.size,
            borderRadius: widget.borderRadius,
            isFii: widget.isFii,
            style: widget.style,
            image: MemoryImage(bytes),
          );
        }

        return _fallback();
      },
    );
  }

  Widget _buildBundled() {
    final assetPath = localLogoAssetPath(widget.symbol);
    if (assetPath == null) return _fallback();

    return _LogoImageShell(
      symbol: widget.symbol,
      size: widget.size,
      borderRadius: widget.borderRadius,
      isFii: widget.isFii,
      style: widget.style,
      image: AssetImage(assetPath),
    );
  }

  Widget _buildSvg(String svg) {
    final vibrant = widget.style == AssetLogoStyle.vibrant;
    final innerSize = vibrant ? widget.size : widget.size * 0.84;

    try {
      final logo = SvgPicture.string(
        svg,
        width: innerSize,
        height: innerSize,
        fit: vibrant ? BoxFit.cover : BoxFit.contain,
        clipBehavior: Clip.hardEdge,
      );
      return _LogoImageShell(
        symbol: widget.symbol,
        size: widget.size,
        borderRadius: widget.borderRadius,
        isFii: widget.isFii,
        style: widget.style,
        child: vibrant
            ? logo
            : Padding(padding: EdgeInsets.all(widget.size * 0.08), child: logo),
      );
    } catch (_) {
      return _buildBundled();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes != null) {
      return _LogoImageShell(
        symbol: widget.symbol,
        size: widget.size,
        borderRadius: widget.borderRadius,
        isFii: widget.isFii,
        style: widget.style,
        image: MemoryImage(_bytes!),
      );
    }

    if (!_finished) {
      return _fallback(loading: true);
    }

    if (isSvgLogoUrl(widget.url) && !isApiLogoUrl(widget.url)) {
      return FutureBuilder<String?>(
        future: loadAssetLogoSvg(widget.url),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return _fallback(loading: true);
          }

          final svg = snapshot.data;
          if (svg != null) {
            return _buildSvg(svg);
          }

          if (looksLikeCryptoSymbol(widget.symbol)) {
            return _buildCryptoPng();
          }

          return _buildBundled();
        },
      );
    }

    return _buildBundled();
  }
}

class _LogoImageShell extends StatelessWidget {
  const _LogoImageShell({
    required this.symbol,
    required this.size,
    required this.borderRadius,
    required this.isFii,
    required this.style,
    this.image,
    this.child,
  });

  final String symbol;
  final double size;
  final double borderRadius;
  final bool isFii;
  final AssetLogoStyle style;
  final ImageProvider? image;
  final Widget? child;

  Widget _fallback() {
    return _TickerFallback(
      symbol: symbol,
      size: size,
      borderRadius: borderRadius,
      isFii: isFii,
      style: style,
    );
  }

  @override
  Widget build(BuildContext context) {
    final vibrant = style == AssetLogoStyle.vibrant;
    final innerSize = vibrant ? size : size * 0.84;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logoBackground = isDark ? const Color(0xFF232B36) : const Color(0xFFF4F6F8);
    final logoBorder = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
    final glowColor = (isFii
            ? MarketCategory.fiis
            : looksLikeCryptoSymbol(symbol)
                ? MarketCategory.cripto
                : MarketCategory.acoesBr)
        .theme
        .accentColor;

    final content = child ??
        Image(
          image: image!,
          fit: vibrant ? BoxFit.cover : BoxFit.contain,
          width: innerSize,
          height: innerSize,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) return child;
            return _fallback();
          },
          errorBuilder: (context, error, stackTrace) => _fallback(),
        );

    if (vibrant) {
      return _VibrantShell(
        size: size,
        borderRadius: borderRadius,
        glowColor: glowColor,
        child: content,
      );
    }

    return _LogoFrame(
      size: size,
      borderRadius: borderRadius,
      backgroundColor: logoBackground,
      borderColor: logoBorder,
      child: Padding(
        padding: EdgeInsets.all(size * 0.08),
        child: content,
      ),
    );
  }
}

class _VibrantShell extends StatelessWidget {
  const _VibrantShell({
    required this.size,
    required this.borderRadius,
    required this.glowColor,
    required this.child,
  });

  final double size;
  final double borderRadius;
  final Color glowColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.38),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _LogoFrame extends StatelessWidget {
  const _LogoFrame({
    required this.size,
    required this.borderRadius,
    required this.backgroundColor,
    required this.borderColor,
    required this.child,
  });

  final double size;
  final double borderRadius;
  final Color backgroundColor;
  final Color borderColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: child,
    );
  }
}

class _TickerFallback extends StatelessWidget {
  const _TickerFallback({
    required this.symbol,
    required this.size,
    required this.borderRadius,
    required this.isFii,
    required this.style,
    this.loading = false,
  });

  final String symbol;
  final double size;
  final double borderRadius;
  final bool isFii;
  final AssetLogoStyle style;
  final bool loading;

  MarketCategory get _category {
    if (isFii) return MarketCategory.fiis;
    if (looksLikeCryptoSymbol(symbol)) return MarketCategory.cripto;
    return MarketCategory.acoesBr;
  }

  String get _label {
    final normalized = symbol.trim().toUpperCase();
    if (isFii) {
      final letters = normalized.replaceAll(RegExp(r'\d'), '');
      if (letters.length >= 4) return letters.substring(0, 4);
      return letters.isEmpty ? normalized : letters;
    }
    return normalized.length > 4 ? normalized.substring(0, 4) : normalized;
  }

  @override
  Widget build(BuildContext context) {
    final theme = _category.theme;
    final vibrant = style == AssetLogoStyle.vibrant;

    if (vibrant) {
      return _VibrantShell(
        size: size,
        borderRadius: borderRadius,
        glowColor: theme.accentColor,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: theme.cardGradient,
            ),
          ),
          child: loading
              ? Center(
                  child: SizedBox(
                    width: size * 0.34,
                    height: size * 0.34,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.iconAccent ?? theme.accentColor,
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    _label,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isFii ? size * 0.24 : size * 0.26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: isFii ? -0.4 : -0.3,
                      color: isFii ? const Color(0xFFFFE8CC) : theme.accentColor,
                      height: 1,
                      shadows: isFii
                          ? const [
                              Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1)),
                            ]
                          : null,
                    ),
                  ),
                ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark
        ? theme.cardGradient.first.withValues(alpha: 0.95)
        : Color.alphaBlend(theme.accentColor.withValues(alpha: 0.14), Colors.white);
    final borderColor = theme.accentColor.withValues(alpha: isDark ? 0.55 : 0.35);
    final textColor = isDark ? theme.iconAccent ?? theme.accentColor : theme.accentColor;

    return _LogoFrame(
      size: size,
      borderRadius: borderRadius,
      backgroundColor: background,
      borderColor: borderColor,
      child: loading
          ? SizedBox(
              width: size * 0.34,
              height: size * 0.34,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: textColor,
              ),
            )
          : Text(
              _label,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                fontSize: isFii ? size * 0.22 : size * 0.24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: textColor,
                height: 1,
              ),
            ),
    );
  }
}
