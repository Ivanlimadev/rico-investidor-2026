import 'package:flutter/material.dart';
import 'package:rico_investidor/features/fii/utils/fii_narrative.dart';
import 'package:rico_investidor/models/fii_models.dart';

class FiiAboutCard extends StatelessWidget {
  const FiiAboutCard({
    super.key,
    required this.detail,
    this.tenants,
  });

  final FiiDetail detail;
  final FiiTenantsResponse? tenants;

  @override
  Widget build(BuildContext context) {
    final narrative = buildFiiNarrative(detail: detail, tenants: tenants);
    final highlights = buildFiiHighlights(detail: detail, tenants: tenants);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(narrative, style: Theme.of(context).textTheme.bodyMedium),
            if (highlights.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: highlights
                    .map(
                      (h) => Chip(
                        label: Text(h),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              bolsaiDataDisclaimer(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
