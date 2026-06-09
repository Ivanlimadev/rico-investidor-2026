import 'package:flutter/material.dart';
import 'package:rico_investidor/app/app_shell_scope.dart';
import 'package:rico_investidor/features/menu/account_menu_items.dart';
import 'package:rico_investidor/features/menu/widgets/profile_header.dart';
import 'package:rico_investidor/models/user_profile.dart';

void openSettingsScreen(
  BuildContext context, {
  required UserProfile profile,
  required ProfileChanged onProfileChanged,
  required VoidCallback onLogin,
  required VoidCallback onRegister,
  required LogoutCallback onLogout,
  ValueChanged<ThemeMode>? onThemeModeChanged,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SettingsScreen(
        profile: profile,
        onProfileChanged: onProfileChanged,
        onLogin: onLogin,
        onRegister: onRegister,
        onLogout: onLogout,
        onThemeModeChanged: onThemeModeChanged,
      ),
    ),
  );
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.profile,
    required this.onProfileChanged,
    required this.onLogin,
    required this.onRegister,
    required this.onLogout,
    this.onThemeModeChanged,
  });

  final UserProfile profile;
  final ProfileChanged onProfileChanged;
  final VoidCallback onLogin;
  final VoidCallback onRegister;
  final LogoutCallback onLogout;
  final ValueChanged<ThemeMode>? onThemeModeChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late UserProfile _profile = widget.profile;

  @override
  void didUpdateWidget(SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile) {
      _profile = widget.profile;
    }
  }

  void _handleProfileChanged(UserProfile profile) {
    setState(() => _profile = profile);
    widget.onProfileChanged(profile);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        actions: const [ShellHomeButton()],
      ),
      body: ListView(
        children: [
          ProfileHeader(profile: _profile),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              'Conta',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          AccountMenuItems(
            profile: _profile,
            onProfileChanged: _handleProfileChanged,
            onLogin: widget.onLogin,
            onRegister: widget.onRegister,
            onLogout: widget.onLogout,
            onThemeModeChanged: widget.onThemeModeChanged,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
