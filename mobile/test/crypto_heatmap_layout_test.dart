import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rico_investidor/features/crypto/models/crypto_models.dart';
import 'package:rico_investidor/features/crypto/utils/crypto_heatmap_layout.dart';

void main() {
  test('partitionHeatmapRows follows Binance-like tiers', () {
    final items = List.generate(
      10,
      (index) => CryptoQuoteDto(
        symbol: 'C$index',
        name: 'Coin $index',
        price: 1,
        changePercent: index.toDouble(),
        volume: (10 - index).toDouble(),
      ),
    );

    final rows = partitionCryptoHeatmapRows(items);

    expect(rows.length, 3);
    expect(rows[0].length, 2);
    expect(rows[1].length, 4);
    expect(rows[2].length, 4);
  });

  test('heatmapChangeColor uses green and red tones', () {
    expect(heatmapChangeColor(4, isDark: true), isNot(heatmapChangeColor(-4, isDark: true)));
    expect(heatmapChangeColor(0, isDark: true), const Color(0xFF2B3139));
  });
}
