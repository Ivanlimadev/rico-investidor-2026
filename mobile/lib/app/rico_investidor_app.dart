import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rico_investidor/app/main_shell_screen.dart';
import 'package:rico_investidor/core/auth/auth_session.dart';
import 'package:rico_investidor/core/network/api_client.dart';
import 'package:rico_investidor/core/theme/app_theme.dart';
import 'package:rico_investidor/features/auth/data/auth_repository.dart';
import 'package:rico_investidor/features/auth/screens/auth_welcome_screen.dart';
import 'package:rico_investidor/features/auth/screens/login_screen.dart';
import 'package:rico_investidor/features/auth/screens/register_screen.dart';
import 'package:rico_investidor/features/global_markets/data/global_market_repository.dart';
import 'package:rico_investidor/features/home/data/home_repository.dart';
import 'package:rico_investidor/features/home/home_screen.dart';
import 'package:rico_investidor/features/onboarding/market_onboarding_screen.dart';
// HIDDEN: premium intro — import kept for when subscription launches
// import 'package:rico_investidor/features/onboarding/premium_intro_screen.dart';
import 'package:rico_investidor/models/user_profile.dart';
import 'package:rico_investidor/services/account_onboarding_storage.dart';
import 'package:rico_investidor/services/asset_search_service.dart';
import 'package:rico_investidor/features/home/data/preferred_market_preloader.dart';
import 'package:rico_investidor/services/app_bootstrap_service.dart';
import 'package:rico_investidor/core/markets/supported_market_countries.dart';
import 'package:rico_investidor/services/portfolio_data_migration.dart';
import 'package:rico_investidor/services/market_preference_storage.dart';
import 'package:rico_investidor/services/portfolio_dividend_service.dart';
import 'package:rico_investidor/services/portfolio_fx_service.dart';
import 'package:rico_investidor/services/portfolio_price_service.dart';
import 'package:rico_investidor/services/user_preferences_storage.dart';
import 'package:rico_investidor/features/portfolio/data/portfolio_repository.dart';
import 'package:rico_investidor/services/portfolio_storage.dart';
import 'package:rico_investidor/state/portfolio_state.dart';

class RicoInvestidorApp extends StatefulWidget {
  const RicoInvestidorApp({super.key});

  @override
  State<RicoInvestidorApp> createState() => _RicoInvestidorAppState();
}

class _RicoInvestidorAppState extends State<RicoInvestidorApp> {
  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale(defaultLocaleCode);
  UserPreferences? _userPreferences;
  late UserProfile _profile = createDefaultProfile();
  final HomeRepository _homeRepository = homeRepository;
  final GlobalMarketRepository _globalMarketRepository = globalMarketRepository;
  final PortfolioStorage _portfolioStorage = PortfolioStorage();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  MarketPreference? _preferredMarket;
  bool _preferenceLoaded = false;
  bool _accountLoaded = false;
  bool _accountOnboardingCompleted = false;
  bool _portfolioBootstrapped = false;
  late PortfolioState _portfolio = createInitialPortfolioState(
    searchService: assetSearchService,
  );

  void _toggleTheme() {
    final next = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    _setThemeMode(next);
  }

  void _setThemeMode(ThemeMode mode) {
    final current = _userPreferences ??
        UserPreferences(
          themeMode: _themeMode,
          notificationsEnabled: true,
          localeCode: defaultLocaleCode,
        );
    final updated = current.copyWith(themeMode: mode);
    setState(() {
      _themeMode = mode;
      _userPreferences = updated;
    });
    unawaited(userPreferencesStorage.save(updated));
  }

  void _updateProfile(UserProfile profile) {
    setState(() => _profile = profile);
  }

  void _rebuildPortfolioUi() {
    setState(() {
      _portfolio = _portfolio.cloneForUi();
    });
  }

  UserProfile _profileFromSession(UserProfile profile) {
    if (authSession.isRegisteredSession && profile.isAnonymous) {
      return profile.copyWith(isAnonymous: false);
    }
    return profile;
  }

