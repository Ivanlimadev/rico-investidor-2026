import 'package:flutter/material.dart';
import 'package:rico_investidor/core/utils/asset_magic_number.dart';
import 'package:rico_investidor/core/widgets/asset_magic_number_card.dart';
import 'package:rico_investidor/features/fii/utils/fii_magic_number.dart';
import 'package:rico_investidor/models/fii_models.dart';
import 'package:rico_investidor/models/holding_currency.dart';

class FiiMagicNumberCard extends StatelessWidget {
  const FiiMagicNumberCard({
    super.key,
    required this.detail,
    this.distributions,
    this.history = const [],
  });

  final FiiDetail detail;
  final FiiDistributions? distributions;
  final List<FiiHistoryPoint> history;

  @override
  Widget build(BuildContext context) {
    final result = computeMagicNumber(
      detail: detail,
      distributions: distributions,
      history: history,
    );

    if (result == null) return const SizedBox.shrink();

    return AssetMagicNumberCard(
      result: result,
      unitLabel: 'cota',
      unitPlural: 'cotas',
      currency: HoldingCurrency.brl,
      priceLabel: 'Cotação atual',
    );
  }
}
