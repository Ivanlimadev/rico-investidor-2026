import 'package:rico_investidor/features/fii/utils/fii_format.dart';
import 'package:rico_investidor/models/fii_models.dart';

class FiiFundCostLine {
  const FiiFundCostLine({
    required this.title,
    required this.perShareLabel,
    required this.totalFundLabel,
    required this.example100Label,
  });

  final String title;
  final String perShareLabel;
  final String totalFundLabel;
  final String example100Label;
}

class FiiFundCostsSummary {
  const FiiFundCostsSummary({required this.lines});

  final List<FiiFundCostLine> lines;
}

FiiFundCostsSummary? buildFiiFundCostsSummary(FiiDetail detail) {
  final fees = detail.feesPaidLastMonth;
  if (fees == null) return null;

  final shares = detail.sharesOutstanding;
  final lines = <FiiFundCostLine>[];

  void addLine({
    required String title,
    required double? amount,
  }) {
    if (amount == null || amount <= 0) return;

    if (shares != null && shares > 0) {
      final perShare = amount / shares;
      lines.add(
        FiiFundCostLine(
          title: title,
          perShareLabel: formatPerShareBrl(perShare),
          totalFundLabel: formatCompactFundTotal(amount),
          example100Label: formatBrl(perShare * 100),
        ),
      );
      return;
    }

    lines.add(
      FiiFundCostLine(
        title: title,
        perShareLabel: '—',
        totalFundLabel: formatCompactFundTotal(amount),
        example100Label: '—',
      ),
    );
  }

  addLine(title: 'Administração', amount: fees.admin);
  addLine(title: 'Performance', amount: fees.performance);

  if (lines.isEmpty) return null;
  return FiiFundCostsSummary(lines: lines);
}

String formatPerShareBrl(double value) {
  final abs = value.abs();
  final sign = value < 0 ? '-' : '';

  if (abs >= 0.01) return '$sign${formatBrl(abs)}';
  if (abs == 0) return formatBrl(0);
  if (abs < 0.0001) return '$sign< R\$ 0,0001';

  final fixed = abs.toStringAsFixed(4);
  final parts = fixed.split('.');
  final decimals = parts[1].replaceAll(RegExp(r'0+$'), '');
  final padded = decimals.padRight(2, '0');
  return '${sign}R\$ ${parts[0]},$padded';
}

String formatCompactFundTotal(double value) => formatCompactBrl(value);
