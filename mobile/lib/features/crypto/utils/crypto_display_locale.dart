import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';

/// Cripto em USD para mercado preferido EUA/global; BRL só quando preferência é Brasil.
bool cryptoShowsBrazilianQuotes(BuildContext context) {
  final scope = context.dependOnInheritedWidgetOfExactType<AppShellScope>();
  return scope?.preferredMarket.isBrazil ?? false;
}
