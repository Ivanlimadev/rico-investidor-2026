import 'package:flutter/material.dart';
import 'package:rico_investidor/app/main_shell_screen.dart';
import 'package:rico_investidor/data/mock_market_data.dart';
import 'package:rico_investidor/features/dividends/dividends_screen.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/fii/widgets/featured_fiis_row.dart';
import 'package:rico_investidor/features/home/data/home_repository.dart';
import 'package:rico_investidor/features/home/models/home_feed.dart';
import 'package:rico_investidor/features/home/widgets/market_category_card.dart';
import 'package:rico_investidor/features/home/widgets/portfolio_allocation_card.dart';
import 'package:rico_investidor/features/home/widgets/portfolio_summary_row.dart';
import 'package:rico_investidor/features/market/market_list_screen.dart';
import 'package:rico_investidor/features/portfolio/portfolio_screen.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/features/quotes/widgets/featured_stocks_row.dart';
import 'package:rico_investidor/features/settings/settings_screen.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/models/market_category_availability.dart';
import 'package:rico_investidor/models/subscription_plan.dart';
import 'package:rico_investidor/models/user_profile.dart';
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
  });

  final UserProfile profile;
  final void Function(UserProfile profile) onProfileChanged;
  final PortfolioState portfolio;
  final VoidCallback onPortfolioChanged;
  final HomeRepository homeRepository;
  final FiiRepository fiiRepository;
  final QuoteRepository quoteRepository;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<HomeFeed> _feedFuture;

  @override
  void initState() {
    super.initState();
    _feedFuture = widget.homeRepository.loadFeed();
  }

  void _retryFeed() {
    widget.homeRepository.invalidateFeed();
    setState(() {
      _feedFuture = widget.homeRepository.loadFeed();
    });
  }

  void _openCategory(BuildContext context, MarketCategory category) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MarketListScreen(
          category: category,
          fiiRepository: widget.fiiRepository,
          quoteRepository: widget.quoteRepository,
        ),
      ),
    );
  }

  int? _marketCount(HomeFeed? feed, MarketCategory category) {
    if (category.isDemo) return null;

    final fallback = MockMarketData.byCategory(category).length;
    if (feed == null) return fallback;

    return switch (category) {
      MarketCategory.fiis => feed.marketCounts.fiis ?? fallback,
      MarketCategory.acoesBr => feed.marketCounts.acoesBr ?? fallback,
      MarketCategory.bdr => feed.marketCounts.bdr ?? fallback,
      MarketCategory.etf => feed.marketCounts.etf ?? fallback,
      MarketCategory.etfInternacional => feed.marketCounts.etfIntl ?? fallback,
      MarketCategory.moeda => feed.marketCounts.moeda ?? fallback,
      MarketCategory.tesouroDireto => feed.marketCounts.tesouro ?? fallback,
      MarketCategory.indices => feed.marketCounts.indices ?? fallback,
      MarketCategory.cripto => feed.marketCounts.cripto ?? fallback,
      _ => fallback,
    };
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
      body: FutureBuilder<HomeFeed>(
        future: _feedFuture,
        builder: (context, snapshot) {
          final feed = snapshot.data;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: PortfolioSummaryRow(
                  summary: widget.portfolio.buildSummary(),
                  onPortfolioTap: () => openPortfolioScreen(
                    context,
                    portfolio: widget.portfolio,
                    onPortfolioChanged: widget.onPortfolioChanged,
                    fiiRepository: widget.fiiRepository,
                    quoteRepository: widget.quoteRepository,
                  ),
                  onDividendsTap: () => openDividendsScreen(
                    context,
                    portfolio: widget.portfolio,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: PortfolioAllocationCard(
                  portfolio: widget.portfolio,
                  onTap: () => openPortfolioScreen(
                    context,
                    portfolio: widget.portfolio,
                    onPortfolioChanged: widget.onPortfolioChanged,
                    fiiRepository: widget.fiiRepository,
                    quoteRepository: widget.quoteRepository,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Text(
                    'FIIs em destaque',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: FeaturedFiisRow(
                  repository: widget.fiiRepository,
                  initialItems: feed?.featuredFiis,
                  loading: snapshot.connectionState == ConnectionState.waiting,
                  error: snapshot.hasError ? snapshot.error : null,
                  onRetry: _retryFeed,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Text(
                    'Principais ações',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: FeaturedStocksRow(
                  repository: widget.quoteRepository,
                  fiiRepository: widget.fiiRepository,
                  initialItems: feed?.featuredStocks,
                  loading: snapshot.connectionState == ConnectionState.waiting,
                  error: snapshot.hasError ? snapshot.error : null,
                  onRetry: _retryFeed,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Text(
                    'Mercados',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, kBottomNavContentPadding),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.82,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final category = MarketCategory.values[index];
                      return MarketCategoryCard(
                        category: category,
                        assetCount: _marketCount(feed, category),
                        isDemo: category.isDemo,
                        onTap: () => _openCategory(context, category),
                      );
                    },
                    childCount: MarketCategory.values.length,
                  ),
                ),
              ),
            ],
          );
        },
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
