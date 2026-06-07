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

  /// Patrimônio total exibido no topo — tudo em dólares (mercado EUA).
  HoldingCurrency get displayCurrency => HoldingCurrency.usd;

  double get displayTotal => totalUsd;

  double get totalInvestedBrl =>
      domesticInvestedBrl +
      convertToBrl(
        amount: internationalInvestedUsd,
        currency: HoldingCurrency.usd,
        usdBrlRate: usdBrlRate,
      );

  double get totalInvestedUsd =>
      internationalInvestedUsd +
      convertToUsd(
        amount: domesticInvestedBrl,
        currency: HoldingCurrency.brl,
        usdBrlRate: usdBrlRate,
      );

  double get combinedProfitBrl => totalBrl - totalInvestedBrl;

  double get combinedProfitUsd => totalUsd - totalInvestedUsd;

  double get combinedProfitPercent {
    if (totalInvestedUsd <= 0) return 0;
    return (combinedProfitUsd / totalInvestedUsd) * 100;
  }

  double get displayProfitPercent => combinedProfitPercent;

  /// % do patrimônio total (em R$) no bucket Brasil/B3.
  double get domesticShareOfTotal {
    final total = totalBrl;
    if (total <= 0) return 0;
    return (domesticMarketValueBrl / total) * 100;
  }

  /// % do patrimônio total (em R$) no bucket internacional.
  double get internationalShareOfTotal {
    final total = totalBrl;
    if (total <= 0) return 0;
    final intlBrl = convertToBrl(
      amount: internationalMarketValueUsd,
      currency: HoldingCurrency.usd,
      usdBrlRate: usdBrlRate,
    );
    return (intlBrl / total) * 100;
  }

  /// Total na moeda da preferência (só alocação / pesos relativos).
  double primaryTotal(MarketPreference preference) => preference.isBrazil
      ? domesticMarketValueBrl
      : internationalMarketValueUsd;

  double primaryInvested(MarketPreference preference) => preference.isBrazil
      ? domesticInvestedBrl
      : internationalInvestedUsd;

  double primaryProfit(MarketPreference preference) => preference.isBrazil
      ? domesticProfitBrl
      : internationalProfitUsd;

  double primaryProfitPercent(MarketPreference preference) {
    final invested = primaryInvested(preference);
    if (invested <= 0) return 0;
    return (primaryProfit(preference) / invested) * 100;
  }

  /// Soma dos pesos de alocação na moeda da preferência (denominador do gráfico).
  double allocationTotal(
    Iterable<PortfolioHolding> holdings, {
    required MarketPreference preference,
    required MarketCategory? Function(PortfolioHolding holding) categoryResolver,
  }) {
    var total = 0.0;
    for (final holding in holdings) {
      total += allocationWeight(
        holding,
        preference: preference,
        category: categoryResolver(holding),
      );
    }
    return total;
  }

  /// Base para % da carteira nos sub-informativos (ambos os baldes).
  double combinedTotalBrl() {
    return domesticMarketValueBrl +
        convertToBrl(
          amount: internationalMarketValueUsd,
          currency: HoldingCurrency.usd,
          usdBrlRate: usdBrlRate,
        );
  }

  double combinedTotalUsd() {
    return internationalMarketValueUsd +
        convertToUsd(
          amount: domesticMarketValueBrl,
          currency: HoldingCurrency.brl,
          usdBrlRate: usdBrlRate,
        );
  }

  double domesticSharePercent(MarketPreference preference) {
    final total = preference.isBrazil ? combinedTotalBrl() : combinedTotalUsd();
    if (total <= 0) return 0;
    final domesticWeight = preference.isBrazil
        ? domesticMarketValueBrl
        : convertToUsd(
            amount: domesticMarketValueBrl,
            currency: HoldingCurrency.brl,
            usdBrlRate: usdBrlRate,
          );
    return (domesticWeight / total) * 100;
  }

  double internationalSharePercent(MarketPreference preference) {
    final total = preference.isBrazil ? combinedTotalBrl() : combinedTotalUsd();
    if (total <= 0) return 0;
    final internationalWeight = preference.isBrazil
        ? convertToBrl(
            amount: internationalMarketValueUsd,
            currency: HoldingCurrency.usd,
            usdBrlRate: usdBrlRate,
          )
        : internationalMarketValueUsd;
    return (internationalWeight / total) * 100;
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
  required MarketCategory? Function(PortfolioHolding holding) categoryResolver,
  double? usdBrlRate,
}) {
  var domesticMarket = 0.0;
  var domesticInvested = 0.0;
  var internationalMarket = 0.0;
  var internationalInvested = 0.0;

  for (final holding in holdings) {
    final category = categoryResolver(holding);
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
