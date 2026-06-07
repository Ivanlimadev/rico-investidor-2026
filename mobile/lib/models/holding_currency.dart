import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/models/portfolio_holding.dart';

enum HoldingCurrency {
  brl,
  usd;

  String get code => name;

  String format(double value) {
    return switch (this) {
      HoldingCurrency.usd => formatUsd(value),
      HoldingCurrency.brl => formatBrl(value),
    };
  }

  String get averagePriceLabel {
    return switch (this) {
      HoldingCurrency.usd => 'Preço médio (US\$)',
      HoldingCurrency.brl => 'Preço médio (R\$)',
    };
  }

  static HoldingCurrency fromCode(String? code) {
    if (code == usd.code) return HoldingCurrency.usd;
    return HoldingCurrency.brl;
  }
}

HoldingCurrency holdingCurrencyForCategory(MarketCategory category) {
  return HoldingCurrency.usd;
}

HoldingCurrency holdingCurrencyForSymbol(String symbol) {
  return HoldingCurrency.usd;
}

double convertToUsd({
  required double amount,
  required HoldingCurrency currency,
  required double? usdBrlRate,
}) {
  if (currency == HoldingCurrency.usd) return amount;
  if (usdBrlRate == null || usdBrlRate <= 0) return 0;
  return amount / usdBrlRate;
}

double convertToBrl({
  required double amount,
  required HoldingCurrency currency,
  required double? usdBrlRate,
}) {
  if (currency == HoldingCurrency.brl) return amount;
  if (usdBrlRate == null || usdBrlRate <= 0) return 0;
  return amount * usdBrlRate;
}

bool isBdrSymbol(String symbol, {MarketCategory? category}) => false;

bool isInternationalUsdHolding(
  PortfolioHolding holding, {
  MarketCategory? category,
}) {
  return true;
}

HoldingCurrency resolvedHoldingCurrency(
  PortfolioHolding holding, {
  MarketCategory? category,
}) {
  return HoldingCurrency.usd;
}
