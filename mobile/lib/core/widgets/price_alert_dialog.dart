import 'package:flutter/material.dart';
import 'package:rico_investidor/core/network/api_exception.dart';
import 'package:rico_investidor/features/alerts/data/alert_repository.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/market_category.dart';

Future<void> showPriceAlertDialog(BuildContext context, {required AssetItem asset}) async {
  await showDialog<void>(
    context: context,
    builder: (context) => _PriceAlertDialogContent(asset: asset),
  );
}

class _PriceAlertDialogContent extends StatefulWidget {
  const _PriceAlertDialogContent({required this.asset});

  final AssetItem asset;

  @override
  State<_PriceAlertDialogContent> createState() => _PriceAlertDialogContentState();
}

class _PriceAlertDialogContentState extends State<_PriceAlertDialogContent> {
  final _aboveController = TextEditingController();
  final _belowController = TextEditingController();

  @override
  void dispose() {
    _aboveController.dispose();
    _belowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Alerta de preço — ${widget.asset.symbol}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Receba um aviso quando o preço cruzar o valor definido. '
              'Não é recomendação de compra ou venda.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _aboveController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Alertar acima de (USD)',
                hintText: 'Ex: 100.00',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _belowController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Alertar abaixo de (USD)',
                hintText: 'Ex: 80.00',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () async {
            final above = double.tryParse(_aboveController.text.replaceAll(',', '.'));
            final below = double.tryParse(_belowController.text.replaceAll(',', '.'));
            if ((above == null || above <= 0) && (below == null || below <= 0)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Informe pelo menos um preço válido.')),
              );
              return;
            }

            try {
              final category = widget.asset.category == MarketCategory.cripto ? 'crypto' : 'stocks';
              if (above != null && above > 0) {
                await alertRepository.createAlert(
                  symbol: widget.asset.symbol,
                  category: category,
                  direction: 'above',
                  targetPrice: above,
                );
              }
              if (below != null && below > 0) {
                await alertRepository.createAlert(
                  symbol: widget.asset.symbol,
                  category: category,
                  direction: 'below',
                  targetPrice: below,
                );
              }
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Alertas salvos para ${widget.asset.symbol}.')),
              );
            } on ApiException catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(e.message)),
              );
            } catch (_) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Não foi possível salvar o alerta.')),
              );
            }
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
