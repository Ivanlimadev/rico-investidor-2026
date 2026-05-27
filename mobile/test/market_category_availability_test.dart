import 'package:flutter_test/flutter_test.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/models/market_category_availability.dart';

void main() {
  test('live categories include B3-backed markets', () {
    expect(MarketCategory.acoesBr.hasLiveData, isTrue);
    expect(MarketCategory.fiis.hasLiveData, isTrue);
    expect(MarketCategory.etfInternacional.hasLiveData, isTrue);
    expect(MarketCategory.moeda.hasLiveData, isTrue);
    expect(MarketCategory.tesouroDireto.hasLiveData, isTrue);
    expect(MarketCategory.indices.hasLiveData, isTrue);
    expect(MarketCategory.cripto.hasLiveData, isTrue);
  });

  test('demo categories are flagged', () {
    expect(MarketCategory.cripto.isDemo, isFalse);
    expect(MarketCategory.stocks.isDemo, isTrue);
    expect(MarketCategory.indices.isDemo, isFalse);
    expect(MarketCategory.tesouroDireto.isDemo, isFalse);
    expect(MarketCategory.acoesBr.isDemo, isFalse);
  });
}
