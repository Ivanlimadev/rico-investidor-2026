import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_bottom_nav_bar.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/app/tab_root_navigator.dart';
import 'package:rico_investidor/features/community/community_tab_screen.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/home/data/home_repository.dart';
import 'package:rico_investidor/features/global_markets/data/global_market_repository.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/features/finances/finances_tab_screen.dart';
import 'package:rico_investidor/features/home/home_screen.dart';
import 'package:rico_investidor/features/menu/account_menu_items.dart';
import 'package:rico_investidor/features/menu/menu_tab_screen.dart';
import 'package:rico_investidor/features/portfolio/portfolio_tab_screen.dart';
import 'package:rico_investidor/features/search/search_tab_screen.dart';
import 'package:rico_investidor/models/user_profile.dart';
import 'package:rico_investidor/services/market_preference_storage.dart';
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
    required this.homeRepository,
    required this.fiiRepository,
    required this.quoteRepository,
    required this.globalMarketRepository,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.preferredMarket,
    required this.onChangePreferredMarket,
    required this.onLogin,
    required this.onRegister,
    required this.onLogout,
  });

  final UserProfile profile;
  final void Function(UserProfile profile) onProfileChanged;
  final PortfolioState portfolio;
  final VoidCallback onPortfolioChanged;
  final HomeRepository homeRepository;
  final FiiRepository fiiRepository;
  final QuoteRepository quoteRepository;
  final GlobalMarketRepository globalMarketRepository;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final MarketPreference preferredMarket;
  final VoidCallback onChangePreferredMarket;
  final VoidCallback onLogin;
  final VoidCallback onRegister;
  final LogoutCallback onLogout;

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  AppTab _tab = AppTab.home;
  final Set<AppTab> _loadedTabs = {AppTab.home};
  String? _pendingSearchQuery;

  // Abas exibidas na barra inferior. Comunidade e Finanças ficam ocultas
  // (código preservado) para acelerar o lançamento; basta reincluí-las aqui.
  static const List<AppTab> _visibleTabs = [
    AppTab.home,
    AppTab.portfolio,
    AppTab.search,
    AppTab.menu,
  ];

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
    setState(() {
      _loadedTabs.add(AppTab.home);
      _tab = AppTab.home;
    });
  }

  void _selectTab(AppTab tab) {
    if (_tab == tab) {
      _navigatorKeys[tab.index].currentState?.popUntil((route) => route.isFirst);
      return;
    }
    setState(() {
      _loadedTabs.add(tab);
      _tab = tab;
    });
  }

  void _goToSearch({String? query}) {
    if (query != null && query.trim().isNotEmpty) {
      _pendingSearchQuery = query.trim();
    }
    if (_tab == AppTab.search) {
      _navigatorKeys[AppTab.search.index].currentState?.popUntil((route) => route.isFirst);
    }
    _selectTab(AppTab.search);
  }

  void _consumePendingSearchQuery() {
    _pendingSearchQuery = null;
  }

  Widget _tabRoot(AppTab tab, Widget root) {
    if (!_loadedTabs.contains(tab)) return const SizedBox.shrink();
    return TabRootNavigator(
      navigatorKey: _navigatorKeys[tab.index],
      root: root,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShellScope(
      currentTab: _tab,
      goToHome: _goToHome,
      goToSearch: _goToSearch,
      portfolio: widget.portfolio,
      onPortfolioChanged: widget.onPortfolioChanged,
      preferredMarket: widget.preferredMarket,
      onChangePreferredMarket: widget.onChangePreferredMarket,
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            _tabRoot(
              AppTab.home,
              HomeScreen(
                profile: widget.profile,
                onProfileChanged: widget.onProfileChanged,
                portfolio: widget.portfolio,
                onPortfolioChanged: widget.onPortfolioChanged,
                homeRepository: widget.homeRepository,
                fiiRepository: widget.fiiRepository,
                quoteRepository: widget.quoteRepository,
                isDarkMode: widget.isDarkMode,
                onToggleTheme: widget.onToggleTheme,
                preferredMarket: widget.preferredMarket,
                onChangePreferredMarket: widget.onChangePreferredMarket,
                onLogin: widget.onLogin,
                onRegister: widget.onRegister,
                onLogout: widget.onLogout,
              ),
            ),
            _tabRoot(
              AppTab.portfolio,
              PortfolioTabScreen(
                portfolio: widget.portfolio,
                onPortfolioChanged: widget.onPortfolioChanged,
                fiiRepository: widget.fiiRepository,
                quoteRepository: widget.quoteRepository,
              ),
            ),
            _tabRoot(
              AppTab.search,
              SearchTabScreen(
                portfolio: widget.portfolio,
                fiiRepository: widget.fiiRepository,
                quoteRepository: widget.quoteRepository,
                initialQuery: _pendingSearchQuery,
                onInitialQueryApplied: _consumePendingSearchQuery,
              ),
            ),
            _tabRoot(AppTab.community, const CommunityTabScreen()),
            _tabRoot(AppTab.finances, const FinancesTabScreen()),
            _tabRoot(
              AppTab.menu,
              MenuTabScreen(
                profile: widget.profile,
                onProfileChanged: widget.onProfileChanged,
                portfolio: widget.portfolio,
                onPortfolioChanged: widget.onPortfolioChanged,
                fiiRepository: widget.fiiRepository,
                quoteRepository: widget.quoteRepository,
                globalMarketRepository: widget.globalMarketRepository,
                isDarkMode: widget.isDarkMode,
                onToggleTheme: widget.onToggleTheme,
                onLogin: widget.onLogin,
                onRegister: widget.onRegister,
                onLogout: widget.onLogout,
              ),
            ),
          ],
        ),
        bottomNavigationBar: AppBottomNavBar(
          selectedIndex:
              _visibleTabs.indexOf(_tab).clamp(0, _visibleTabs.length - 1),
          onDestinationSelected: (index) => _selectTab(_visibleTabs[index]),
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
