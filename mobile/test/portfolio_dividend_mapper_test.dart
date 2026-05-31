import 'package:flutter_test/flutter_test.dart';
import 'package:rico_investidor/features/portfolio/utils/portfolio_dividend_mapper.dart';
import 'package:rico_investidor/models/fii_models.dart';
import 'package:rico_investidor/models/portfolio_holding.dart';

void main() {
  test('maps API payment to portfolio total using quantity', () {
    const holding = PortfolioHolding(
      id: 'h-1',
      symbol: 'PETR4',
      name: 'Petrobras',
      quantity: 100,
      averagePrice: 30,
      currentPrice: 38,
    );

    final payments = [
      const FiiDistributionPayment(
        paymentDate: '2025-05-10',
        valuePerShare: 1.25,
        label: 'Dividendo',
      ),
    ];

    final cutoff = DateTime(2024, 1, 1);
    final mapped = mapDistributionPaymentsToPortfolio(
      holding: holding,
      payments: payments,
      cutoff: cutoff,
    );

    expect(mapped, hasLength(1));
    expect(mapped.first.amount, 125);
    expect(mapped.first.symbol, 'PETR4');
    expect(mapped.first.kind, 'Dividendo');
  });
}
