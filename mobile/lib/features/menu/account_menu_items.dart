import 'package:flutter/material.dart';
import 'package:rico_investidor/core/config/legal_urls.dart';
import 'package:rico_investidor/core/network/api_exception.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/features/auth/data/auth_repository.dart';
import 'package:rico_investidor/features/legal/about_screen.dart';
import 'package:rico_investidor/features/legal/legal_document_screen.dart';
import 'package:rico_investidor/features/legal/legal_content.dart';
import 'package:rico_investidor/features/settings/change_password_screen.dart';
import 'package:rico_investidor/features/settings/help_support_screen.dart';
import 'package:rico_investidor/features/settings/preferences_screen.dart';
// HIDDEN: assinatura — import kept for paywall
// import 'package:rico_investidor/features/subscription/paywall_screen.dart';
import 'package:rico_investidor/l10n/app_strings.dart';
import 'package:rico_investidor/models/subscription_plan.dart';
import 'package:rico_investidor/models/user_profile.dart';
import 'package:rico_investidor/services/profile_photo_service.dart';

typedef ProfileChanged = void Function(UserProfile profile);
typedef LogoutCallback = Future<void> Function();

class AccountMenuItems extends StatelessWidget {
  const AccountMenuItems({
    super.key,
    required this.profile,
    required this.onProfileChanged,
    required this.onLogin,
    required this.onRegister,
    required this.onLogout,
    this.onThemeModeChanged,
    this.dense = false,
  });

  final UserProfile profile;
  final ProfileChanged onProfileChanged;
  final VoidCallback onLogin;
  final VoidCallback onRegister;
  final LogoutCallback onLogout;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final bool dense;

