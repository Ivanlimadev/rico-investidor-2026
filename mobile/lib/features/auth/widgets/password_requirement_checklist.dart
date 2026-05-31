import 'package:flutter/material.dart';
import 'package:rico_investidor/core/utils/password_requirements.dart';

/// Checklist visual dos requisitos de senha — atualiza conforme o usuário digita.
class PasswordRequirementChecklist extends StatelessWidget {
  const PasswordRequirementChecklist({
    super.key,
    required this.password,
  });

  final String password;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    final success = theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'A senha deve conter:',
          style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        for (final rule in PasswordRequirements.requirements)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(
                  rule.test(password) ? Icons.check_circle_rounded : Icons.circle_outlined,
                  size: 18,
                  color: rule.test(password) ? success : muted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rule.label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: rule.test(password) ? success : muted,
                      fontWeight: rule.test(password) ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
