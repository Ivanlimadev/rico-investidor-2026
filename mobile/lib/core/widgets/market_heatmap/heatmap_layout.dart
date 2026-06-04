import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Item genérico para tiles do mapa de calor.
class HeatmapTileItem {
  const HeatmapTileItem({
    required this.symbol,
    required this.changePercent,
    this.volume,
  });

  final String symbol;
  final double changePercent;
  final double? volume;
}

/// Partições estilo Binance: blocos maiores no topo (maior volume).
const heatmapRowSizes = [2, 4, 6, 6];

/// Altura relativa de cada faixa do mapa de calor.
const heatmapRowHeightWeights = [0.34, 0.26, 0.22, 0.18];

List<List<HeatmapTileItem>> partitionHeatmapRows(List<HeatmapTileItem> items) {
  if (items.isEmpty) return [];

  final rows = <List<HeatmapTileItem>>[];
  var index = 0;
  for (final size in heatmapRowSizes) {
    if (index >= items.length) break;
    final end = math.min(index + size, items.length);
    rows.add(items.sublist(index, end));
    index = end;
  }
  return rows;
}

double heatmapTileVolume(HeatmapTileItem item) {
  final volume = item.volume;
  if (volume == null || volume <= 0) return 1;
  return volume;
}

Color heatmapChangeColor(double changePercent, {required bool isDark}) {
  if (changePercent.abs() < 0.05) {
    return isDark ? const Color(0xFF2B3139) : const Color(0xFFE8EAED);
  }

  final intensity = (changePercent.abs() / 8).clamp(0.25, 1.0);

  if (changePercent > 0) {
    return Color.lerp(
      isDark ? const Color(0xFF14352A) : const Color(0xFFD7F5E8),
      isDark ? const Color(0xFF0ECB81) : const Color(0xFF0ABF7A),
      intensity,
    )!;
  }

  return Color.lerp(
    isDark ? const Color(0xFF3A1F24) : const Color(0xFFFCE4E4),
    isDark ? const Color(0xFFF6465D) : const Color(0xFFE5484D),
    intensity,
  )!;
}

Color heatmapLabelColor(double changePercent, {required bool isDark}) {
  if (changePercent.abs() >= 1.5) {
    return isDark ? Colors.white : const Color(0xFF101828);
  }
  return isDark ? Colors.white.withValues(alpha: 0.92) : const Color(0xFF344054);
}
