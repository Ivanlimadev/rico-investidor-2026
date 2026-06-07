import 'package:flutter/material.dart';
import 'package:rico_investidor/core/utils/us_market_capabilities_labels.dart';
import 'package:rico_investidor/features/global_markets/models/global_market_models.dart';

class UsIntradayDelayChip extends StatelessWidget {
  const UsIntradayDelayChip({
    super.key,
    required this.capabilities,
    this.compact = true,
  });

  final GlobalMarketCapabilitiesDto capabilities;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!shouldShowUsIntradayDelayNotice(capabilities)) {
      return const SizedBox.shrink();
    }

    final color = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);

    return Chip(
      avatar: Icon(Icons.info_outline, size: compact ? 14 : 16, color: color),
      label: Text(usIntradayDelayChipLabel(capabilities)),
      visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      side: BorderSide(color: color.withValues(alpha: 0.25)),
    );
  }
}
