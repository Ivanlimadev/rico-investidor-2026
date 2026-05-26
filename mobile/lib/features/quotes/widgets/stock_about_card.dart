import 'package:flutter/material.dart';
import 'package:rico_investidor/features/quotes/models/stock_quote_detail.dart';

class StockAboutCard extends StatefulWidget {
  const StockAboutCard({super.key, required this.profile});

  final StockProfileDto profile;

  @override
  State<StockAboutCard> createState() => _StockAboutCardState();
}

class _StockAboutCardState extends State<StockAboutCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    if ((profile.summary ?? '').isEmpty &&
        profile.sector == null &&
        profile.industry == null) {
      return const SizedBox.shrink();
    }

    final summary = profile.summary ?? '';
    final showToggle = summary.length > 220;
    final visibleSummary = !_expanded && showToggle ? '${summary.substring(0, 220)}…' : summary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Sobre a empresa', style: Theme.of(context).textTheme.titleSmall),
            if (profile.sector != null || profile.industry != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (profile.sector != null)
                    Chip(
                      label: Text(profile.sector!),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (profile.industry != null)
                    Chip(
                      label: Text(profile.industry!),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (profile.employees != null)
                    Chip(
                      label: Text('${profile.employees} colaboradores'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
            if (summary.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(visibleSummary, style: Theme.of(context).textTheme.bodyMedium),
              if (showToggle)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    child: Text(_expanded ? 'Ver menos' : 'Ver mais'),
                  ),
                ),
            ],
            if (profile.website != null && profile.website!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                profile.website!,
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
