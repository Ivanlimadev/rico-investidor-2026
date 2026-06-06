import 'package:rico_investidor/features/global_markets/models/global_market_models.dart';
import 'package:rico_investidor/features/quotes/models/stock_quote_detail.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/models/fii_models.dart';
import 'package:rico_investidor/models/market_category.dart';

class AssetMagicNumberResult {
  const AssetMagicNumberResult({
    required this.magicNumber,
    required this.monthlyDividendPerShare,
    required this.price,
    this.source,
  });

  final int magicNumber;
  final double monthlyDividendPerShare;
  final double price;
  final String? source;
}

AssetMagicNumberResult? computeAssetMagicNumber({
  required double price,
  List<FiiDistributionPayment> payments = const [],
  double? ttmPerShare,
  List<double> historyMonthlyValues = const [],
  double? dividendYieldPercent,
}) {
  if (price <= 0) return null;

  final monthly = _estimateMonthlyDividend(
    payments: payments,
    ttmPerShare: ttmPerShare,
    historyMonthlyValues: historyMonthlyValues,
    price: price,
    dividendYieldPercent: dividendYieldPercent,
  );
  if (monthly == null || monthly <= 0) return null;

  return AssetMagicNumberResult(
    magicNumber: (price / monthly).ceil(),
    monthlyDividendPerShare: monthly,
    price: price,
    source: _dividendSource(
      payments: payments,
      ttmPerShare: ttmPerShare,
      historyMonthlyValues: historyMonthlyValues,
      dividendYieldPercent: dividendYieldPercent,
    ),
  );
}

AssetMagicNumberResult? magicNumberFromFii({
  required FiiDetail detail,
  FiiDistributions? distributions,
  List<FiiHistoryPoint> history = const [],
}) {
  final price = detail.closePrice;
  if (price == null || price <= 0) return null;

  final historyValues = history
      .where((p) => p.valuePerShare != null && p.valuePerShare! > 0)
      .map((p) => p.valuePerShare!)
      .toList();

  return computeAssetMagicNumber(
    price: price,
    payments: distributions?.payments ?? const [],
    ttmPerShare: distributions?.ttmPerShare,
    historyMonthlyValues: historyValues,
    dividendYieldPercent: detail.dividendYieldTtm,
  );
}

AssetMagicNumberResult? magicNumberFromStock({
  required double price,
  required StockDividendsDto dividends,
  double? dividendYieldPercent,
}) {
  return computeAssetMagicNumber(
    price: price,
    payments: dividends.payments,
    ttmPerShare: dividends.ttmPerShare,
    dividendYieldPercent: dividendYieldPercent ?? dividends.displayDividendYield,
  );
}

AssetMagicNumberResult? magicNumberFromGlobalStock({
  required double price,
  required List<GlobalStockDividendDto> dividends,
  GlobalStockDividendsSummaryDto? summary,
  double? dividendYieldPercent,
}) {
  final payments = dividends
      .where((item) => !item.isProjected && item.amount > 0)
      .map(
        (item) => FiiDistributionPayment(
          referenceDate: item.effectiveComDate ?? item.effectiveExDate,
          paymentDate: item.effectivePaymentDate ?? item.effectiveExDate,
          valuePerShare: item.amount,
          label: item.dividendType,
        ),
      )
      .toList();

  return computeAssetMagicNumber(
    price: price,
    payments: payments,
    ttmPerShare: summary?.ttmPerShare,
    dividendYieldPercent: dividendYieldPercent ?? summary?.dividendYieldTtm,
  );
}

AssetMagicNumberResult? magicNumberFromAssetItem(AssetItem asset) {
  if (asset.price <= 0) return null;
  return computeAssetMagicNumber(
    price: asset.price,
    dividendYieldPercent: asset.dividendYield12m,
  );
}

String magicNumberUnitLabel(MarketCategory category) {
  return category == MarketCategory.fiis ? 'cota' : 'ação';
}

String magicNumberUnitPlural(MarketCategory category) {
  return category == MarketCategory.fiis ? 'cotas' : 'ações';
}

double? _estimateMonthlyDividend({
  required List<FiiDistributionPayment> payments,
  required double? ttmPerShare,
  required List<double> historyMonthlyValues,
  required double price,
  required double? dividendYieldPercent,
}) {
  if (payments.isNotEmpty) {
    final recent = payments
        .where((p) => p.valuePerShare != null && p.valuePerShare! > 0)
        .toList()
      ..sort((a, b) => (b.referenceDate ?? '').compareTo(a.referenceDate ?? ''));

    if (recent.isNotEmpty) {
      final sample = recent.take(6).map((p) => p.valuePerShare!).toList();
      return sample.reduce((a, b) => a + b) / sample.length;
    }
  }

  if (ttmPerShare != null && ttmPerShare > 0) {
    return ttmPerShare / 12;
  }

  if (historyMonthlyValues.isNotEmpty) {
    final sample = historyMonthlyValues.length <= 6
        ? historyMonthlyValues
        : historyMonthlyValues.sublist(historyMonthlyValues.length - 6);
    return sample.reduce((a, b) => a + b) / sample.length;
  }

  if (dividendYieldPercent != null && dividendYieldPercent > 0) {
    return price * (dividendYieldPercent / 100) / 12;
  }

  return null;
}

String? _dividendSource({
  required List<FiiDistributionPayment> payments,
  required double? ttmPerShare,
  required List<double> historyMonthlyValues,
  required double? dividendYieldPercent,
}) {
  if (payments.isNotEmpty) return 'média dos últimos pagamentos';
  if (ttmPerShare != null) return 'provento 12m ÷ 12';
  if (historyMonthlyValues.isNotEmpty) return 'histórico mensal';
  if (dividendYieldPercent != null) return 'DY 12m estimado';
  return null;
}
