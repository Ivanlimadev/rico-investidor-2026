import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rico_investidor/app/main_shell_screen.dart';
import 'package:rico_investidor/core/auth/auth_session.dart';
import 'package:rico_investidor/core/theme/app_theme.dart';
import 'package:rico_investidor/features/auth/data/auth_repository.dart';
import 'package:rico_investidor/features/auth/screens/auth_welcome_screen.dart';
import 'package:rico_investidor/features/auth/screens/login_screen.dart';
import 'package:rico_investidor/features/auth/screens/register_screen.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/global_markets/data/global_market_repository.dart';
import 'package:rico_investidor/features/home/data/home_repository.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/features/home/home_screen.dart';
import 'package:rico_investidor/features/onboarding/market_onboarding_screen.dart';
import 'package:rico_investidor/features/onboarding/premium_intro_screen.dart';
import 'package:rico_investidor/models/user_profile.dart';
import 'package:rico_investidor/services/account_onboarding_storage.dart';
import 'package:rico_investidor/services/asset_search_service.dart';
import 'package:rico_investidor/features/home/data/preferred_market_preloader.dart';
import 'package:rico_investidor/services/app_bootstrap_service.dart';
import 'package:rico_investidor/services/market_preference_storage.dart';
import 'package:rico_investidor/services/portfolio_dividend_service.dart';
import 'package:rico_investidor/services/portfolio_fx_service.dart';
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
  bool _accountLoaded = false;
  bool _accountOnboardingCompleted = false;
  bool _introCompleted = false;
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
    unawaited(_syncPortfolioDividends());
  }

  Future<void> _loadPortfolio() async {
    final saved = await _portfolioStorage.load();
    if (!mounted || saved == null) return;
    setState(() {
      _portfolio = PortfolioState(
        searchService: assetSearchService,
        holdings: saved.holdings,
        dividends: saved.dividends,
        usdBrlRate: _portfolio.usdBrlRate,
      );
    });
    unawaited(_syncPortfolioDividends());
  }

  Future<void> _loadPortfolioFx() async {
    final rate = await portfolioFxService.fetchUsdBrlRate();
    if (!mounted || rate == null) return;
    setState(() => _portfolio.usdBrlRate = rate);
  }

  Future<void> _syncPortfolioDividends() async {
    await portfolioDividendService.syncPortfolioDividends(_portfolio);
    if (!mounted) return;
    setState(() {});
    await _portfolioStorage.save(
      holdings: _portfolio.holdings,
      dividends: _portfolio.dividends,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadPortfolio();
    _loadAccountState();
    _loadPreference();
    unawaited(_loadPortfolioFx());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_warmIntroData());
      unawaited(_syncPortfolioDividends());
      Future<void>.delayed(const Duration(seconds: 2), _refreshPortfolioPrices);
    });
  }

  Future<void> _warmIntroData() async {
    final preference = await marketPreferenceStorage.load();
    await appBootstrapService.warmIntro(
      preferredMarket: preference,
      quoteRepository: _quoteRepository,
      globalMarketRepository: _globalMarketRepository,
      fiiRepository: _fiiRepository,
    );
  }

  Future<void> _loadAccountState() async {
    final onboardingDone = await accountOnboardingStorage.isCompleted();
    var profile = createDefaultProfile();

    if (authSession.accessToken != null) {
      try {
        profile = await authRepository.fetchProfile();
        if (profile.isRegistered) {
          await accountOnboardingStorage.markCompleted();
        }
      } catch (_) {
        // Sem /me (auth desligado ou offline) — mantém perfil local.
      }
    }

    if (!mounted) return;
    setState(() {
      _profile = profile;
      _accountOnboardingCompleted = onboardingDone || profile.isRegistered;
      _accountLoaded = true;
    });
  }

  Future<void> _completeAccountOnboarding() async {
    await accountOnboardingStorage.markCompleted();
    UserProfile profile = createDefaultProfile();
    try {
      profile = await authRepository.fetchProfile();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _accountOnboardingCompleted = true;
      _profile = profile;
    });
  }

  Future<void> _skipAccountOnboarding() async {
    await accountOnboardingStorage.markCompleted();
    if (!mounted) return;
    setState(() => _accountOnboardingCompleted = true);
  }

  void _openLogin() {
    _navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (context) => LoginScreen(
          onSuccess: () async {
            Navigator.of(context).pop();
            await _completeAccountOnboarding();
          },
        ),
      ),
    );
  }

  void _openRegister() {
    _navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (context) => RegisterScreen(
          onSuccess: () async {
            Navigator.of(context).pop();
            await _completeAccountOnboarding();
          },
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await authRepository.logout();
    UserProfile profile = createDefaultProfile();
    try {
      profile = await authRepository.fetchProfile();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _profile = profile);
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
    preferredMarketPreloader.invalidate();
    if (!mounted) return;
    setState(() => _preferredMarket = preference);
    unawaited(
      appBootstrapService.warmIntro(
        preferredMarket: preference,
        quoteRepository: _quoteRepository,
        globalMarketRepository: _globalMarketRepository,
        fiiRepository: _fiiRepository,
      ),
    );
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
    await _loadPortfolioFx();
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
    if (!_introCompleted) {
      return PremiumIntroScreen(
        onFinished: () => setState(() => _introCompleted = true),
      );
    }

    if (!_preferenceLoaded || !_accountLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_accountOnboardingCompleted) {
      return AuthWelcomeScreen(
        onCompleted: _completeAccountOnboarding,
        onSkip: _skipAccountOnboarding,
      );
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
      onLogin: _openLogin,
      onRegister: _openRegister,
      onLogout: _logout,
    );
  }
}
