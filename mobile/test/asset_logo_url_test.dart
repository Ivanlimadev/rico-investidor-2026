import 'package:flutter_test/flutter_test.dart';
import 'package:rico_investidor/core/utils/asset_logo_url.dart';

void main() {
  test('resolveAssetLogoUrl uses crypto API proxy', () {
    final url = resolveAssetLogoUrl(
      'BTC',
      'https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/svg/color/btc.svg',
    );

    expect(url, contains('/v1/crypto/BTC/logo.png'));
  });

  test('resolveAssetLogoUrl builds crypto API when logoUrl is missing', () {
    final url = resolveAssetLogoUrl('ETH', null);

    expect(url, contains('/v1/crypto/ETH/logo.png'));
  });

  test('resolveAssetLogoUrl builds US market API for AAPL', () {
    final url = resolveAssetLogoUrl('AAPL', null);

    expect(url, contains('/v1/global-markets/AAPL/logo.png'));
  });

  test('resolveAssetLogoUrl returns null for bundled offline ticker', () {
    expect(resolveAssetLogoUrl('PETR4', null), isNull);
    expect(hasBundledLogo('PETR4'), isTrue);
  });

  test('logoDownloadCandidates includes proxy and FMP fallback', () {
    final urls = logoDownloadCandidates(
      symbol: 'AAPL',
      resolvedUrl: resolveAssetLogoUrl('AAPL', null),
      originalLogoUrl: 'https://financialmodelingprep.com/image-stock/AAPL.png',
    );

    expect(urls.length, greaterThanOrEqualTo(2));
    expect(urls.any((url) => url.contains('/v1/global-markets/AAPL/logo.png')), isTrue);
    expect(urls.any((url) => url.contains('financialmodelingprep.com/image-stock/AAPL.png')), isTrue);
  });

  test('resolveAssetLogoUrl maps FMP url to local proxy', () {
    final url = resolveAssetLogoUrl(
      'MSFT',
      'https://financialmodelingprep.com/image-stock/MSFT.png',
    );

    expect(url, contains('/v1/global-markets/MSFT/logo.png'));
  });

  test('looksLikeCryptoSymbol rejects stock tickers', () {
    expect(looksLikeCryptoSymbol('BTC'), isTrue);
    expect(looksLikeCryptoSymbol('AAPL'), isFalse);
    expect(looksLikeCryptoSymbol('MSFT'), isFalse);
  });
}
