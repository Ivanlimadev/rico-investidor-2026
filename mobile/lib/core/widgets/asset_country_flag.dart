import 'package:flutter/material.dart';
import 'package:rico_investidor/core/markets/market_visibility.dart';
import 'package:rico_investidor/core/widgets/vector_country_flag.dart';
import 'package:rico_investidor/core/search/asset_search_config.dart';
import 'package:rico_investidor/core/widgets/asset_card_header.dart';
import 'package:rico_investidor/core/widgets/asset_logo.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/market_category.dart';

const _exchangeMicToCountry = {
  'XNAS': 'US',
  'XNYS': 'US',
  'ARCX': 'US',
  'BATS': 'US',
  'XASE': 'US',
  'BVMF': 'BR',
  'BOVESPA': 'BR',
};

const _currencyToCountry = {
  'USD': 'US',
  'EUR': 'EU',
  'GBP': 'GB',
  'JPY': 'JP',
  'CHF': 'CH',
  'CAD': 'CA',
  'AUD': 'AU',
  'CNY': 'CN',
  'CNH': 'CN',
  'ARS': 'AR',
  'MXN': 'MX',
  'NZD': 'NZ',
  'SEK': 'SE',
  'NOK': 'NO',
  'DKK': 'DK',
  'ZAR': 'ZA',
  'TRY': 'TR',
  'RUB': 'RU',
  'HKD': 'HK',
  'SGD': 'SG',
  'KRW': 'KR',
  'INR': 'IN',
};

const _usIndexSymbols = {
  'SPX',
  'GSPC',
  'DJI',
  'IXIC',
  'NDX',
  'RUT',
  'VIX',
  '^GSPC',
  '^DJI',
  '^IXIC',
};

/// País de origem/listagem principal do ativo para exibição na busca.
String? countryCodeForAsset(AssetItem asset) {
  final category = resolveMarketCategory(symbol: asset.symbol, stored: asset.category);

  switch (category) {
    case MarketCategory.stocks:
    case MarketCategory.reits:
      return _countryCodeForExchange(asset.exchangeMic) ?? 'US';
    case MarketCategory.cripto:
      return null;
  }
}

String? _countryCodeForExchange(String? mic) {
  if (mic == null || mic.isEmpty) return null;
  final normalized = mic.toUpperCase();
  return _exchangeMicToCountry[normalized] ?? (normalized == 'US' ? 'US' : null);
}

String _countryCodeForBdr(String symbol) {
  final normalized = symbol.trim().toUpperCase();
  if (normalized.length >= 2) {
    return switch (normalized.substring(normalized.length - 2)) {
      '34' => 'US',
      '35' => 'GB',
      '39' => 'EU',
      _ => 'BR',
    };
  }
  return 'BR';
}

String? _countryCodeForCurrencyPair(String pair) {
  final normalized = pair.trim().toUpperCase().replaceAll('/', '-');
  final parts = normalized.split('-');
  if (parts.isEmpty) return null;

  final foreign = parts.firstWhere((part) => part != 'BRL', orElse: () => parts.first);
  return _currencyToCountry[foreign];
}

String _countryCodeForIndex(String symbol) {
  final normalized = symbol.trim().toUpperCase();
  final withoutCaret = normalized.replaceAll('^', '');
  if (_usIndexSymbols.contains(normalized) || _usIndexSymbols.contains(withoutCaret)) {
    return 'US';
  }
  return 'BR';
}

const _emojiFlags = <String, String>{
  'BR': '🇧🇷',
  'US': '🇺🇸',
  'GB': '🇬🇧',
  'EU': '🇪🇺',
  'JP': '🇯🇵',
  'CH': '🇨🇭',
  'CA': '🇨🇦',
  'AU': '🇦🇺',
  'CN': '🇨🇳',
  'AR': '🇦🇷',
  'MX': '🇲🇽',
  'NZ': '🇳🇿',
  'SE': '🇸🇪',
  'NO': '🇳🇴',
  'DK': '🇩🇰',
  'ZA': '🇿🇦',
  'TR': '🇹🇷',
  'RU': '🇷🇺',
  'HK': '🇭🇰',
  'SG': '🇸🇬',
  'KR': '🇰🇷',
  'IN': '🇮🇳',
};

