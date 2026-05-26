import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/app/main_shell_screen.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/home/widgets/market_category_icon.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/features/market/market_list_screen.dart';
import 'package:rico_investidor/features/menu/widgets/profile_header.dart';
import 'package:rico_investidor/features/settings/settings_screen.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/models/market_category_theme.dart';
import 'package:rico_investidor/models/user_profile.dart';
import 'package:rico_investidor/state/portfolio_state.dart';

class MenuTabScreen extends StatelessWidget {
  const MenuTabScreen({
    super.key,
    required this.profile,
    required this.onProfileChanged,
    required this.portfolio,
    required this.onPortfolioChanged,
    required this.fiiRepository,
    required this.quoteRepository,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  final UserProfile profile;
  final void Function(UserProfile profile) onProfileChanged;
  final PortfolioState portfolio;
  final VoidCallback onPortfolioChanged;
  final FiiRepository fiiRepository;
  final QuoteRepository quoteRepository;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  void _openCategory(BuildContext context, MarketCategory category) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MarketListScreen(
          category: category,
          fiiRepository: fiiRepository,
          quoteRepository: quoteRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu'),
        actions: const [ShellHomeButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: kBottomNavContentPadding),
        children: [
          ProfileHeader(profile: profile),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text('Mercados', style: Theme.of(context).textTheme.titleSmall),
          ),
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
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openCategory(context, category),
            ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            title: Text(isDarkMode ? 'Tema claro' : 'Tema escuro'),
            onTap: onToggleTheme,
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Configurações'),
            subtitle: const Text('Conta, plano e preferências'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SettingsScreen(
                  profile: profile,
                  onProfileChanged: onProfileChanged,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
