import 'package:flutter/material.dart';

class AppBottomNavItem {
  const AppBottomNavItem({
    required this.label,
    this.icon,
    this.selectedIcon,
    this.iconBuilder,
  }) : assert(
          icon != null || iconBuilder != null,
          'Informe icon ou iconBuilder',
        );

  final String label;
  final IconData? icon;
  final IconData? selectedIcon;
  final Widget Function(bool selected, Color color)? iconBuilder;
}

class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AppBottomNavItem> destinations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      color: colorScheme.surface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: List.generate(destinations.length, (index) {
              final item = destinations[index];
              final selected = index == selectedIndex;
              final color = selected
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha: 0.55);

              return Expanded(
                child: Semantics(
                  label: item.label,
                  selected: selected,
                  button: true,
                  child: InkWell(
                    onTap: () => onDestinationSelected(index),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (item.iconBuilder != null)
                            item.iconBuilder!(selected, color)
                          else
                            Icon(
                              selected ? item.selectedIcon : item.icon,
                              size: selected ? 24 : 22,
                              color: color,
                            ),
                          const SizedBox(height: 3),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              item.label,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 11,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                                color: color,
                                letterSpacing: 0,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
