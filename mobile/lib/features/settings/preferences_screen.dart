import 'package:flutter/material.dart';
import 'package:rico_investidor/services/user_preferences_storage.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({
    super.key,
    this.onThemeModeChanged,
  });

  final ValueChanged<ThemeMode>? onThemeModeChanged;

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  UserPreferences? _preferences;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final preferences = await userPreferencesStorage.load();
    if (!mounted) return;
    setState(() {
      _preferences = preferences;
      _loading = false;
    });
  }

  Future<void> _update(UserPreferences preferences) async {
    setState(() => _preferences = preferences);
    await userPreferencesStorage.save(preferences);
    widget.onThemeModeChanged?.call(preferences.themeMode);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _preferences == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Preferências')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final preferences = _preferences!;

    return Scaffold(
      appBar: AppBar(title: const Text('Preferências')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              'Appearance',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Dark'),
            value: ThemeMode.dark,
            groupValue: preferences.themeMode,
            onChanged: (value) {
              if (value == null) return;
              _update(preferences.copyWith(themeMode: value));
            },
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Light'),
            value: ThemeMode.light,
            groupValue: preferences.themeMode,
            onChanged: (value) {
              if (value == null) return;
              _update(preferences.copyWith(themeMode: value));
            },
          ),
          RadioListTile<ThemeMode>(
            title: const Text('System default'),
            value: ThemeMode.system,
            groupValue: preferences.themeMode,
            onChanged: (value) {
              if (value == null) return;
              _update(preferences.copyWith(themeMode: value));
            },
          ),
          const Divider(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Text(
              'Notifications',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          SwitchListTile(
            title: const Text('Push notifications'),
            subtitle: const Text('Alerts, price updates and portfolio reminders'),
            value: preferences.notificationsEnabled,
            onChanged: (value) {
              _update(preferences.copyWith(notificationsEnabled: value));
            },
          ),
        ],
      ),
    );
  }
}
