import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/features/dividends/widgets/portfolio_dividends_section.dart';
import 'package:rico_investidor/state/portfolio_state.dart';

void openDividendsScreen(
  BuildContext context, {
  required PortfolioState portfolio,
  VoidCallback? onPortfolioChanged,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => DividendsScreen(
        portfolio: portfolio,
        onPortfolioChanged: onPortfolioChanged,
      ),
    ),
  );
}

class DividendsScreen extends StatelessWidget {
  const DividendsScreen({
    super.key,
    required this.portfolio,
    this.onPortfolioChanged,
  });

  final PortfolioState portfolio;
  final VoidCallback? onPortfolioChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dividendos'),
        actions: const [ShellHomeButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          PortfolioDividendsSection(
            portfolio: portfolio,
            onPortfolioChanged: onPortfolioChanged,
          ),
        ],
      ),
    );
  }
}
