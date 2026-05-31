import 'package:flutter/material.dart';
import 'package:rico_investidor/app/main_shell_screen.dart';
import 'package:rico_investidor/core/theme/app_theme.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/global_markets/data/global_market_repository.dart';
import 'package:rico_investidor/features/home/data/home_repository.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/features/home/home_screen.dart';
import 'package:rico_investidor/features/onboarding/market_onboarding_screen.dart';
import 'package:rico_investidor/models/user_profile.dart';
import 'package:rico_investidor/services/asset_search_service.dart';
import 'package:rico_investidor/services/market_preference_storage.dart';
import 'package:rico_investidor/services/portfolio_price_service.dart';
import 'package:rico_investidor/services/portfolio_storage.dart';
import 'package:rico_investidor/state/portfolio_state.dart';

class RicoInvestidorApp extends StatefulWidget {
  const RicoInvestidorApp({super.key});

  @override
  State<RicoInvestidorApp> createState() => _RicoInvestidorAppState();
}

class _RicoInvestidorAppState extends State<RicoInvestidorApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  late UserProfile _profile = createDefaultProfile();
  final HomeRepository _homeRepository = homeRepository;
  final FiiRepository _fiiRepository = fiiRepository;
  final QuoteRepository _quoteRepository = quoteRepository;
  final GlobalMarketRepository _globalMarketRepository = globalMarketRepository;
  final PortfolioStorage _portfolioStorage = PortfolioStorage();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  MarketPreference? _preferredMarket;
  bool _preferenceLoaded = false;
  late PortfolioState _portfolio = createInitialPortfolioState(
    searchService: assetSearchService,
  );

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void _updateProfile(UserProfile profile) {
    setState(() => _profile = profile);
  }

  void _onPortfolioChanged() {
    setState(() {});
    _portfolioStorage.save(
      holdings: _portfolio.holdings,
      dividends: _portfolio.dividends,
    );
  }

  Future<void> _loadPortfolio() async {
    final saved = await _portfolioStorage.load();
    if (!mounted || saved == null) return;
    setState(() {
      _portfolio = PortfolioState(
        searchService: assetSearchService,
        holdings: saved.holdings,
        dividends: saved.dividends,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _loadPortfolio();
    _loadPreference();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(seconds: 2), _refreshPortfolioPrices);
    });
  }

  Future<void> _loadPreference() async {
    final saved = await marketPreferenceStorage.load();
    if (!mounted) return;
    setState(() {
      _preferredMarket = saved;
      _preferenceLoaded = true;
    });
  }

  Future<void> _confirmPreference(MarketPreference preference) async {
    await marketPreferenceStorage.save(preference);
    if (!mounted) return;
    setState(() => _preferredMarket = preference);
  }

  void _changePreferredMarket() {
    _navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (context) => MarketOnboardingScreen(
          repository: _globalMarketRepository,
          currentCode: _preferredMarket?.code,
          allowBack: true,
          onConfirm: (preference) {
            Navigator.of(context).pop();
            _confirmPreference(preference);
          },
        ),
      ),
    );
  }

  Future<void> _refreshPortfolioPrices() async {
    if (!mounted) return;
    final before = _portfolio.totalBalance;
    final ok = await PortfolioPriceService(
      quoteRepository: _quoteRepository,
    ).refreshAll(_portfolio);
    if (!mounted) return;
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível atualizar os preços da carteira.')),
      );
    }
    if ((_portfolio.totalBalance - before).abs() > 0.009) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rico Investidor',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (!_preferenceLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final preference = _preferredMarket;
    if (preference == null) {
      return MarketOnboardingScreen(
        repository: _globalMarketRepository,
        onConfirm: _confirmPreference,
      );
    }

    return MainShellScreen(
      profile: _profile,
      onProfileChanged: _updateProfile,
      portfolio: _portfolio,
      onPortfolioChanged: _onPortfolioChanged,
      homeRepository: _homeRepository,
      fiiRepository: _fiiRepository,
      quoteRepository: _quoteRepository,
      isDarkMode: _themeMode == ThemeMode.dark,
      onToggleTheme: _toggleTheme,
      preferredMarket: preference,
      onChangePreferredMarket: _changePreferredMarket,
    );
  }
}
