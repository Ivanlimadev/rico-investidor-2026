import 'dart:convert';

import 'package:rico_investidor/models/dividend_payment.dart';
import 'package:rico_investidor/models/portfolio_holding.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _holdingsKey = 'portfolio_holdings_v1';
const _dividendsKey = 'portfolio_dividends_v1';

class PortfolioStorage {
  Future<void> save({
    required List<PortfolioHolding> holdings,
    required List<DividendPayment> dividends,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _holdingsKey,
      jsonEncode(holdings.map((h) => h.toJson()).toList()),
    );
    await prefs.setString(
      _dividendsKey,
      jsonEncode(dividends.map((d) => d.toJson()).toList()),
    );
  }

  Future<({List<PortfolioHolding> holdings, List<DividendPayment> dividends})?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final holdingsRaw = prefs.getString(_holdingsKey);
    final dividendsRaw = prefs.getString(_dividendsKey);
    if (holdingsRaw == null) return null;

    final holdingsJson = jsonDecode(holdingsRaw) as List<dynamic>;
    final dividendsJson = dividendsRaw == null
        ? const <dynamic>[]
        : jsonDecode(dividendsRaw) as List<dynamic>;

    return (
      holdings: holdingsJson
          .map((e) => PortfolioHolding.fromJson(e as Map<String, dynamic>))
          .toList(),
      dividends: dividendsJson
          .map((e) => DividendPayment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