  void _onPortfolioChanged() {
    _rebuildPortfolioUi();
    unawaited(
      _portfolioStorage.save(
        holdings: _portfolio.holdings,
        dividends: _portfolio.dividends,
      ),
    );
    if (!_portfolioBootstrapped && _portfolio.holdings.isNotEmpty) {
      unawaited(_bootstrapPortfolioData());
    }
  }

  Future<void> _loadPortfolio() async {
    try {
      await authSession.ensureAuthenticated();
    } catch (_) {}

    if (authSession.isRegisteredSession) {
      final loadedRemote = await _loadPortfolioFromServer();
      if (loadedRemote) {
        unawaited(_bootstrapPortfolioData());
        return;
      }
    }

    final saved = await _portfolioStorage.load();
    if (!mounted) return;

    if (saved != null) {
      final migrated = PortfolioDataMigration.migrateHoldings(saved.holdings);
      final repairedHoldings = PortfolioState.repairHoldingsCurrencies(
        PortfolioDataMigration.dropOrphanBrazilHoldings(migrated),
        searchService: assetSearchService,
      );
      setState(() {
        _portfolio = PortfolioState(
          searchService: assetSearchService,
          holdings: repairedHoldings,
          dividends: saved.dividends,
          usdBrlRate: _portfolio.usdBrlRate,
        );
      });
    }

    unawaited(_bootstrapPortfolioData());
  }

