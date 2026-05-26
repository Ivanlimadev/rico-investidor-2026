import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/core/utils/currency_format.dart';
import 'package:rico_investidor/features/fii/utils/fii_payments.dart';
import 'package:rico_investidor/models/fii_models.dart';

class FiiRecentDividendsCard extends StatefulWidget {
  const FiiRecentDividendsCard({super.key, required this.payments});

  final List<FiiDistributionPayment> payments;

  @override
  State<FiiRecentDividendsCard> createState() => _FiiRecentDividendsCardState();
}

class _FiiRecentDividendsCardState extends State<FiiRecentDividendsCard> {
  static const _pageSize = 5;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final sorted = sortPaymentsNewestFirst(widget.payments);
    if (sorted.isEmpty) return const SizedBox.shrink();

    final maxPage = ((sorted.length - 1) / _pageSize).floor();
    final page = _page.clamp(0, maxPage);
    final start = page * _pageSize;
    final end = (start + _pageSize).clamp(0, sorted.length);
    final pageItems = sorted.sublist(start, end);
    final hasNext = end < sorted.length;
    final hasPrevious = page > 0;
    final hasEstimatedDates = pageItems.any((p) => paymentDateInfo(p).isEstimated);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Proventos recentes', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _TableHeader(hasEstimated: hasEstimatedDates),
            const Divider(height: 1),
            for (var i = 0; i < pageItems.length; i++) ...[
              _PaymentRow(payment: pageItems[i]),
              if (i < pageItems.length - 1) const Divider(height: 1),
            ],
            if (hasNext || hasPrevious) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (hasPrevious)
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () => setState(() => _page = (page - 1).clamp(0, maxPage)),
                      child: const Text('Anterior'),
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: Text(
                      '${start + 1}–$end de ${sorted.length}',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (hasNext)
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () => setState(() => _page = (page + 1).clamp(0, maxPage)),
                      child: const Text('Próximo'),
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.hasEstimated});

  final bool hasEstimated;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          fontWeight: FontWeight.w600,
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(flex: 22, child: Text('Tipo', style: style)),
          Expanded(flex: 26, child: Text('Data COM', style: style)),
          Expanded(flex: 28, child: Text(hasEstimated ? 'Pagamento ~' : 'Pagamento', style: style)),
          Expanded(
            flex: 24,
            child: Text('Valor', style: style, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment});

  final FiiDistributionPayment payment;

  @override
  Widget build(BuildContext context) {
    final type = paymentDisplayType(payment);
    final comDate = paymentComDate(payment);
    final payInfo = paymentDateInfo(payment);
    final value = payment.valuePerShare;

    final cellStyle = Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600);
    final valueStyle = cellStyle?.copyWith(color: AppColors.positive);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 22,
            child: Text(type, style: cellStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: 26,
            child: Text(comDate, style: cellStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: 28,
            child: Text(payInfo.label, style: cellStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: 24,
            child: Text(
              value != null ? formatBrl(value) : '—',
              style: valueStyle,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
