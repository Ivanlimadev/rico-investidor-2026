import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rico_investidor/core/widgets/asset_logo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AssetLogo renders ticker fallback for US stock', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AssetLogo(
            symbol: 'AAPL',
            size: 48,
            style: AssetLogoStyle.vibrant,
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('AAPL'), findsOneWidget);
  });
}