  Future<bool> _loadPortfolioFromServer() async {
    if (!portfolioRepository.canSync) return false;
    try {
      final remote = await portfolioRepository.fetchRemoteHoldings();
      if (!mounted) return false;
      final repaired = PortfolioState.repairHoldingsCurrencies(
        remote,
        searchService: assetSearchService,
      );
      setState(() {
        _portfolio = PortfolioState(
          searchService: assetSearchService,
          holdings: repaired,
          dividends: _portfolio.dividends,
          usdBrlRate: _portfolio.usdBrlRate,
        );
      });
      await _portfolioStorage.save(
        holdings: _portfolio.holdings,
        dividends: _portfolio.dividends,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _migratePortfolioAfterRegistration() async {
    if (!authSession.isRegisteredSession) return;

    final messenger = _scaffoldMessengerKey.currentState;
    messenger?.showSnackBar(
      const SnackBar(content: Text('Carregando carteira da conta…')),
    );

    try {
      final local = await _portfolioStorage.load();
      final localHoldings = local?.holdings ?? _portfolio.holdings;

      // Servidor (Postgres) primeiro — não sobrescrever com cache local zerado.
      var loadedRemote = await _loadPortfolioFromServer();
      if (!loadedRemote && localHoldings.isNotEmpty) {
        final synced = await portfolioRepository.syncLocalHoldings(localHoldings);
        if (!mounted) return;
        setState(() {
          _portfolio = PortfolioState(
            searchService: assetSearchService,
            holdings: PortfolioState.repairHoldingsCurrencies(
              synced,
              searchService: assetSearchService,
            ),
            dividends: local?.dividends ?? _portfolio.dividends,
            usdBrlRate: _portfolio.usdBrlRate,
          );
        });
        loadedRemote = _portfolio.holdings.isNotEmpty;
      }

      if (!loadedRemote) {
        messenger?.showSnackBar(
          const SnackBar(content: Text('Não foi possível carregar a carteira agora')),
        );
        return;
      }

      final priceResult = await PortfolioPriceService().refreshAllDetailed(_portfolio);
      if (!mounted) return;
      if (priceResult.updated > 0) {
        _rebuildPortfolioUi();
      }

      await _portfolioStorage.save(
        holdings: _portfolio.holdings,
        dividends: _portfolio.dividends,
      );
      _portfolioBootstrapped = false;
      unawaited(_bootstrapPortfolioData());
      messenger?.showSnackBar(
        const SnackBar(content: Text('Carteira vinculada à sua conta')),
      );
    } catch (_) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Não foi possível salvar a carteira agora')),
      );
    }
  }

  Future<void> _clearPortfolioState() async {
    await _portfolioStorage.clear();
    if (!mounted) return;
    setState(() {
      _portfolio = createInitialPortfolioState(searchService: assetSearchService);
      _portfolioBootstrapped = false;
    });
  }

  Future<void> _loadPortfolioFx() async {
    final rate = await portfolioFxService.fetchUsdBrlRate();
    if (!mounted || rate == null) return;
    setState(() => _portfolio.usdBrlRate = rate);
  }

  @override
  void initState() {
    super.initState();
    authSession.onSessionRefreshed = _onAuthSessionRefreshed;
    authSession.onSessionExpired = _onSessionExpired;
    _loadPortfolio();
    _loadAccountState();
    _loadPreference();
    _loadUserPreferences();
    unawaited(_loadPortfolioFx());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_warmIntroData());
      unawaited(_warnIfBackendOffline());
    });
  }

  Future<void> _warnIfBackendOffline() async {
    final backendOk = await apiClient.checkHealth();
    if (!backendOk) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text(
            'Backend offline. Suba a API: uvicorn app.main:app --reload --host 127.0.0.1 --port 8000',
          ),
          duration: Duration(seconds: 10),
        ),
      );
      return;
    }

    if (authSession.accessToken == null || authSession.accessToken!.isEmpty) {
      try {
        await authSession.ensureAuthenticated();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    if (authSession.onSessionRefreshed == _onAuthSessionRefreshed) {
      authSession.onSessionRefreshed = null;
    }
    if (authSession.onSessionExpired == _onSessionExpired) {
      authSession.onSessionExpired = null;
    }
    super.dispose();
  }

  void _onAuthSessionRefreshed() {
    if (!mounted) return;
    unawaited(_loadAccountState());
    unawaited(_refreshPortfolioPrices(showErrorOnFailure: false));
  }

  Future<void> _bootstrapPortfolioData() async {
    if (_portfolioBootstrapped || _portfolio.holdings.isEmpty) return;
    _portfolioBootstrapped = true;

    for (var i = 0; i < 40; i++) {
      if (!mounted) return;
      if (_accountLoaded && _preferenceLoaded) break;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    try {
      await authSession.ensureAuthenticated();
    } catch (_) {}

    if (!mounted || _portfolio.holdings.isEmpty) return;

    final priceResult = await PortfolioPriceService().refreshAllDetailed(_portfolio);

    var dividendsSynced = false;
    try {
      final divResult = await portfolioDividendService.syncPortfolioDividends(_portfolio);
      dividendsSynced = divResult.completed;
    } catch (_) {}

    if (!mounted) return;

    _rebuildPortfolioUi();
    if (dividendsSynced || priceResult.updated > 0) {
      await _portfolioStorage.save(
        holdings: _portfolio.holdings,
        dividends: _portfolio.dividends,
      );
    }

    if (!priceResult.isSuccess && !(priceResult.updated > 0 || dividendsSynced)) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível sincronizar a carteira. Confirme o backend em http://127.0.0.1:8000/health',
          ),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  void _onSessionExpired() {
    if (!mounted) return;
    unawaited(_handleSessionExpired());
  }

  Future<void> _handleSessionExpired() async {
    final nav = _navigatorKey.currentState;
    if (nav == null) return;

    nav.popUntil((route) => route.isFirst);

    _scaffoldMessengerKey.currentState?.clearSnackBars();
    _scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text('Sessão expirada. Entre novamente para continuar.'),
        duration: Duration(seconds: 5),
      ),
    );

    if (!mounted) return;
    setState(() => _profile = createDefaultProfile());

    await nav.push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => LoginScreen(
          sessionExpired: true,
          onSuccess: () async {
            Navigator.of(context).pop();
            await _completeAccountOnboarding();
          },
        ),
      ),
    );

    if (!mounted) return;
    if (!authSession.isRegisteredSession) {
      await authSession.ensureAuthenticated();
    }
    try {
      final profile = await authRepository.fetchProfile();
      if (!mounted) return;
      setState(() => _profile = profile);
    } catch (_) {
      if (!mounted) return;
      setState(() => _profile = createDefaultProfile());
    }
  }

  Future<void> _warmIntroData() async {
    final preference = await marketPreferenceStorage.load();
    await appBootstrapService.warmIntro(
      preferredMarket: preference,
      globalMarketRepository: _globalMarketRepository,
    );
  }

  Future<void> _loadAccountState() async {
    try {
      await authSession.ensureAuthenticated();
    } catch (_) {}

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
      _profile = _profileFromSession(profile);
      _accountOnboardingCompleted = onboardingDone || _profile.isRegistered;
      _accountLoaded = true;
    });
  }

  Future<void> _completeAccountOnboarding() async {
    await accountOnboardingStorage.markCompleted();
    UserProfile profile = createDefaultProfile().copyWith(
      isAnonymous: !authSession.isRegisteredSession,
    );
    try {
      profile = _profileFromSession(await authRepository.fetchProfile());
    } catch (_) {
      if (authSession.isRegisteredSession) {
        profile = profile.copyWith(isAnonymous: false);
      }
    }
    await _migratePortfolioAfterRegistration();
    await _loadPortfolio();
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

  void _openLogin({bool sessionExpired = false}) {
    _navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (context) => LoginScreen(
          sessionExpired: sessionExpired,
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
    await _clearPortfolioState();
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

    MarketPreference? preference = saved;
    if (preference == null) {
      preference = defaultMarketPreference;
      unawaited(marketPreferenceStorage.save(preference));
    }

    setState(() {
      _preferredMarket = preference;
      _preferenceLoaded = true;
    });
  }

  Future<void> _loadUserPreferences() async {
    final preferences = await userPreferencesStorage.load();
    if (!mounted) return;
    setState(() {
      _userPreferences = preferences;
      _themeMode = preferences.themeMode;
      _locale = preferences.locale;
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
          globalMarketRepository: _globalMarketRepository,
      ),
    );
  }

  void _changePreferredMarket() {
    final preference = _preferredMarket;
    if (preference == null) return;
    _navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => MarketOnboardingScreen(
          repository: _globalMarketRepository,
          currentCode: preference.code,
          allowBack: true,
          onConfirm: _confirmPreference,
        ),
      ),
    );
  }

  Future<void> _refreshPortfolioPrices({bool showErrorOnFailure = true}) async {
    if (!mounted || _portfolio.holdings.isEmpty) return;
    final before = _portfolio.patrimonioTotalUsd;
    final ok = await PortfolioPriceService(
    ).refreshAll(_portfolio);
    if (!mounted) return;
    final hasCachedPrices = _portfolio.holdings.any((holding) => holding.currentPrice > 0);
    if (!ok && showErrorOnFailure && !hasCachedPrices) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível atualizar os preços. Verifique se o backend está rodando e puxe para atualizar na aba Carteira.',
          ),
        ),
      );
    }
    if ((_portfolio.patrimonioTotalUsd - before).abs() > 0.009 || ok) {
      _rebuildPortfolioUi();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rico Investidor',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      locale: _locale,
      supportedLocales: const [Locale('en')],
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    // HIDDEN: premium intro — PremiumIntroScreen not shown until subscription launches
    // if (!_introCompleted) {
    //   return PremiumIntroScreen(
    //     onFinished: () => setState(() => _introCompleted = true),
    //   );
    // }

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
      globalMarketRepository: _globalMarketRepository,
      isDarkMode: _themeMode == ThemeMode.dark,
      onToggleTheme: _toggleTheme,
      onThemeModeChanged: _setThemeMode,
      preferredMarket: preference,
      onChangePreferredMarket: _changePreferredMarket,
      onLogin: _openLogin,
      onRegister: _openRegister,
      onLogout: _logout,
      onPortfolioAccountReady: _migratePortfolioAfterRegistration,
    );
  }
}
