import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/features/fii/utils/fii_ticker.dart';
import 'package:rico_investidor/models/market_category.dart';

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
  return switch (category) {
    MarketCategory.stocks ||
    MarketCategory.reits ||
    MarketCategory.etfInternacional ||
    MarketCategory.cripto =>
      HoldingCurrency.usd,
    _ => HoldingCurrency.brl,
  };
}

HoldingCurrency holdingCurrencyForSymbol(String symbol) {
  final normalized = symbol.trim().toUpperCase();
  if (normalized.endsWith('.SA')) return HoldingCurrency.brl;
  if (isFiiTicker(normalized)) return HoldingCurrency.brl;
  if (normalized.length >= 2) {
    final suffix = normalized.substring(normalized.length - 2);
    if ({'11', '34', '35', '39'}.contains(suffix)) return HoldingCurrency.brl;
  }
  if (RegExp(r'^[A-Z]{1,5}([.-][A-Z])?$').hasMatch(normalized)) {
    return HoldingCurrency.usd;
  }
  return HoldingCurrency.brl;
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
