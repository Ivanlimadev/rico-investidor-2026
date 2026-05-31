import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/models/asset_item.dart';
import 'package:rico_investidor/navigation/open_asset_actions.dart';
import 'package:rico_investidor/services/favorites_storage.dart';

/// Menu padrão de ativo: buscar, favoritar e adicionar à carteira.
class AssetQuickActions extends StatelessWidget {
  const AssetQuickActions({
    super.key,
    required this.asset,
    this.compact = false,
    this.showSearch = true,
    this.showFavorite = true,
    this.showPortfolio = true,
  });

  final AssetItem asset;
  final bool compact;
  final bool showSearch;
  final bool showFavorite;
  final bool showPortfolio;

  /// Botões para a AppBar — ao lado do botão Início (ordem: buscar, favorito, carteira+).
  static List<Widget> appBarActions(
    BuildContext context,
    AssetItem asset, {
    bool showSearch = true,
    bool showFavorite = true,
    bool showPortfolio = true,
  }) {
    final actions = <Widget>[];
    if (showSearch) {
      actions.add(
        IconButton(
          tooltip: 'Buscar',
          onPressed: () => openAssetSearch(context, asset),
          icon: const Icon(Icons.search_rounded),
        ),
      );
    }
    if (showFavorite) {
      actions.add(_FavoriteAppBarButton(asset: asset));
    }
    if (showPortfolio) {
      actions.add(
        IconButton(
          tooltip: 'Adicionar à carteira',
          onPressed: () => openAddAssetToPortfolio(context, asset),
          icon: const WalletAddIcon(),
        ),
      );
    }
    return actions;
  }

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[
      if (showSearch)
        _ActionIconButton(
          tooltip: 'Buscar',
          icon: Icons.search_rounded,
          compact: compact,
          onPressed: () => openAssetSearch(context, asset),
        ),
      if (showFavorite)
        _FavoriteActionButton(asset: asset, compact: compact),
      if (showPortfolio)
        _ActionIconButton(
          tooltip: 'Adicionar à carteira',
          iconWidget: WalletAddIcon(size: compact ? 17 : 20),
          compact: compact,
          accent: true,
          onPressed: () => openAddAssetToPortfolio(context, asset),
        ),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) SizedBox(width: compact ? 4 : 6),
          buttons[i],
        ],
      ],
    );
  }
}

/// Carteira com + (adicionar à carteira).
class WalletAddIcon extends StatelessWidget {
  const WalletAddIcon({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    final plusSize = size * 0.52;
    return SizedBox(
      width: size + 2,
      height: size + 2,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(Icons.account_balance_wallet_outlined, size: size),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              padding: const EdgeInsets.all(0.5),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_rounded,
                size: plusSize,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoriteAppBarButton extends StatefulWidget {
  const _FavoriteAppBarButton({required this.asset});

  final AssetItem asset;

  @override
  State<_FavoriteAppBarButton> createState() => _FavoriteAppBarButtonState();
}

class _FavoriteAppBarButtonState extends State<_FavoriteAppBarButton> {
  bool _isFavorite = false;
  bool _loading = true;
  StreamSubscription<void>? _subscription;

  @override
  void initState() {
    super.initState();
    _load();
    _subscription = favoritesStorage.changes.listen((_) => _load());
  }

  @override
  void didUpdateWidget(covariant _FavoriteAppBarButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.symbol != widget.asset.symbol) _load();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final isFavorite = await favoritesStorage.isFavorite(widget.asset.symbol);
    if (!mounted) return;
    setState(() {
      _isFavorite = isFavorite;
      _loading = false;
    });
  }

  Future<void> _toggle() async {
    setState(() => _loading = true);
    await favoritesStorage.toggle(widget.asset);
    if (!mounted) return;
    final isFavorite = await favoritesStorage.isFavorite(widget.asset.symbol);
    if (!mounted) return;
    setState(() {
      _isFavorite = isFavorite;
      _loading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isFavorite
              ? '${widget.asset.symbol} adicionado aos favoritos'
              : '${widget.asset.symbol} removido dos favoritos',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return IconButton(
        onPressed: null,
        icon: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    return IconButton(
      tooltip: _isFavorite ? 'Remover dos favoritos' : 'Favoritar',
      onPressed: _toggle,
      icon: Icon(
        _isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
        color: _isFavorite ? AppColors.accent : null,
      ),
    );
  }
}

class _FavoriteActionButton extends StatefulWidget {
  const _FavoriteActionButton({required this.asset, required this.compact});

  final AssetItem asset;
  final bool compact;

  @override
  State<_FavoriteActionButton> createState() => _FavoriteActionButtonState();
}

class _FavoriteActionButtonState extends State<_FavoriteActionButton> {
  bool _isFavorite = false;
  bool _loading = true;
  StreamSubscription<void>? _subscription;

  @override
  void initState() {
    super.initState();
    _load();
    _subscription = favoritesStorage.changes.listen((_) => _load());
  }

  @override
  void didUpdateWidget(covariant _FavoriteActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.symbol != widget.asset.symbol) _load();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final isFavorite = await favoritesStorage.isFavorite(widget.asset.symbol);
    if (!mounted) return;
    setState(() {
      _isFavorite = isFavorite;
      _loading = false;
    });
  }

  Future<void> _toggle() async {
    setState(() => _loading = true);
    await favoritesStorage.toggle(widget.asset);
    if (!mounted) return;
    final isFavorite = await favoritesStorage.isFavorite(widget.asset.symbol);
    if (!mounted) return;
    setState(() {
      _isFavorite = isFavorite;
      _loading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isFavorite
              ? '${widget.asset.symbol} adicionado aos favoritos'
              : '${widget.asset.symbol} removido dos favoritos',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _ActionIconButton(
      tooltip: _isFavorite ? 'Remover dos favoritos' : 'Favoritar',
      icon: _isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
      compact: widget.compact,
      accent: _isFavorite,
      loading: _loading,
      onPressed: _loading ? null : _toggle,
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  const _ActionIconButton({
    required this.tooltip,
    this.icon,
    this.iconWidget,
    required this.compact,
    required this.onPressed,
    this.accent = false,
    this.loading = false,
  }) : assert(icon != null || iconWidget != null);

  final String tooltip;
  final IconData? icon;
  final Widget? iconWidget;
  final bool compact;
  final VoidCallback? onPressed;
  final bool accent;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 30.0 : 36.0;
    final iconSize = compact ? 17.0 : 20.0;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(compact ? 9 : 11),
          child: Ink(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(compact ? 9 : 11),
              color: accent
                  ? AppColors.accent.withValues(alpha: 0.2)
                  : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
              border: Border.all(
                color: accent
                    ? AppColors.accent.withValues(alpha: 0.6)
                    : Theme.of(context).colorScheme.outline.withValues(alpha: 0.22),
              ),
            ),
            child: loading
                ? Padding(
                    padding: EdgeInsets.all(size * 0.26),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accent ? AppColors.accent : AppColors.primary,
                    ),
                  )
                : Center(
                    child: iconWidget ??
                        Icon(
                          icon,
                          size: iconSize,
                          color: accent ? AppColors.accent : null,
                        ),
                  ),
          ),
        ),
      ),
    );
  }
}
