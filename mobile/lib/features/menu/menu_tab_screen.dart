import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/app/main_shell_screen.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/features/menu/account_menu_items.dart';
import 'package:rico_investidor/features/menu/widgets/profile_header.dart';
import 'package:rico_investidor/features/dividends/screens/dividend_agenda_screen.dart';
import 'package:rico_investidor/features/global_markets/data/global_market_repository.dart';
import 'package:rico_investidor/features/settings/settings_screen.dart';
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
    this.globalMarketRepository,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.onLogin,
    required this.onRegister,
    required this.onLogout,
  });

  final UserProfile profile;
  final void Function(UserProfile profile) onProfileChanged;
  final PortfolioState portfolio;
  final VoidCallback onPortfolioChanged;
  final FiiRepository fiiRepository;
  final QuoteRepository quoteRepository;
  final GlobalMarketRepository? globalMarketRepository;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final VoidCallback onLogin;
  final VoidCallback onRegister;
  final LogoutCallback onLogout;

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
          ListTile(
            leading: Icon(isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            title: Text(isDarkMode ? 'Tema claro' : 'Tema escuro'),
            onTap: onToggleTheme,
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: const Text('Agenda de dividendos'),
            subtitle: const Text('Ações BR (B3) e EUA — data com, pagamento e valor'),
            onTap: () => openDividendAgendaScreen(
              context,
              fiiRepository: fiiRepository,
              quoteRepository: quoteRepository,
              globalMarketRepository: globalMarketRepository,
            ),
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
                  onLogin: onLogin,
                  onRegister: onRegister,
                  onLogout: onLogout,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
