import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/core/ads/feed_ad_widget.dart';
import 'package:rico_investidor/core/widgets/safe_network_avatar.dart';
import 'package:rico_investidor/app/main_shell_screen.dart';
import 'package:rico_investidor/features/crypto/screens/crypto_explore_screen.dart';
import 'package:rico_investidor/features/global_markets/data/global_market_repository.dart';
import 'package:rico_investidor/features/home/data/home_repository.dart';
import 'package:rico_investidor/features/home/widgets/portfolio_allocation_card.dart';
import 'package:rico_investidor/features/home/widgets/crypto_market_hub_card.dart';
import 'package:rico_investidor/features/home/widgets/portfolio_summary_row.dart';
import 'package:rico_investidor/features/home/widgets/preferred_market_section.dart';
import 'package:rico_investidor/features/dividends/screens/portfolio_month_dividends_screen.dart';
import 'package:rico_investidor/core/auth/auth_session.dart';
import 'package:rico_investidor/services/portfolio_dividend_service.dart';
import 'package:rico_investidor/services/portfolio_price_service.dart';
import 'package:rico_investidor/features/home/data/preferred_market_preloader.dart';
import 'package:rico_investidor/services/portfolio_storage.dart';
import 'package:rico_investidor/features/portfolio/portfolio_screen.dart';
import 'package:rico_investidor/features/menu/account_menu_items.dart';
import 'package:rico_investidor/features/settings/settings_screen.dart';
import 'package:rico_investidor/l10n/app_strings.dart';
import 'package:rico_investidor/core/ads/ad_subscription_plan.dart';
import 'package:rico_investidor/models/subscription_plan.dart';
import 'package:rico_investidor/models/user_profile.dart';
import 'package:rico_investidor/services/market_preference_storage.dart';
import 'package:rico_investidor/state/portfolio_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.profile,
    required this.onProfileChanged,
    required this.portfolio,
    required this.onPortfolioChanged,
    required this.homeRepository,
    required this.isDarkMode,
    required this.onToggleTheme,
    this.onThemeModeChanged,
    required this.preferredMarket,
    required this.onChangePreferredMarket,
    required this.onLogin,
    required this.onRegister,
    required this.onLogout,
    this.globalMarketRepository,
  });

  final UserProfile profile;
  final void Function(UserProfile profile) onProfileChanged;
  final PortfolioState portfolio;
  final VoidCallback onPortfolioChanged;
  final HomeRepository homeRepository;
  final GlobalMarketRepository? globalMarketRepository;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final MarketPreference preferredMarket;
  final VoidCallback onChangePreferredMarket;
  final VoidCallback onLogin;
  final VoidCallback onRegister;
  final LogoutCallback onLogout;

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final ScrollController scrollController = ScrollController();
  bool _syncingPortfolio = false;
  String? _syncMessage;
  int _marketDataGeneration = 0;

  GlobalMarketRepository get _globalMarketRepository =>
      widget.globalMarketRepository ?? globalMarketRepository;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      refreshMarketQuotes();
      unawaited(_syncPortfolioOnHomeOpen());
      unawaited(_refreshPortfolioPricesOnHome());
    });
  }

  void refreshMarketQuotes() {
    preferredMarketPreloader.invalidate();
    _globalMarketRepository.invalidateHeatmapCache();
    setState(() => _marketDataGeneration++);
  }

  Future<void> _refreshPortfolioPricesOnHome() async {
    if (widget.portfolio.holdings.isEmpty) return;
    await PortfolioPriceService().refreshAllDetailed(widget.portfolio);
    if (!mounted) return;
    widget.onPortfolioChanged();
  }

  Future<void> _syncPortfolioOnHomeOpen() async {
    if (widget.portfolio.holdings.isEmpty) return;

    setState(() {
      _syncingPortfolio = true;
      _syncMessage = null;
    });

    try {
      await authSession.ensureAuthenticated();
    } catch (_) {}

    var dividendsOk = false;
    try {
      final divResult = await portfolioDividendService.syncPortfolioDividends(widget.portfolio);
      dividendsOk = divResult.completed;
    } catch (_) {}

    if (!mounted) return;

    widget.onPortfolioChanged();
    if (dividendsOk) {
      await PortfolioStorage().save(
        holdings: widget.portfolio.holdings,
        dividends: widget.portfolio.dividends,
      );
    }

    setState(() {
      _syncingPortfolio = false;
      _syncMessage = null;
    });
  }

  void scrollToTop() {
    refreshMarketQuotes();
    if (!scrollController.hasClients) return;
    scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  void _openCrypto(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CryptoExploreScreen(),
      ),
    );
  }

  Future<void> _openMonthDividends(BuildContext context) async {
    if (widget.portfolio.holdings.isNotEmpty) {
      final result = await portfolioDividendService.syncPortfolioDividends(widget.portfolio);
      if (result.completed) {
        widget.onPortfolioChanged();
        await PortfolioStorage().save(
          holdings: widget.portfolio.holdings,
          dividends: widget.portfolio.dividends,
        );
      }
    }
    if (!context.mounted) return;
    openPortfolioMonthDividendsScreen(
      context,
      portfolio: widget.portfolio,
      onPortfolioChanged: widget.onPortfolioChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Rico Investidor'),
            Text(
              AppStrings.homeGreeting(widget.profile.displayName),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: AppStrings.settingsTooltip,
            onPressed: () => openSettingsScreen(
              context,
              profile: widget.profile,
              onProfileChanged: widget.onProfileChanged,
              onLogin: widget.onLogin,
              onRegister: widget.onRegister,
              onLogout: widget.onLogout,
              onThemeModeChanged: widget.onThemeModeChanged,
            ),
            icon: SafeNetworkAvatar(
              radius: 14,
              photoUrl: widget.profile.hasPhoto ? widget.profile.photoUrl : null,
            ),
          ),
          IconButton(
            tooltip: widget.isDarkMode ? AppStrings.lightThemeTooltip : AppStrings.darkThemeTooltip,
            onPressed: widget.onToggleTheme,
            icon: Icon(widget.isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
          ),
        ],
      ),
      body: CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: PortfolioSummaryRow(
              portfolio: widget.portfolio,
              preferredMarket: widget.preferredMarket,
              countryCode: widget.profile.countryCode,
              syncMessage: _syncMessage,
              syncing: _syncingPortfolio,
              onPortfolioTap: () => openPortfolioScreen(
                context,
                portfolio: widget.portfolio,
                onPortfolioChanged: widget.onPortfolioChanged,
              ),
              onDividendsTap: () => _openMonthDividends(context),
            ),
          ),
          SliverToBoxAdapter(
            child: PortfolioAllocationCard(
              portfolio: widget.portfolio,
              preferredMarket: widget.preferredMarket,
              onTap: widget.portfolio.holdings.isEmpty
                  ? () => openAddAssetScreen(
                        context,
                        portfolio: widget.portfolio,
                        onPortfolioChanged: widget.onPortfolioChanged,
                      )
                  : () => openPortfolioScreen(
                        context,
                        portfolio: widget.portfolio,
                        onPortfolioChanged: widget.onPortfolioChanged,
                      ),
            ),
          ),
          SliverToBoxAdapter(
            child: PreferredMarketSection(
              key: ValueKey('preferred-market-$_marketDataGeneration'),
              // Lê do AppShellScope (InheritedWidget) — atravessa o Navigator
              // aninhado das abas, que captura o HomeScreen só na 1ª montagem.
              // Sem isso, trocar de mercado não atualizava a home.
              preference: AppShellScope.of(context).preferredMarket,
              globalMarketRepository: _globalMarketRepository,
              onChangePreferred: AppShellScope.of(context).onChangePreferredMarket,
            ),
          ),
          SliverToBoxAdapter(
            child: RicoFeedAd(plan: kAdsSubscriptionPlan),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Text(
                AppStrings.cryptoSection,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: CryptoMarketHubCard(
              onTap: () => _openCrypto(context),
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 16),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: kBottomNavContentPadding),
          ),
        ],
      ),
    );
  }
}

/// Perfil inicial de demonstração até integrar autenticação.
UserProfile createDefaultProfile() {
  return const UserProfile(
    displayName: 'Investidor',
    plan: SubscriptionPlan.free,
  );
}
