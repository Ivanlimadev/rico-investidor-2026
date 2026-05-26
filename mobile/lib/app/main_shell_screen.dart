import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_bottom_nav_bar.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/app/tab_root_navigator.dart';
import 'package:rico_investidor/features/community/community_tab_screen.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/features/finances/finances_tab_screen.dart';
import 'package:rico_investidor/features/home/home_screen.dart';
import 'package:rico_investidor/features/menu/menu_tab_screen.dart';
import 'package:rico_investidor/features/portfolio/portfolio_tab_screen.dart';
import 'package:rico_investidor/features/search/search_tab_screen.dart';
import 'package:rico_investidor/models/user_profile.dart';
import 'package:rico_investidor/state/portfolio_state.dart';

enum AppTab {
  home,
  portfolio,
  search,
  community,
  finances,
  menu,
}

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({
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

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  AppTab _tab = AppTab.home;

  final _navigatorKeys = List.generate(
    AppTab.values.length,
    (_) => GlobalKey<NavigatorState>(),
  );

  int get _index => _tab.index;

  void _goToHome() {
    if (_tab == AppTab.home) {
      _navigatorKeys[AppTab.home.index].currentState?.popUntil((route) => route.isFirst);
      return;
    }
    setState(() => _tab = AppTab.home);
  }

  void _selectTab(AppTab tab) {
    if (_tab == tab) {
      _navigatorKeys[tab.index].currentState?.popUntil((route) => route.isFirst);
      return;
    }
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    return AppShellScope(
      currentTab: _tab,
      goToHome: _goToHome,
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            TabRootNavigator(
              navigatorKey: _navigatorKeys[AppTab.home.index],
              root: HomeScreen(
                profile: widget.profile,
                onProfileChanged: widget.onProfileChanged,
                portfolio: widget.portfolio,
                onPortfolioChanged: widget.onPortfolioChanged,
                fiiRepository: widget.fiiRepository,
                quoteRepository: widget.quoteRepository,
                isDarkMode: widget.isDarkMode,
                onToggleTheme: widget.onToggleTheme,
              ),
            ),
            TabRootNavigator(
              navigatorKey: _navigatorKeys[AppTab.portfolio.index],
              root: PortfolioTabScreen(
                portfolio: widget.portfolio,
                onPortfolioChanged: widget.onPortfolioChanged,
                fiiRepository: widget.fiiRepository,
                quoteRepository: widget.quoteRepository,
              ),
            ),
            TabRootNavigator(
              navigatorKey: _navigatorKeys[AppTab.search.index],
              root: SearchTabScreen(
                portfolio: widget.portfolio,
                fiiRepository: widget.fiiRepository,
                quoteRepository: widget.quoteRepository,
              ),
            ),
            TabRootNavigator(
              navigatorKey: _navigatorKeys[AppTab.community.index],
              root: const CommunityTabScreen(),
            ),
            TabRootNavigator(
              navigatorKey: _navigatorKeys[AppTab.finances.index],
              root: const FinancesTabScreen(),
            ),
            TabRootNavigator(
              navigatorKey: _navigatorKeys[AppTab.menu.index],
              root: MenuTabScreen(
                profile: widget.profile,
                onProfileChanged: widget.onProfileChanged,
                portfolio: widget.portfolio,
                onPortfolioChanged: widget.onPortfolioChanged,
                fiiRepository: widget.fiiRepository,
                quoteRepository: widget.quoteRepository,
                isDarkMode: widget.isDarkMode,
                onToggleTheme: widget.onToggleTheme,
              ),
            ),
          ],
        ),
        bottomNavigationBar: AppBottomNavBar(
          selectedIndex: _index,
          onDestinationSelected: (index) => _selectTab(AppTab.values[index]),
          destinations: const [
            AppBottomNavItem(
              icon: Icons.home_outlined,
              selectedIcon: Icons.home,
              label: 'Início',
            ),
            AppBottomNavItem(
              icon: Icons.account_balance_wallet_outlined,
              selectedIcon: Icons.account_balance_wallet,
              label: 'Carteira',
            ),
            AppBottomNavItem(
              icon: Icons.search,
              selectedIcon: Icons.search,
              label: 'Buscar',
            ),
            AppBottomNavItem(
              icon: Icons.groups_outlined,
              selectedIcon: Icons.groups,
              label: 'Comunidade',
            ),
            AppBottomNavItem(
              icon: Icons.savings_outlined,
              selectedIcon: Icons.savings,
              label: 'Finanças',
            ),
            AppBottomNavItem(
              icon: Icons.menu,
              selectedIcon: Icons.menu_open,
              label: 'Menu',
            ),
          ],
        ),
      ),
    );
  }
}

/// Espaço extra no rodapé — barra inferior fixa + FAB nas abas com botão flutuante.
const kBottomNavContentPadding = 96.0;

/// Eleva o FAB acima da barra inferior do shell.
const kBottomNavFabPadding = 72.0;
