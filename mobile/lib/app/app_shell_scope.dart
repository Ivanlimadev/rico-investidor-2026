import 'package:flutter/material.dart';
import 'package:rico_investidor/app/main_shell_screen.dart';

class AppShellScope extends InheritedWidget {
  const AppShellScope({
    super.key,
    required this.currentTab,
    required this.goToHome,
    required super.child,
  });

  final AppTab currentTab;
  final VoidCallback goToHome;

  static AppShellScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppShellScope>();
    assert(scope != null, 'AppShellScope not found');
    return scope!;
  }

  static AppShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppShellScope>();
  }

  @override
  bool updateShouldNotify(AppShellScope oldWidget) {
    return currentTab != oldWidget.currentTab;
  }
}

/// Botão de início no topo — visível fora da aba Início ou em telas empilhadas.
class ShellHomeButton extends StatelessWidget {
  const ShellHomeButton({super.key});

  @override
  Widget build(BuildContext context) {
    final shell = AppShellScope.maybeOf(context);
    if (shell == null) return const SizedBox.shrink();

    final onHomeTab = shell.currentTab == AppTab.home;
    final canPop = Navigator.of(context).canPop();
    if (onHomeTab && !canPop) return const SizedBox.shrink();

    return IconButton(
      tooltip: 'Início',
      onPressed: shell.goToHome,
      icon: Icon(canPop ? Icons.home_outlined : Icons.home),
    );
  }
}
