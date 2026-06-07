import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/widgets/asset_logo.dart';
import 'package:rico_investidor/features/portfolio/utils/portfolio_dividend_mapper.dart';
import 'package:rico_investidor/models/dividend_payment.dart';
import 'package:rico_investidor/models/holding_currency.dart';

/// Card compacto — ticker, data e valor centralizado.
class DividendCompactCard extends StatelessWidget {
  const DividendCompactCard({
    super.key,
    required this.payment,
    this.onTap,
  });

  final DividendPayment payment;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final date = formatDividendDay(payment.date);
    final amountLabel = holdingCurrencyForSymbol(payment.symbol).format(payment.amount);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AssetLogo(
                symbol: payment.symbol,
                size: 24,
                borderRadius: 7,
              ),
              const SizedBox(height: 5),
              Text(
                payment.symbol,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                    ),
              ),
              const Spacer(),
              Text(
                date,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62),
                      fontSize: 9.5,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                amountLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                      color: AppColors.positive,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
