import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rico_investidor/features/auth/screens/login_screen.dart';

void main() {
  testWidgets('LoginScreen shows session expired banner', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          sessionExpired: true,
          onSuccess: () {},
        ),
      ),
    );

    expect(find.textContaining('Sua sessão expirou'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets('LoginScreen hides banner by default', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(onSuccess: () {}),
      ),
    );

    expect(find.textContaining('Sua sessão expirou'), findsNothing);
  });
}
