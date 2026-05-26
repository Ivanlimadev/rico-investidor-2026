import 'package:flutter/material.dart';

/// Navigator interno de cada aba — mantém a barra inferior visível ao abrir telas.
class TabRootNavigator extends StatelessWidget {
  const TabRootNavigator({
    super.key,
    required this.navigatorKey,
    required this.root,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget root;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (settings) {
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => root,
        );
      },
    );
  }
}
