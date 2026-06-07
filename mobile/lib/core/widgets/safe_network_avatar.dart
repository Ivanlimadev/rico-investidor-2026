import 'package:flutter/material.dart';

/// Avatar com fallback quando a URL externa falha ou está indisponível.
class SafeNetworkAvatar extends StatelessWidget {
  const SafeNetworkAvatar({
    super.key,
    required this.radius,
    this.photoUrl,
    this.fallbackIcon = Icons.person,
  });

  final double radius;
  final String? photoUrl;
  final IconData fallbackIcon;

  bool get _hasPhoto => photoUrl != null && photoUrl!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    if (!_hasPhoto) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(fallbackIcon, size: radius, color: color),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.15),
      child: ClipOval(
        child: Image.network(
          photoUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(fallbackIcon, size: radius, color: color),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return SizedBox(
              width: radius,
              height: radius,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color.withValues(alpha: 0.7),
              ),
            );
          },
        ),
      ),
    );
  }
}
