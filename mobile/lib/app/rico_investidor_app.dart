import 'package:flutter/material.dart';
import 'package:rico_investidor/app/main_shell_screen.dart';
import 'package:rico_investidor/core/theme/app_theme.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/quotes/data/quote_repository.dart';
import 'package:rico_investidor/features/home/home_screen.dart';
import 'package:rico_investidor/models/user_profile.dart';
import 'package:rico_investidor/services/asset_search_service.dart';
import 'package:rico_investidor/state/portfolio_state.dart';

class RicoInvestidorApp extends StatefulWidget {
  const RicoInvestidorApp({super.key});

  @override
  State<RicoInvestidorApp> createState() => _RicoInvestidorAppState();
}

class _RicoInvestidorAppState extends State<RicoInvestidorApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  late UserProfile _profile = createDefaultProfile();
  final FiiRepository _fiiRepository = fiiRepository;
  final QuoteRepository _quoteRepository = quoteRepository;
  late final PortfolioState _portfolio = createInitialPortfolioState(
    searchService: AssetSearchService(
      fiiRepository: _fiiRepository,
      quoteRepository: _quoteRepository,
    ),
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
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rico Investidor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      home: MainShellScreen(
        profile: _profile,
        onProfileChanged: _updateProfile,
        portfolio: _portfolio,
        onPortfolioChanged: _onPortfolioChanged,
        fiiRepository: _fiiRepository,
        quoteRepository: _quoteRepository,
        isDarkMode: _themeMode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}
