import 'package:flutter/material.dart';
import 'package:rico_investidor/features/global_markets/models/global_market_models.dart';

class GlobalStockAboutCard extends StatelessWidget {
  const GlobalStockAboutCard({super.key, required this.company});

  final GlobalStockCompanyProfileDto company;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (company.sector != null && company.sector!.isNotEmpty)
        Chip(label: Text(company.sector!), visualDensity: VisualDensity.compact),
      if (company.industry != null && company.industry!.isNotEmpty)
        Chip(label: Text(company.industry!), visualDensity: VisualDensity.compact),
      if (company.country != null && company.country!.isNotEmpty)
        Chip(label: Text(company.country!), visualDensity: VisualDensity.compact),
      if (company.exchangeName != null && company.exchangeName!.isNotEmpty)
        Chip(label: Text(company.exchangeName!), visualDensity: VisualDensity.compact),
      if (company.exchangeMic != null && company.exchangeMic!.isNotEmpty)
        Chip(label: Text(company.exchangeMic!), visualDensity: VisualDensity.compact),
      if (company.isin != null && company.isin!.isNotEmpty)
        Chip(label: Text('ISIN ${company.isin}'), visualDensity: VisualDensity.compact),
      if (company.cusip != null && company.cusip!.isNotEmpty)
        Chip(label: Text('CUSIP ${company.cusip}'), visualDensity: VisualDensity.compact),
    ];

    if (chips.isEmpty &&
        (company.exchangeWebsite ?? '').isEmpty &&
        (company.website ?? '').isEmpty &&
        (company.summary ?? '').isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Sobre a empresa', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(
              company.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (company.exchangeCity != null && company.exchangeCity!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                company.exchangeCity!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (company.summary != null && company.summary!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                company.summary!,
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (chips.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: chips),
            ],
            if ((company.website ?? company.exchangeWebsite)?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                company.website ?? company.exchangeWebsite!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
