import 'package:flutter/material.dart';
import 'package:rico_investidor/models/market_category.dart';

class PortfolioAllocationSlice {
  const PortfolioAllocationSlice({
    required this.category,
    required this.label,
    required this.value,
    required this.percent,
    required this.color,
  });

  final MarketCategory? category;
  final String label;
  final double value;
  final double percent;
  final Color color;
}
