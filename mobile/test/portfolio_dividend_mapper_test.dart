import 'package:flutter_test/flutter_test.dart';
import 'package:rico_investidor/features/portfolio/utils/portfolio_dividend_mapper.dart';
import 'package:rico_investidor/features/quotes/models/stock_quote_detail.dart';
import 'package:rico_investidor/models/market_series_models.dart';
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
      const DistributionPayment(
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
    expect(mapped.first.quantity, 100);
  });

  test('maps upcoming event in current month with com and payment dates', () {
    const holding = PortfolioHolding(
      id: 'h-1',
      symbol: 'ITUB4',
      name: 'Itaú',
      quantity: 50,
      averagePrice: 30,
      currentPrice: 32,
    );

    final now = DateTime.now();
    final mapped = mapUpcomingEventsToPortfolio(
      holding: holding,
      events: [
        StockDividendEventDto(
          label: 'JCP',
          comDate: '${now.year}-${now.month.toString().padLeft(2, '0')}-12',
          paymentDate: '${now.year}-${now.month.toString().padLeft(2, '0')}-28',
          valuePerShare: 0.5,
          isProjected: true,
        ),
      ],
      month: now,
    );

    expect(mapped, hasLength(1));
    expect(mapped.first.amount, 25);
    expect(mapped.first.comDate, isNotNull);
    expect(mapped.first.isProjected, isTrue);
  });
}
