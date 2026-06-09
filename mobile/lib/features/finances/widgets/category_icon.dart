import 'package:flutter/material.dart';
import 'package:rico_investidor/features/finances/utils/finance_category_mapper.dart';

class FinanceCategoryIcon extends StatelessWidget {
  const FinanceCategoryIcon({
    super.key,
    required this.category,
    this.size = 20,
  });

  final String category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final info = financeCategoryInfo(category);
    return Text(info.emoji, style: TextStyle(fontSize: size));
  }
}
