import 'package:flutter_test/flutter_test.dart';
import 'package:rico_investidor/core/utils/annual_dividend_summary.dart';
import 'package:rico_investidor/models/market_series_models.dart';

void main() {
  test('buildAnnualDividendSummaryFromPayments sums by payment year', () {
    final payments = [
      DistributionPayment(
        referenceDate: '2024-03-10',
        paymentDate: '2024-03-25',
        valuePerShare: 1.0,
      ),
      DistributionPayment(
        referenceDate: '2024-06-10',
        paymentDate: '2024-06-25',
        valuePerShare: 0.5,
      ),
      DistributionPayment(
        referenceDate: '2023-12-01',
        paymentDate: '2023-12-15',
        valuePerShare: 0.25,
      ),
    ];

    final summary = buildAnnualDividendSummaryFromPayments(payments)
      ..sort((a, b) => b.year.compareTo(a.year));

    expect(summary.length, 2);
    expect(summary[0].year, 2024);
    expect(summary[0].totalPerShare, closeTo(1.5, 0.0001));
    expect(summary[0].payments, 2);
    expect(summary[1].year, 2023);
    expect(summary[1].totalPerShare, closeTo(0.25, 0.0001));
  });

  test('resolveAnnualDividendSummary prefers payments over API summary', () {
    final payments = [
      DistributionPayment(
        referenceDate: '2025-01-01',
        paymentDate: '2025-01-15',
        valuePerShare: 2,
      ),
    ];
    const apiSummary = [
      DistributionYear(year: 2025, totalPerShare: 99, payments: 1),
    ];

    final resolved = resolveAnnualDividendSummary(
      annualSummary: apiSummary,
      payments: payments,
    );

    expect(resolved.single.totalPerShare, closeTo(2, 0.0001));
  });
}
