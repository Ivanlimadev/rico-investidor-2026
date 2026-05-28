import 'package:flutter_test/flutter_test.dart';
import 'package:rico_investidor/core/utils/asset_logo_url.dart';

void main() {
  test('resolveAssetLogoUrl uses crypto png from backend url', () {
    final url = resolveAssetLogoUrl(
      'BTC',
      'https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/svg/color/btc.svg',
      isFii: false,
    );

    expect(url, contains('cryptocurrency-icons'));
    expect(url, endsWith('/btc.png'));
  });

  test('resolveAssetLogoUrl builds crypto png when logoUrl is missing', () {
    final url = resolveAssetLogoUrl('ETH', null, isFii: false);

    expect(url, contains('/eth.png'));
  });

  test('resolveAssetLogoUrl keeps api logo for b3 stocks', () {
    final url = resolveAssetLogoUrl('PETR4', null, isFii: false);

    expect(url, contains('/v1/quotes/PETR4/logo.png'));
  });

  test('looksLikeCryptoSymbol rejects fiis and b3 tickers', () {
    expect(looksLikeCryptoSymbol('BTC'), isTrue);
    expect(looksLikeCryptoSymbol('HGLG11'), isFalse);
    expect(looksLikeCryptoSymbol('PETR4'), isFalse);
  });
}
