import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rico_investidor/features/onboarding/premium_intro_screen.dart';

void main() {
  testWidgets('Intro premium exibe a marca', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: PremiumIntroScreen(onFinished: () {}),
      ),
    );
    await tester.pump();

    expect(find.text('INVESTIDOR'), findsOneWidget);
  });
}
