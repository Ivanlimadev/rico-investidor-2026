import 'package:flutter_test/flutter_test.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/models/market_category_availability.dart';

void main() {
  test('live categories include supported markets', () {
    expect(MarketCategory.acoesBr.hasLiveData, isTrue);
    expect(MarketCategory.fiis.hasLiveData, isTrue);
    expect(MarketCategory.etfInternacional.hasLiveData, isTrue);
    expect(MarketCategory.moeda.hasLiveData, isTrue);
    expect(MarketCategory.tesouroDireto.hasLiveData, isTrue);
    expect(MarketCategory.indices.hasLiveData, isTrue);
    expect(MarketCategory.cripto.hasLiveData, isTrue);
    expect(MarketCategory.stocks.hasLiveData, isTrue);
    expect(MarketCategory.reits.hasLiveData, isTrue);
  });
}