  Future<void> _editName(BuildContext context) async {
    final controller = TextEditingController(text: profile.displayName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.editNameTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: AppStrings.displayNameLabel,
            hintText: AppStrings.displayNameHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) Navigator.pop(context, name);
            },
            child: const Text(AppStrings.save),
          ),
        ],
      ),
    );
    if (result == null || !context.mounted) return;
    try {
      final updated = await authRepository.updateProfile(name: result);
      if (!context.mounted) return;
      onProfileChanged(updated);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.couldNotUpdateName)),
      );
    }
  }

  Future<void> _pickPhoto(BuildContext context) async {
    final picked = await profilePhotoService.pickFromGallery();
    if (picked == null || !context.mounted) return;

    try {
      final updated = await authRepository.uploadProfilePhoto(picked.path);
      if (!context.mounted) return;
      onProfileChanged(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.photoUpdated)),
      );
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.couldNotUploadPhoto)),
      );
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.signOutTitle),
        content: const Text(AppStrings.signOutMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(AppStrings.signOutButton),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await onLogout();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.signedOut)),
      );
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final farewell = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Que pena que você vai…'),
        content: const Text(
          'Sua carteira, alertas e dados de conta serão removidos permanentemente. '
          'Esperamos que volte quando quiser acompanhar seus investimentos de novo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ficar no app'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Continuar exclusão',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (farewell != true || !context.mounted) return;

    final passwordController = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(AppStrings.deleteAccountTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Esta ação é irreversível. Carteira, transações, alertas e finanças vinculadas serão apagados.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: AppStrings.passwordLabel,
                  hintText: AppStrings.confirmPasswordHint,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(AppStrings.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(AppStrings.deleteButton),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;

      await authRepository.deleteAccount(password: passwordController.text);
      if (!context.mounted) return;
      await onLogout();
      if (!context.mounted) return;
      onProfileChanged(
        profile.copyWith(
          displayName: 'Investidor',
          clearPhoto: true,
          email: null,
          isAnonymous: true,
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conta excluída. Esperamos vê-lo de volta em breve.'),
        ),
      );
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.couldNotDeleteAccount)),
      );
    } finally {
      passwordController.dispose();
    }
  }

  void _openLegal(BuildContext context, {required String title, required String url}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalDocumentScreen(title: title, url: url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (profile.isRegistered && profile.email != null)
          ListTile(
            dense: dense,
            leading: const Icon(Icons.email_outlined),
            title: const Text(AppStrings.emailMenuTitle),
            subtitle: Text(profile.email!),
          ),
        if (!profile.isRegistered) ...[
          ListTile(
            dense: dense,
            leading: const Icon(Icons.login),
            title: const Text(AppStrings.signInMenuTitle),
            subtitle: const Text(AppStrings.signInMenuSubtitle),
            onTap: onLogin,
          ),
          ListTile(
            dense: dense,
            leading: const Icon(Icons.person_add_outlined),
            title: const Text(AppStrings.createAccountMenuTitle),
            subtitle: const Text(AppStrings.createAccountMenuSubtitle),
            onTap: onRegister,
          ),
          const Divider(height: 8),
        ],
        ListTile(
          dense: dense,
          leading: const Icon(Icons.photo_camera_outlined),
          title: const Text(AppStrings.addPhoto),
          subtitle: profile.hasPhoto
              ? const Text(AppStrings.changeProfilePhoto)
              : const Text(AppStrings.noPhotoSet),
          onTap: () => _pickPhoto(context),
        ),
        ListTile(
          dense: dense,
          leading: const Icon(Icons.badge_outlined),
          title: const Text(AppStrings.editName),
          subtitle: Text(profile.displayName),
          onTap: () => _editName(context),
        ),
        // HIDDEN: assinatura — plano / assinar Rico Pro
        // ListTile(
        //   dense: dense,
        //   leading: Icon(plan.isPro ? Icons.workspace_premium : Icons.card_membership_outlined),
        //   title: const Text(AppStrings.currentPlan),
        //   subtitle: Text('${plan.label} · ${plan.description}'),
        //   trailing: _PlanBadge(plan: plan),
        // ),
        // ListTile(
        //   dense: dense,
        //   leading: const Icon(Icons.star_outline),
        //   title: Text(plan.isPro ? AppStrings.manageSubscription : AppStrings.subscribeRicoPro),
        //   subtitle: Text(
        //     plan.isPro
        //         ? AppStrings.subscriptionManageSubtitle
        //         : AppStrings.subscriptionUpgradeSubtitle,
        //   ),
        //   onTap: () async {
        //     final upgraded = await openPaywallScreen(context);
        //     if (upgraded == true && context.mounted) {
        //       onProfileChanged(profile.copyWith(plan: SubscriptionPlan.pro));
        //     }
        //   },
        // ),
        // const Divider(height: 8),
        ListTile(
          dense: dense,
          leading: const Icon(Icons.tune_outlined),
          title: const Text(AppStrings.preferences),
          subtitle: const Text(AppStrings.preferencesSubtitle),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PreferencesScreen(onThemeModeChanged: onThemeModeChanged),
              ),
            );
          },
        ),
        ListTile(
          dense: dense,
          leading: const Icon(Icons.help_outline),
          title: const Text(AppStrings.helpAndSupport),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const HelpSupportScreen(),
              ),
            );
          },
        ),
        ListTile(
          dense: dense,
          leading: const Icon(Icons.info_outline),
          title: const Text('Sobre nós'),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
            );
          },
        ),
        ListTile(
          dense: dense,
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text(AppStrings.privacy),
          onTap: () => _openLegal(
            context,
            title: LegalContent.privacyTitle,
            url: LegalUrls.privacyPolicy,
          ),
        ),
        ListTile(
          dense: dense,
          leading: const Icon(Icons.description_outlined),
          title: const Text(AppStrings.termsOfUse),
          onTap: () => _openLegal(
            context,
            title: LegalContent.termsTitle,
            url: LegalUrls.termsOfService,
          ),
        ),
        if (profile.isRegistered) ...[
          const Divider(height: 8),
          ListTile(
            dense: dense,
            leading: const Icon(Icons.lock_outline),
            title: const Text(AppStrings.changePassword),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ChangePasswordScreen(),
                ),
              );
            },
          ),
          ListTile(
            dense: dense,
            leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
            title: Text(
              AppStrings.deleteAccountTitle,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => _confirmDeleteAccount(context),
          ),
          ListTile(
            dense: dense,
            leading: const Icon(Icons.logout),
            title: const Text(AppStrings.signOutTitle),
            onTap: () => _confirmLogout(context),
          ),
        ],
      ],
    );
  }
}

// ignore: unused_element
class _PlanBadge extends StatelessWidget {
  const _PlanBadge({required this.plan});

  final SubscriptionPlan plan;

  @override
  Widget build(BuildContext context) {
    final isPro = plan.isPro;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPro
            ? AppColors.accent.withValues(alpha: 0.25)
            : Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        plan.label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isPro ? AppColors.accent : Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
