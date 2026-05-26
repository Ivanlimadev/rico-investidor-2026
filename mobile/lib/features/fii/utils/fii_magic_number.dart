import 'package:rico_investidor/models/fii_models.dart';

class FiiMagicNumberResult {
  const FiiMagicNumberResult({
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

FiiMagicNumberResult? computeMagicNumber({
  required FiiDetail detail,
  FiiDistributions? distributions,
  List<FiiHistoryPoint> history = const [],
}) {
  final price = detail.closePrice;
  if (price == null || price <= 0) return null;

  final monthly = _estimateMonthlyDividend(detail, distributions, history);
  if (monthly == null || monthly <= 0) return null;

  final magic = (price / monthly).ceil();

  return FiiMagicNumberResult(
    magicNumber: magic,
    monthlyDividendPerShare: monthly,
    price: price,
    source: _dividendSource(detail, distributions, history),
  );
}

double? _estimateMonthlyDividend(
  FiiDetail detail,
  FiiDistributions? distributions,
  List<FiiHistoryPoint> history,
) {
  if (distributions != null && distributions.payments.isNotEmpty) {
    final recent = distributions.payments
        .where((p) => p.valuePerShare != null && p.valuePerShare! > 0)
        .toList()
      ..sort((a, b) => (b.referenceDate ?? '').compareTo(a.referenceDate ?? ''));

    if (recent.isNotEmpty) {
      final sample = recent.take(6).map((p) => p.valuePerShare!).toList();
      return sample.reduce((a, b) => a + b) / sample.length;
    }
  }

  if (distributions?.ttmPerShare != null && distributions!.ttmPerShare! > 0) {
    return distributions.ttmPerShare! / 12;
  }

  if (history.isNotEmpty) {
    final values = history
        .where((p) => p.valuePerShare != null && p.valuePerShare! > 0)
        .map((p) => p.valuePerShare!)
        .toList();
    if (values.isNotEmpty) {
      final sample = values.length <= 6 ? values : values.sublist(values.length - 6);
      return sample.reduce((a, b) => a + b) / sample.length;
    }
  }

  if (detail.dividendYieldTtm != null && detail.closePrice != null && detail.dividendYieldTtm! > 0) {
    final annualPerShare = detail.closePrice! * (detail.dividendYieldTtm! / 100);
    return annualPerShare / 12;
  }

  return null;
}

String? _dividendSource(
  FiiDetail detail,
  FiiDistributions? distributions,
  List<FiiHistoryPoint> history,
) {
  if (distributions != null && distributions.payments.isNotEmpty) {
    return 'média dos últimos pagamentos';
  }
  if (distributions?.ttmPerShare != null) return 'provento 12m ÷ 12';
  if (history.any((p) => p.valuePerShare != null)) return 'histórico mensal';
  if (detail.dividendYieldTtm != null) return 'DY 12m estimado';
  return null;
}
