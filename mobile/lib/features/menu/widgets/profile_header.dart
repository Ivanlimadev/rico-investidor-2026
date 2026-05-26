import 'package:flutter/material.dart';
import 'package:rico_investidor/models/user_profile.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.profile,
    this.compact = false,
    this.onTap,
  });

  final UserProfile profile;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final avatarRadius = compact ? 28.0 : 40.0;

    final content = Row(
      children: [
        CircleAvatar(
          radius: avatarRadius,
          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
          backgroundImage:
              profile.hasPhoto ? NetworkImage(profile.photoUrl!) : null,
          child: profile.hasPhoto
              ? null
              : Icon(
                  Icons.person,
                  size: avatarRadius,
                  color: Theme.of(context).colorScheme.primary,
                ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.displayName,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: compact ? 17 : 20,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    profile.plan.isPro ? Icons.workspace_premium : Icons.lock_open,
                    size: 16,
                    color: profile.plan.isPro
                        ? Theme.of(context).colorScheme.secondary
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Plano ${profile.plan.label}',
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (onTap != null)
          Icon(
            Icons.chevron_right,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
      ],
    );

    if (onTap == null) {
      return Padding(
        padding: EdgeInsets.fromLTRB(20, compact ? 12 : 20, 20, compact ? 8 : 16),
        child: content,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, compact ? 12 : 20, 12, compact ? 8 : 16),
          child: content,
        ),
      ),
    );
  }
}
