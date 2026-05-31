import 'package:flutter_test/flutter_test.dart';
import 'package:rico_investidor/core/search/asset_search_config.dart';

void main() {
  group('search grid sizing', () {
    test('cell width accounts for spacing', () {
      expect(
        searchGridCellWidth(gridWidth: 320, columns: 3),
        closeTo(101.33, 0.01),
      );
    });

    test('logo scales with cell width', () {
      expect(searchGridLogoSizeForCellWidth(100), 52);
      expect(searchGridLogoSizeForCellWidth(80), kSearchGridMinLogoSize);
      expect(searchGridLogoSizeForCellWidth(120), kSearchGridMaxLogoSize);
    });

    test('typography scales with logo', () {
      expect(searchGridLabelFontSize(52), closeTo(12.48, 0.01));
      expect(searchGridPriceFontSize(52), closeTo(10.92, 0.01));
    });
  });
}
