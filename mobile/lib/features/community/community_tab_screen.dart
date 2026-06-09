import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/app/main_shell_screen.dart';
import 'package:rico_investidor/l10n/app_strings.dart';

class CommunityTabScreen extends StatelessWidget {
  const CommunityTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.communityTitle),
        actions: const [ShellHomeButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, kBottomNavContentPadding),
        children: [
          const _ComingSoonCard(
            icon: Icons.forum_outlined,
            title: AppStrings.communityDiscussions,
            subtitle: AppStrings.communityDiscussionsSubtitle,
          ),
          const SizedBox(height: 12),
          const _ComingSoonCard(
            icon: Icons.campaign_outlined,
            title: AppStrings.communityFeed,
            subtitle: AppStrings.communityFeedSubtitle,
          ),
          const SizedBox(height: 12),
          const _ComingSoonCard(
            icon: Icons.group_add_outlined,
            title: AppStrings.followInvestors,
            subtitle: AppStrings.followInvestorsSubtitle,
          ),
        ],
      ),
    );
  }
}

class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title, style: Theme.of(context).textTheme.titleSmall),
                      ),
                      Chip(
                        label: const Text(AppStrings.comingSoon),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
