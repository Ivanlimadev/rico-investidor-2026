import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/features/portfolio/add_asset_screen.dart';
import 'package:rico_investidor/models/asset_item.dart';

/// Abre a aba Buscar com o ticker/símbolo pré-preenchido.
void openAssetSearch(BuildContext context, AssetItem asset) {
  final shell = AppShellScope.maybeOf(context);
  if (shell != null) {
    shell.goToSearch(query: asset.symbol);
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Buscar: ${asset.symbol}')),
  );
}

/// Abre o formulário de adicionar à carteira com o ativo pré-selecionado.
Future<bool?> openAddAssetToPortfolio(BuildContext context, AssetItem asset) {
  final shell = AppShellScope.maybeOf(context);
  if (shell == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Carteira indisponível nesta tela')),
    );
    return Future.value(null);
  }

  return Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => AddAssetScreen(
        portfolio: shell.portfolio,
        initialAsset: asset,
      ),
    ),
  ).then((saved) {
    if (saved == true) shell.onPortfolioChanged();
    return saved;
  });
}
