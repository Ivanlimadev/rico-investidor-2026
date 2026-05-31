import 'package:flutter_test/flutter_test.dart';
import 'package:rico_investidor/core/utils/asset_logo_url.dart';

void main() {
  test('resolveAssetLogoUrl uses crypto API proxy', () {
    final url = resolveAssetLogoUrl(
      'BTC',
      'https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/svg/color/btc.svg',
      isFii: false,
    );

    expect(url, contains('/v1/crypto/BTC/logo.png'));
  });

  test('resolveAssetLogoUrl builds crypto API when logoUrl is missing', () {
    final url = resolveAssetLogoUrl('ETH', null, isFii: false);

    expect(url, contains('/v1/crypto/ETH/logo.png'));
  });

  test('resolveAssetLogoUrl uses quotes API proxy for b3 stocks', () {
    final url = resolveAssetLogoUrl('PETR4', null, isFii: false);

    expect(url, contains('/v1/quotes/PETR4/logo.png'));
  });

  test('resolveAssetLogoUrl uses fiis API proxy for fiis', () {
    final url = resolveAssetLogoUrl('HGLG11', null, isFii: false);

    expect(url, contains('/v1/fiis/HGLG11/logo.png'));
  });

  test('logoDownloadCandidates tries proxy then direct b3', () {
    final urls = logoDownloadCandidates(
      symbol: 'PETR4',
      isFii: false,
      resolvedUrl: resolveAssetLogoUrl('PETR4', null, isFii: false),
    );

    expect(urls.first, contains('/v1/quotes/PETR4/logo.png'));
    expect(urls.any((u) => u.contains('icones-b3')), isTrue);
  });

  test('looksLikeCryptoSymbol rejects fiis and b3 tickers', () {
    expect(looksLikeCryptoSymbol('BTC'), isTrue);
    expect(looksLikeCryptoSymbol('HGLG11'), isFalse);
    expect(looksLikeCryptoSymbol('PETR4'), isFalse);
  });
}
