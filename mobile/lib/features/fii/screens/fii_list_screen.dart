import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/core/config/api_config.dart';
import 'package:rico_investidor/features/fii/data/fii_repository.dart';
import 'package:rico_investidor/features/fii/screens/fii_compare_screen.dart';
import 'package:rico_investidor/features/fii/screens/fii_explore_screen.dart' show FiiExploreScreen, FiiScreenerTile;
import 'package:rico_investidor/features/fii/utils/fii_screener_presets.dart';
import 'package:rico_investidor/models/fii_models.dart';
import 'package:rico_investidor/navigation/open_asset_detail.dart';

class FiiListScreen extends StatefulWidget {
  const FiiListScreen({super.key, required this.repository});

  final FiiRepository repository;

  @override
  State<FiiListScreen> createState() => _FiiListScreenState();
}

class _FiiListScreenState extends State<FiiListScreen> {
  final _searchController = TextEditingController();
  List<FiiScreenerItem> _items = [];
  int _total = 0;
  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final preset = fiiScreenerPresets.firstWhere((p) => p.id == 'all');
      final response = await widget.repository.screener(preset.params);
      if (!mounted) return;
      setState(() {
        _items = response.data;
        _total = response.total;
        _loading = false;
      });
      _applySearch(_query);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _applySearch(String query) {
    _query = query.trim();
    if (_query.isEmpty) return;
    final q = _query.toLowerCase();
    setState(() {
      _items = _items
          .where(
            (f) => f.ticker.toLowerCase().contains(q) || f.name.toLowerCase().contains(q),
          )
          .toList();
    });
  }

  void _onSearchChanged(String value) async {
    if (value.trim().isEmpty) {
      _load();
      return;
    }
    setState(() => _loading = true);
    try {
      final preset = fiiScreenerPresets.firstWhere((p) => p.id == 'all');
      final response = await widget.repository.screener(preset.params);
      final q = value.trim().toLowerCase();
      final filtered = response.data
          .where(
            (f) => f.ticker.toLowerCase().contains(q) || f.name.toLowerCase().contains(q),
          )
          .toList();
      if (!mounted) return;
      setState(() {
        _items = filtered;
        _total = response.total;
        _query = value.trim();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _reload() {
    widget.repository.invalidate();
    _searchController.clear();
    _query = '';
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FIIs'),
        actions: [
          const ShellHomeButton(),
          IconButton(
            tooltip: 'Explorar',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => FiiExploreScreen(repository: widget.repository),
              ),
            ),
            icon: const Icon(Icons.tune),
          ),
          IconButton(
            tooltip: 'Comparar',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => FiiCompareScreen(repository: widget.repository),
              ),
            ),
            icon: const Icon(Icons.compare_arrows),
          ),
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Buscar por ticker ou nome',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              _query.isEmpty
                  ? '$_total FIIs · cotações ao vivo'
                  : '${_items.length} encontrados · "$_query"',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _FiiListError(error: _error!, onRetry: _reload);
    }

    if (_items.isEmpty) {
      return const Center(child: Text('Nenhum FII encontrado.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _items[index];
        return FiiScreenerTile(
          item: item,
          onTap: () => openTickerDetailQuick(context, item.ticker),
        );
      },
    );
  }
}

class _FiiListError extends StatelessWidget {
  const _FiiListError({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 12),
          Text('Erro ao carregar FIIs', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(error, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Confira se a API está rodando em ${ApiConfig.baseUrl}',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Tentar novamente')),
        ],
      ),
    );
  }
}
