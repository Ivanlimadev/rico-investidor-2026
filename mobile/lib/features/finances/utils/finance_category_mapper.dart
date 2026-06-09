import 'package:flutter/material.dart';
import 'package:rico_investidor/l10n/app_strings.dart';

class FinanceCategoryInfo {
  const FinanceCategoryInfo({
    required this.key,
    required this.label,
    required this.icon,
    required this.emoji,
  });

  final String key;
  final String label;
  final IconData icon;
  final String emoji;
}

const _categories = <FinanceCategoryInfo>[
  FinanceCategoryInfo(key: 'food_drink', label: AppStrings.categoryFoodDrink, icon: Icons.restaurant_outlined, emoji: '🍔'),
  FinanceCategoryInfo(key: 'shopping', label: AppStrings.categoryShopping, icon: Icons.shopping_bag_outlined, emoji: '🛒'),
  FinanceCategoryInfo(key: 'transportation', label: AppStrings.categoryTransportation, icon: Icons.directions_car_outlined, emoji: '⛽'),
  FinanceCategoryInfo(key: 'housing', label: AppStrings.categoryHousing, icon: Icons.home_outlined, emoji: '🏠'),
  FinanceCategoryInfo(key: 'health', label: AppStrings.categoryHealth, icon: Icons.medical_services_outlined, emoji: '💊'),
  FinanceCategoryInfo(key: 'entertainment', label: AppStrings.categoryEntertainment, icon: Icons.movie_outlined, emoji: '🎬'),
  FinanceCategoryInfo(key: 'travel', label: AppStrings.categoryTravel, icon: Icons.flight_outlined, emoji: '✈️'),
  FinanceCategoryInfo(key: 'education', label: AppStrings.categoryEducation, icon: Icons.school_outlined, emoji: '📚'),
  FinanceCategoryInfo(key: 'income', label: AppStrings.categoryIncome, icon: Icons.payments_outlined, emoji: '💰'),
  FinanceCategoryInfo(key: 'transfers', label: AppStrings.categoryTransfers, icon: Icons.swap_horiz, emoji: '🔄'),
  FinanceCategoryInfo(key: 'fees', label: AppStrings.categoryFees, icon: Icons.receipt_long_outlined, emoji: '💳'),
  FinanceCategoryInfo(key: 'other', label: AppStrings.categoryOther, icon: Icons.category_outlined, emoji: '📦'),
];

FinanceCategoryInfo financeCategoryInfo(String key) {
  final normalized = key.trim().toLowerCase();
  return _categories.firstWhere(
    (item) => item.key == normalized,
    orElse: () => const FinanceCategoryInfo(
      key: 'other',
      label: AppStrings.categoryOther,
      icon: Icons.category_outlined,
      emoji: '📦',
    ),
  );
}

List<FinanceCategoryInfo> get selectableFinanceCategories =>
    _categories.where((item) => item.key != 'transfers').toList();
