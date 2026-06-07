import 'package:flutter/material.dart';
import 'package:rico_investidor/features/global_markets/models/global_market_models.dart';

class UsMarketSessionChip extends StatelessWidget {
  const UsMarketSessionChip({
    super.key,
    required this.capabilities,
    this.compact = true,
  });

  final GlobalMarketCapabilitiesDto capabilities;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final open = capabilities.usMarketOpen;
    final holiday = capabilities.usMarketHoliday;
    final label = capabilities.usMarketLabel;
    final color = open
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);

    return Chip(
      avatar: Icon(
        open
            ? Icons.circle
            : (holiday ? Icons.event_busy_outlined : Icons.schedule_outlined),
        size: compact ? 14 : 16,
        color: open ? Colors.green : color,
      ),
      label: Text(label),
      visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      side: BorderSide(color: color.withValues(alpha: 0.25)),
    );
  }
}
