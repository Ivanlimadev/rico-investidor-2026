import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rico_investidor/core/widgets/asset_logo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final symbol in ['PETR4', 'VALE3', 'ITUB4']) {
    testWidgets('AssetLogo renders $symbol from bundled asset', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AssetLogo(
              symbol: symbol,
              size: 48,
              style: AssetLogoStyle.vibrant,
            ),
          ),
        ),
      );

      await tester.pump();

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<AssetImage>());
      expect((image.image as AssetImage).assetName, 'assets/logos/$symbol.png');
    });
  }
}