String? normalizeCountryCode(String? countryCode) {
  final raw = countryCode?.trim().toUpperCase();
  if (raw == null || raw.isEmpty) return null;
  if (raw.length >= 2) return raw.substring(0, 2);
  return null;
}

String? emojiFlagForCountryCode(String? countryCode) {
  final code = normalizeCountryCode(countryCode);
  if (code == null) return null;
  return _emojiFlags[code];
}

String? flagImageUrlForCountryCode(String? countryCode) {
  final code = normalizeCountryCode(countryCode)?.toLowerCase();
  if (code == null) return null;
  return 'https://flagcdn.com/w40/$code.png';
}

class _EmojiFlag extends StatelessWidget {
  const _EmojiFlag({
    required this.emoji,
    required this.size,
    required this.borderRadius,
  });

  final String emoji;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final width = size * 1.45;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: size,
        child: Center(
          child: Text(
            emoji,
            style: TextStyle(fontSize: size * 0.92, height: 1),
          ),
        ),
      ),
    );
  }
}

/// Bandeira PNG por código ISO-3166 alpha-2 (ex.: BR, US).
class CountryFlagImage extends StatelessWidget {
  const CountryFlagImage({
    super.key,
    required this.countryCode,
    this.size = 28,
    this.borderRadius = 4,
  });

  final String countryCode;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final normalized = normalizeCountryCode(countryCode);
    if (hasVectorCountryFlag(normalized)) {
      return vectorCountryFlagForCode(
        normalized,
        height: size,
        borderRadius: borderRadius,
      );
    }

    final emoji = emojiFlagForCountryCode(normalized);
    if (emoji != null) {
      return _EmojiFlag(emoji: emoji, size: size, borderRadius: borderRadius);
    }

    return CountryCodeBadge(
      code: normalized ?? countryCode,
      height: size,
      borderRadius: borderRadius,
    );
  }
}

/// Bandeira pequena (PNG) para resultados de busca e listas.
class AssetCountryFlag extends StatelessWidget {
  const AssetCountryFlag({
    super.key,
    required this.asset,
    this.size = 14,
  });

  final AssetItem asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    final countryCode = countryCodeForAsset(asset);
    if (hasVectorCountryFlag(countryCode)) {
      return vectorCountryFlagForCode(
        countryCode,
        height: size,
        borderRadius: 2,
      );
    }

    final emoji = emojiFlagForCountryCode(countryCode);
    if (emoji != null) {
      return _EmojiFlag(emoji: emoji, size: size, borderRadius: 2);
    }

    if (countryCode == null) {
      return Icon(
        Icons.public,
        size: size,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
      );
    }

    return CountryCodeBadge(code: countryCode, height: size, borderRadius: 2);
  }
}

class CountryCodeBadge extends StatelessWidget {
  const CountryCodeBadge({
    super.key,
    required this.code,
    required this.height,
    this.borderRadius = 2,
  });

  final String code;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: height * 1.45,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        code.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: height * 0.42,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
      ),
    );
  }
}

/// Logo do ativo com bandeira do país no canto inferior direito.
class AssetSearchLeading extends StatelessWidget {
  const AssetSearchLeading({
    super.key,
    required this.asset,
    this.logoSize = kAssetLogoSizeList,
  });

  final AssetItem asset;
  final double logoSize;

  @override
  Widget build(BuildContext context) {
    final flagSize = searchGridFlagSizeForLogo(logoSize);
    final stackSize = logoSize + flagSize * 0.35;

    return SizedBox(
      width: stackSize,
      height: stackSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AssetLogo(
            symbol: asset.symbol,
            logoUrl: asset.logoUrl,
            size: logoSize,
            borderRadius: kAssetLogoBorderRadius,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 2,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(1.5),
                child: AssetCountryFlag(asset: asset, size: flagSize),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
