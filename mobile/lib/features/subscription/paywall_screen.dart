import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:rico_investidor/features/subscription/revenue_cat_service.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final _service = revenueCatService;

  var _loading = true;
  var _purchasing = false;
  String? _error;
  List<Package> _packages = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final configError = _service.configurationError;
    if (configError != null) {
      setState(() {
        _loading = false;
        _error = configError;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final packages = await _service.fetchOfferings();
      if (!mounted) return;
      setState(() {
        _packages = packages;
        _loading = false;
        if (packages.isEmpty) {
          _error = 'No subscription packages available yet.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load subscription options.';
      });
    }
  }

  Future<void> _purchase(Package package) async {
    setState(() => _purchasing = true);
    try {
      final info = await _service.purchasePackage(package);
      if (!mounted) return;
      if (info?.entitlements.active.containsKey('pro') == true) {
        Navigator.of(context).pop(true);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchase completed')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchase failed or was cancelled')),
      );
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _purchasing = true);
    try {
      final info = await _service.restorePurchases();
      if (!mounted) return;
      if (info?.entitlements.active.containsKey('pro') == true) {
        Navigator.of(context).pop(true);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active subscription found')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not restore purchases')),
      );
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rico Pro'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Upgrade to Rico Pro',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Remove ads, unlock alerts, and expanded portfolios.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                if (_error != null)
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_error!),
                    ),
                  ),
                for (final package in _packages) ...[
                  Card(
                    child: ListTile(
                      title: Text(package.storeProduct.title),
                      subtitle: Text(package.storeProduct.description),
                      trailing: Text(package.storeProduct.priceString),
                      onTap: _purchasing ? null : () => _purchase(package),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _purchasing || _packages.isEmpty ? null : () => _purchase(_packages.first),
                  child: _purchasing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Subscribe'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _purchasing ? null : _restore,
                  child: const Text('Restore purchases'),
                ),
              ],
            ),
    );
  }
}

Future<bool?> openPaywallScreen(BuildContext context) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => const PaywallScreen()),
  );
}
