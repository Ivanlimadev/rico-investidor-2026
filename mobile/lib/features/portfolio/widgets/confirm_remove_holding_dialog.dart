import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/models/portfolio_holding.dart';

Future<bool> confirmRemovePortfolioHolding(
  BuildContext context,
  PortfolioHolding holding,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Remover ativo'),
      content: Text(
        'Tem certeza que deseja remover ${holding.symbol} da sua carteira?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Não'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.negative),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Sim'),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}
