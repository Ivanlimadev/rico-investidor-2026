class PasswordRequirement {
  const PasswordRequirement({required this.label, required this.test});

  final String label;
  final bool Function(String password) test;
}

abstract final class PasswordRequirements {
  static final requirements = <PasswordRequirement>[
    PasswordRequirement(
      label: 'Mínimo 8 caracteres',
      test: _hasMinLength,
    ),
    PasswordRequirement(
      label: 'Pelo menos 1 letra maiúscula',
      test: _hasUppercase,
    ),
    PasswordRequirement(
      label: '1 número',
      test: _hasDigit,
    ),
    PasswordRequirement(
      label: '1 caractere especial (@, #, !, etc.)',
      test: _hasSpecial,
    ),
  ];

  static bool _hasMinLength(String password) => password.length >= 8;

  static bool _hasUppercase(String password) => RegExp(r'[A-Z]').hasMatch(password);

  static bool _hasDigit(String password) => RegExp(r'\d').hasMatch(password);

  static bool _hasSpecial(String password) => RegExp(r'[^A-Za-z0-9]').hasMatch(password);

  static bool isValid(String password) {
    return requirements.every((rule) => rule.test(password));
  }

  static String? validationMessage(String password) {
    if (password.isEmpty) return 'Informe uma senha';
    for (final rule in requirements) {
      if (!rule.test(password)) return rule.label;
    }
    return null;
  }
}
