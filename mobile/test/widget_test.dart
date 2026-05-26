import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rico_investidor/app/rico_investidor_app.dart';

void main() {
  testWidgets('App abre na aba Início com navegação inferior', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const RicoInvestidorApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Rico Investidor'), findsOneWidget);
    expect(find.text('Olá, Investidor'), findsOneWidget);
    expect(find.text('Saldo da carteira'), findsOneWidget);
    expect(find.text('Distribuição da carteira'), findsOneWidget);
    expect(find.text('FIIs em destaque'), findsOneWidget);
    expect(find.text('Mercados'), findsOneWidget);
    expect(find.text('Início'), findsOneWidget);
    expect(find.text('Carteira'), findsOneWidget);
    expect(find.text('Comunidade'), findsOneWidget);
    expect(find.text('Finanças'), findsOneWidget);
  });
}
