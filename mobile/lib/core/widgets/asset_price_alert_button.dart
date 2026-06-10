import 'package:flutter/material.dart';
import 'package:rico_investidor/core/widgets/price_alert_dialog.dart';
import 'package:rico_investidor/models/asset_item.dart';

/// Sino de alerta de preço — substitui o botão Início nas telas de detalhe do ativo.
class AssetPriceAlertButton extends StatelessWidget {
  const AssetPriceAlertButton({super.key, required this.asset});

  final AssetItem asset;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Alerta de preço',
      onPressed: () => showPriceAlertDialog(context, asset: asset),
      icon: const Icon(Icons.notifications_outlined),
    );
  }
}
