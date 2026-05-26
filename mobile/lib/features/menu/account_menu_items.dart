import 'package:flutter/material.dart';
import 'package:rico_investidor/core/theme/app_colors.dart';
import 'package:rico_investidor/models/subscription_plan.dart';
import 'package:rico_investidor/models/user_profile.dart';

typedef ProfileChanged = void Function(UserProfile profile);

class AccountMenuItems extends StatelessWidget {
  const AccountMenuItems({
    super.key,
    required this.profile,
    required this.onProfileChanged,
    this.dense = false,
  });

  final UserProfile profile;
  final ProfileChanged onProfileChanged;
  final bool dense;

  Future<void> _showComingSoon(BuildContext context, String feature) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature — em breve')),
    );
  }

  Future<void> _editName(BuildContext context) async {
    final controller = TextEditingController(text: profile.displayName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar nome'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nome exibido',
            hintText: 'Como aparece no app',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) Navigator.pop(context, name);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (result != null && context.mounted) {
      onProfileChanged(profile.copyWith(displayName: result));
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir conta'),
        content: const Text(
          'Esta ação removerá sua conta e todos os dados associados. '
          'Não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.negative,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await _showComingSoon(context, 'Exclusão de conta');
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = profile.plan;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          dense: dense,
          leading: const Icon(Icons.photo_camera_outlined),
          title: const Text('Adicionar foto'),
          subtitle: profile.hasPhoto
              ? const Text('Alterar foto do perfil')
              : const Text('Nenhuma foto definida'),
          onTap: () => _showComingSoon(context, 'Foto do perfil'),
        ),
        ListTile(
          dense: dense,
          leading: const Icon(Icons.badge_outlined),
          title: const Text('Editar nome'),
          subtitle: Text(profile.displayName),
          onTap: () => _editName(context),
        ),
        ListTile(
          dense: dense,
          leading: Icon(plan.isPro ? Icons.workspace_premium : Icons.card_membership_outlined),
          title: const Text('Plano atual'),
          subtitle: Text('${plan.label} · ${plan.description}'),
          trailing: _PlanBadge(plan: plan),
        ),
        ListTile(
          dense: dense,
          leading: const Icon(Icons.star_outline),
          title: Text(plan.isPro ? 'Gerenciar assinatura' : 'Assinar Rico Pro'),
          subtitle: Text(
            plan.isPro
                ? 'Renovação, fatura e cancelamento'
                : 'Desbloqueie alertas, carteiras e mais',
          ),
          onTap: () => _showComingSoon(context, 'Assinatura'),
        ),
        const Divider(height: 8),
        ListTile(
          dense: dense,
          leading: const Icon(Icons.tune_outlined),
          title: const Text('Preferências'),
          subtitle: const Text('Notificações, privacidade e idioma'),
          onTap: () => _showComingSoon(context, 'Preferências'),
        ),
        ListTile(
          dense: dense,
          leading: const Icon(Icons.help_outline),
          title: const Text('Ajuda e suporte'),
          onTap: () => _showComingSoon(context, 'Ajuda'),
        ),
        ListTile(
          dense: dense,
          leading: Icon(Icons.delete_outline, color: AppColors.negative),
          title: Text(
            'Excluir conta',
            style: TextStyle(color: AppColors.negative),
          ),
          onTap: () => _confirmDeleteAccount(context),
        ),
      ],
    );
  }
}

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
