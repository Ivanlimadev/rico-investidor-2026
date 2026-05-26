import 'package:flutter/material.dart';
import 'package:rico_investidor/features/menu/account_menu_items.dart';
import 'package:rico_investidor/features/settings/settings_screen.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/features/home/widgets/market_category_icon.dart';
import 'package:rico_investidor/models/market_category_theme.dart';
import 'package:rico_investidor/models/user_profile.dart';

class MainMenuDrawer extends StatelessWidget {
  const MainMenuDrawer({
    super.key,
    required this.profile,
    required this.onProfileChanged,
    required this.onSelectCategory,
  });

  final UserProfile profile;
  final ProfileChanged onProfileChanged;
  final void Function(MarketCategory category) onSelectCategory;

  void _openSettings(BuildContext context) {
    Navigator.of(context).pop();
    openSettingsScreen(
      context,
      profile: profile,
      onProfileChanged: onProfileChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rico Investidor',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Explore os mercados',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final category in MarketCategory.values)
                    ListTile(
                      leading: SizedBox(
                        width: 40,
                        height: 40,
                        child: MarketCategoryIcon(
                          kind: category.theme.iconKind,
                          size: 36,
                          iconColor: category.theme.iconAccent,
                          accentColor: category.theme.accentColor,
                        ),
                      ),
                      title: Text(category.title),
                      onTap: () => onSelectCategory(category),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Configurações'),
              subtitle: const Text('Conta, plano e preferências'),
              onTap: () => _openSettings(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
