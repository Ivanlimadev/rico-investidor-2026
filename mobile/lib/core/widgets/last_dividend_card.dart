import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/features/fii/utils/fii_payments.dart';
import 'package:rico_investidor/features/global_markets/models/global_market_models.dart';
import 'package:rico_investidor/features/global_markets/utils/global_stock_dividend_utils.dart';
import 'package:rico_investidor/features/quotes/utils/stock_payments.dart';
import 'package:rico_investidor/models/fii_models.dart';

enum LastDividendCurrency { brl, usd }

enum LastDividendDateStyle { stock, fii }

/// Card destacando o último provento/dividendo pago (estilo Investidor10).
class LastDividendCard extends StatelessWidget {
  const LastDividendCard({
    super.key,
    required this.payments,
    this.currency = LastDividendCurrency.brl,
    this.dateStyle = LastDividendDateStyle.stock,
    this.dividendYield12m,
    this.perShareLabel = 'ação',
  }) : _globalDividends = null;

  const LastDividendCard.global({
    super.key,
    required List<GlobalStockDividendDto> dividends,
    this.dividendYield12m,
  })  : payments = const [],
        currency = LastDividendCurrency.usd,
        dateStyle = LastDividendDateStyle.stock,
        perShareLabel = 'ação',
        _globalDividends = dividends;

  final List<FiiDistributionPayment> payments;
  final LastDividendCurrency currency;
  final LastDividendDateStyle dateStyle;
  final double? dividendYield12m;
  final String perShareLabel;
  final List<GlobalStockDividendDto>? _globalDividends;

  @override
  Widget build(BuildContext context) {
    final globalDividends = _globalDividends;
    final info = globalDividends != null
        ? _infoFromGlobal(globalDividends)
        : _infoFromPayments(payments, dateStyle);
    if (info == null) return const SizedBox.shrink();

    final money = currency == LastDividendCurrency.usd ? formatUsd : formatBrl;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.positive.withValues(alpha: 0.14),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.payments_outlined, color: AppColors.positive, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Último dividendo',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                if (dividendYield12m != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.positive.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.positive.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      'DY 12m ${dividendYield12m!.toStringAsFixed(2)}%',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.positive,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  money(info.amount),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.positive,
                      ),
                ),
                const SizedBox(width: 8),
                Text(
                  '/ $perShareLabel',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                ),
                if (info.typeLabel.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(
                    '· ${info.typeLabel}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                        ),
                  ),
                ],
              ],
            ),
            if (info.referenceMonth != null) ...[
              const SizedBox(height: 4),
              Text(
                'Referência ${info.referenceMonth}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
              ),
            ],
            const SizedBox(height: 14),
            _DateRow(label: 'Data COM', value: info.comDate),
            _DateRow(
              label: 'Pagamento',
              value: info.paymentDate,
              muted: info.paymentDate == '—',
            ),
          ],
        ),
      ),
    );
  }
}

class _LastDividendInfo {
  const _LastDividendInfo({
    required this.amount,
    required this.typeLabel,
    required this.comDate,
    required this.paymentDate,
    this.referenceMonth,
  });

  final double amount;
  final String typeLabel;
  final String comDate;
  final String paymentDate;
  final String? referenceMonth;
}

_LastDividendInfo? _infoFromPayments(
  List<FiiDistributionPayment> payments,
  LastDividendDateStyle style,
) {
  final payment = lastPaidPayment(payments);
  if (payment == null) return null;

  final amount = payment.valuePerShare!;
  final typeLabel = style == LastDividendDateStyle.fii
      ? paymentDisplayType(payment)
      : stockPaymentDisplayType(payment);
  final comDate =
      style == LastDividendDateStyle.fii ? paymentComDate(payment) : stockPaymentComDate(payment);
  final payInfo = style == LastDividendDateStyle.fii
      ? paymentDateInfo(payment)
      : stockPaymentDateInfo(payment);

  return _LastDividendInfo(
    amount: amount,
    typeLabel: typeLabel,
    comDate: comDate,
    paymentDate: payInfo.label,
    referenceMonth: style == LastDividendDateStyle.fii
        ? formatReferenceMonth(payment.referenceDate)
        : null,
  );
}

_LastDividendInfo? _infoFromGlobal(List<GlobalStockDividendDto> dividends) {
  final sorted = sortGlobalDividendsNewestFirst(dividends);
  GlobalStockDividendDto? last;
  for (final item in sorted) {
    if (!item.isProjected && item.amount > 0) {
      last = item;
      break;
    }
  }
  if (last == null) return null;

  return _LastDividendInfo(
    amount: last.amount,
    typeLabel: globalDividendTypeLabel(last),
    comDate: formatGlobalDividendDate(last.effectiveComDate),
    paymentDate: formatGlobalDividendDate(last.effectivePaymentDate),
  );
}

FiiDistributionPayment? lastPaidPayment(List<FiiDistributionPayment> payments) {
  for (final payment in sortPaymentsNewestFirst(payments)) {
    final value = payment.valuePerShare;
    if (value != null && value > 0) return payment;
  }
  return null;
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    this.muted = false,
  });

  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: onSurface.withValues(alpha: 0.7),
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: muted ? onSurface.withValues(alpha: 0.45) : null,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
