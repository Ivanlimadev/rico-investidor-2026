import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/app/main_shell_screen.dart';
import 'package:rico_investidor/features/crypto/screens/crypto_explore_screen.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/global_markets/data/global_market_repository.dart';
import 'package:rico_investidor/features/home/data/home_repository.dart';
import 'package:rico_investidor/features/home/screens/world_exchanges_hub_screen.dart';
import 'package:rico_investidor/features/home/widgets/portfolio_allocation_card.dart';
import 'package:rico_investidor/features/home/widgets/crypto_market_hub_card.dart';
import 'package:rico_investidor/features/home/widgets/portfolio_summary_row.dart';
import 'package:rico_investidor/features/home/widgets/preferred_market_section.dart';
import 'package:rico_investidor/features/home/widgets/world_exchanges_hub_card.dart';
import 'package:rico_investidor/features/portfolio/portfolio_screen.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/features/menu/account_menu_items.dart';
import 'package:rico_investidor/features/settings/settings_screen.dart';
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
    required this.fiiRepository,
    required this.quoteRepository,
    required this.isDarkMode,
    required this.onToggleTheme,
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
  final FiiRepository fiiRepository;
  final QuoteRepository quoteRepository;
  final GlobalMarketRepository? globalMarketRepository;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
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

  GlobalMarketRepository get _globalMarketRepository =>
      widget.globalMarketRepository ?? globalMarketRepository;

  void scrollToTop() {
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

  void _openWorldExchanges(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WorldExchangesHubScreen(
          repository: _globalMarketRepository,
          fiiRepository: widget.fiiRepository,
          quoteRepository: widget.quoteRepository,
        ),
      ),
    );
  }

  void _openCrypto(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CryptoExploreScreen(
          fiiRepository: widget.fiiRepository,
          quoteRepository: widget.quoteRepository,
        ),
      ),
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
              'Olá, ${widget.profile.displayName}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Configurações',
            onPressed: () => openSettingsScreen(
              context,
              profile: widget.profile,
              onProfileChanged: widget.onProfileChanged,
              onLogin: widget.onLogin,
              onRegister: widget.onRegister,
              onLogout: widget.onLogout,
            ),
            icon: CircleAvatar(
              radius: 14,
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
              backgroundImage: widget.profile.hasPhoto ? NetworkImage(widget.profile.photoUrl!) : null,
              child: widget.profile.hasPhoto
                  ? null
                  : Icon(
                      Icons.person,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
            ),
          ),
          IconButton(
            tooltip: widget.isDarkMode ? 'Tema claro' : 'Tema escuro',
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
              onPortfolioTap: () => openPortfolioScreen(
                context,
                portfolio: widget.portfolio,
                onPortfolioChanged: widget.onPortfolioChanged,
                fiiRepository: widget.fiiRepository,
                quoteRepository: widget.quoteRepository,
              ),
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
                        fiiRepository: widget.fiiRepository,
                        quoteRepository: widget.quoteRepository,
                      ),
            ),
          ),
          SliverToBoxAdapter(
            child: PreferredMarketSection(
              // Lê do AppShellScope (InheritedWidget) — atravessa o Navigator
              // aninhado das abas, que captura o HomeScreen só na 1ª montagem.
              // Sem isso, trocar de mercado não atualizava a home.
              preference: AppShellScope.of(context).preferredMarket,
              globalMarketRepository: _globalMarketRepository,
              fiiRepository: widget.fiiRepository,
              quoteRepository: widget.quoteRepository,
              onChangePreferred: AppShellScope.of(context).onChangePreferredMarket,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Text(
                'Explore outros mercados',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: WorldExchangesHubCard(
              totalExchanges: null,
              onTap: () => _openWorldExchanges(context),
            ),
          ),
          SliverToBoxAdapter(
            child: CryptoMarketHubCard(
              onTap: () => _openCrypto(context),
            ),
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
