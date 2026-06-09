import 'package:flutter/material.dart';
import 'package:rico_investidor/features/open_finance/data/open_finance_repository.dart';

class PluggyConnectResult {
  const PluggyConnectResult({required this.itemId});

  final String itemId;
}

/// Placeholder while Pluggy Connect is removed from dependencies.
class PluggyConnectScreen extends StatelessWidget {
  const PluggyConnectScreen({
    super.key,
    required this.connectToken,
    required this.repository,
  });

  final String connectToken;
  final OpenFinanceRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect investments')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.link_off_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 16),
              Text(
                'Investment linking is temporarily unavailable.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'This feature will return in a future update.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
