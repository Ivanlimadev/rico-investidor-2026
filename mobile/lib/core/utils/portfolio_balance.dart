import 'package:rico_investidor/models/dividend_payment.dart';
import 'package:rico_investidor/models/holding_currency.dart';
import 'package:rico_investidor/models/market_category.dart';
import 'package:rico_investidor/models/portfolio_holding.dart';
import 'package:rico_investidor/services/market_preference_storage.dart';

/// Patrimônio separado: Brasil (R$) vs internacional (US$), sem BDRs na dolarização.
class PortfolioBalanceBreakdown {
  const PortfolioBalanceBreakdown({
    required this.domesticMarketValueBrl,
    required this.domesticInvestedBrl,
    required this.internationalMarketValueUsd,
    required this.internationalInvestedUsd,
    this.usdBrlRate,
  });

  final double domesticMarketValueBrl;
  final double domesticInvestedBrl;
  final double internationalMarketValueUsd;
  final double internationalInvestedUsd;
  final double? usdBrlRate;

  bool get hasDomestic => domesticMarketValueBrl > 0;
  bool get hasInternational => internationalMarketValueUsd > 0;
  bool get isMixed => hasDomestic && hasInternational;

  double get domesticProfitBrl => domesticMarketValueBrl - domesticInvestedBrl;
  double get internationalProfitUsd => internationalMarketValueUsd - internationalInvestedUsd;

  double get domesticProfitPercent =>
      domesticInvestedBrl <= 0 ? 0 : (domesticProfitBrl / domesticInvestedBrl) * 100;

  double get internationalProfitPercent => internationalInvestedUsd <= 0
      ? 0
      : (internationalProfitUsd / internationalInvestedUsd) * 100;

  double get totalBrl {
    final converted = convertToBrl(
      amount: internationalMarketValueUsd,
      currency: HoldingCurrency.usd,
      usdBrlRate: usdBrlRate,
    );
    return domesticMarketValueBrl + converted;
  }

  double get totalUsd {
    final converted = convertToUsd(
      amount: domesticMarketValueBrl,
      currency: HoldingCurrency.brl,
      usdBrlRate: usdBrlRate,
    );
    return internationalMarketValueUsd + converted;
  }

  double primaryTotal(MarketPreference preference) =>
      preference.isBrazil ? totalBrl : totalUsd;

  double primaryProfitPercent(MarketPreference preference) {
    if (preference.isBrazil) {
      final invested = domesticInvestedBrl +
          convertToBrl(
            amount: internationalInvestedUsd,
            currency: HoldingCurrency.usd,
            usdBrlRate: usdBrlRate,
          );
      final profit = primaryTotal(preference) - invested;
      return invested <= 0 ? 0 : (profit / invested) * 100;
    }

    final invested = internationalInvestedUsd +
        convertToUsd(
          amount: domesticInvestedBrl,
          currency: HoldingCurrency.brl,
          usdBrlRate: usdBrlRate,
        );
    final profit = primaryTotal(preference) - invested;
    return invested <= 0 ? 0 : (profit / invested) * 100;
  }

  double domesticSharePercent(MarketPreference preference) {
    final total = primaryTotal(preference);
    if (total <= 0) return 0;
    final domesticPrimary = preference.isBrazil
        ? domesticMarketValueBrl
        : convertToUsd(
            amount: domesticMarketValueBrl,
            currency: HoldingCurrency.brl,
            usdBrlRate: usdBrlRate,
          );
    return (domesticPrimary / total) * 100;
  }

  double internationalSharePercent(MarketPreference preference) {
    final total = primaryTotal(preference);
    if (total <= 0) return 0;
    final internationalPrimary = preference.isBrazil
        ? convertToBrl(
            amount: internationalMarketValueUsd,
            currency: HoldingCurrency.usd,
            usdBrlRate: usdBrlRate,
          )
        : internationalMarketValueUsd;
    return (internationalPrimary / total) * 100;
  }

  /// Peso do ativo na alocação (moeda de exibição do usuário).
  double allocationWeight(
    PortfolioHolding holding, {
    required MarketPreference preference,
    MarketCategory? category,
  }) {
    if (isInternationalUsdHolding(holding, category: category)) {
      return preference.isBrazil
          ? convertToBrl(
              amount: holding.marketValue,
              currency: HoldingCurrency.usd,
              usdBrlRate: usdBrlRate,
            )
          : holding.marketValue;
    }
    return preference.isBrazil
        ? holding.marketValue
        : convertToUsd(
            amount: holding.marketValue,
            currency: HoldingCurrency.brl,
            usdBrlRate: usdBrlRate,
          );
  }
}

PortfolioBalanceBreakdown computePortfolioBalanceBreakdown({
  required Iterable<PortfolioHolding> holdings,
  required MarketCategory? Function(String symbol) categoryResolver,
  double? usdBrlRate,
}) {
  var domesticMarket = 0.0;
  var domesticInvested = 0.0;
  var internationalMarket = 0.0;
  var internationalInvested = 0.0;

  for (final holding in holdings) {
    final category = categoryResolver(holding.symbol);
    if (isInternationalUsdHolding(holding, category: category)) {
      internationalMarket += holding.marketValue;
      internationalInvested += holding.invested;
    } else {
      domesticMarket += holding.marketValue;
      domesticInvested += holding.invested;
    }
  }

  return PortfolioBalanceBreakdown(
    domesticMarketValueBrl: domesticMarket,
    domesticInvestedBrl: domesticInvested,
    internationalMarketValueUsd: internationalMarket,
    internationalInvestedUsd: internationalInvested,
    usdBrlRate: usdBrlRate,
  );
}

double dividendAmountInCurrency(
  DividendPayment payment, {
  required HoldingCurrency target,
  required double? usdBrlRate,
}) {
  final native = holdingCurrencyForSymbol(payment.symbol);
  if (target == native) return payment.amount;
  if (target == HoldingCurrency.brl) {
    return convertToBrl(amount: payment.amount, currency: native, usdBrlRate: usdBrlRate);
  }
  return convertToUsd(amount: payment.amount, currency: native, usdBrlRate: usdBrlRate);
}
