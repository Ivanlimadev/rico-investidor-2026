import 'package:flutter/material.dart';
import 'package:rico_investidor/app/main_shell_screen.dart';
import 'package:rico_investidor/data/mock_market_data.dart';
import 'package:rico_investidor/features/dividends/dividends_screen.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/features/quotes/widgets/featured_stocks_row.dart';
import 'package:rico_investidor/features/fii/widgets/featured_fiis_row.dart';
import 'package:rico_investidor/features/home/widgets/market_category_card.dart';
import 'package:rico_investidor/features/home/widgets/portfolio_allocation_card.dart';
import 'package:rico_investidor/features/home/widgets/portfolio_summary_row.dart';
import 'package:rico_investidor/features/market/market_list_screen.dart';
import 'package:rico_investidor/features/portfolio/portfolio_screen.dart';
import 'package:rico_investidor/features/settings/settings_screen.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/models/subscription_plan.dart';
import 'package:rico_investidor/models/user_profile.dart';
import 'package:rico_investidor/state/portfolio_state.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Rico Investidor'),
            Text(
              'Olá, ${profile.displayName}',
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
              profile: profile,
              onProfileChanged: onProfileChanged,
            ),
            icon: CircleAvatar(
              radius: 14,
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
              backgroundImage: profile.hasPhoto ? NetworkImage(profile.photoUrl!) : null,
              child: profile.hasPhoto
                  ? null
                  : Icon(
                      Icons.person,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
            ),
          ),
          IconButton(
            tooltip: isDarkMode ? 'Tema claro' : 'Tema escuro',
            onPressed: onToggleTheme,
            icon: Icon(isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: PortfolioSummaryRow(
              summary: portfolio.buildSummary(),
              onPortfolioTap: () => openPortfolioScreen(
                context,
                portfolio: portfolio,
                onPortfolioChanged: onPortfolioChanged,
                fiiRepository: fiiRepository,
              ),
              onDividendsTap: () => openDividendsScreen(
                context,
                portfolio: portfolio,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: PortfolioAllocationCard(
              portfolio: portfolio,
              onTap: () => openPortfolioScreen(
                context,
                portfolio: portfolio,
                onPortfolioChanged: onPortfolioChanged,
                fiiRepository: fiiRepository,
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
          SliverToBoxAdapter(child: FeaturedFiisRow(repository: fiiRepository)),
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
              repository: quoteRepository,
              fiiRepository: fiiRepository,
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
                  if (category == MarketCategory.fiis) {
                    return _FiiCategoryCard(
                      fiiRepository: fiiRepository,
                      onTap: () => _openCategory(context, category),
                    );
                  }
                  final count = MockMarketData.byCategory(category).length;
                  return MarketCategoryCard(
                    category: category,
                    assetCount: count,
                    onTap: () => _openCategory(context, category),
                  );
                },
                childCount: MarketCategory.values.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FiiCategoryCard extends StatelessWidget {
  const _FiiCategoryCard({
    required this.fiiRepository,
    required this.onTap,
  });

  final FiiRepository fiiRepository;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: fiiRepository.totalCount(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? MockMarketData.byCategory(MarketCategory.fiis).length;
        return MarketCategoryCard(
          category: MarketCategory.fiis,
          assetCount: count,
          onTap: onTap,
        );
      },
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
