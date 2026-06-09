import 'package:flutter/material.dart';
import 'package:rico_investidor/core/widgets/safe_network_avatar.dart';
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
        SafeNetworkAvatar(
          radius: avatarRadius,
          photoUrl: profile.hasPhoto ? profile.photoUrl : null,
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
              if (profile.isRegistered && profile.email != null)
                Text(
                  profile.email!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              else
                Text(
                  profile.isRegistered ? 'Active account' : 'Guest',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
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
