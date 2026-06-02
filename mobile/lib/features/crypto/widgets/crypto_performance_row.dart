import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/features/crypto/models/crypto_models.dart';

class CryptoPerformanceRow extends StatelessWidget {
  const CryptoPerformanceRow({super.key, required this.performance});

  final CryptoPerformanceStatsDto performance;

  @override
  Widget build(BuildContext context) {
    final items = <_PerfItem>[
      _PerfItem(label: '24h', value: performance.change24h),
      _PerfItem(label: '7D', value: performance.change7d),
      _PerfItem(label: '30D', value: performance.change30d),
      _PerfItem(label: '1A', value: performance.change1y),
    ];

    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _PerformanceChip(item: items[i])),
        ],
      ],
    );
  }
}

class _PerfItem {
  const _PerfItem({required this.label, required this.value});

  final String label;
  final double? value;
}

class _PerformanceChip extends StatelessWidget {
  const _PerformanceChip({required this.item});

  final _PerfItem item;

  @override
  Widget build(BuildContext context) {
    final value = item.value;
    final isPositive = value != null && value >= 0;
    final color = value == null
        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45)
        : isPositive
            ? AppColors.positive
            : AppColors.negative;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value == null ? '—' : '${isPositive ? '+' : ''}${value.toStringAsFixed(2)}%',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
