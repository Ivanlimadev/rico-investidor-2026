import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeModeKey = 'user_preferences_theme_mode_v1';
const _notificationsKey = 'user_preferences_notifications_v1';
const _localeKey = 'user_preferences_locale_v1';

/// Default locale for the US-focused app build.
const defaultLocaleCode = 'en';

class UserPreferences {
  const UserPreferences({
    required this.themeMode,
    required this.notificationsEnabled,
    required this.localeCode,
  });

  final ThemeMode themeMode;
  final bool notificationsEnabled;
  final String localeCode;

  Locale get locale => Locale(localeCode);

  UserPreferences copyWith({
    ThemeMode? themeMode,
    bool? notificationsEnabled,
    String? localeCode,
  }) {
    return UserPreferences(
      themeMode: themeMode ?? this.themeMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      localeCode: localeCode ?? this.localeCode,
    );
  }
}

class UserPreferencesStorage {
  UserPreferencesStorage._();
  static final UserPreferencesStorage instance = UserPreferencesStorage._();

  Future<UserPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    final themeRaw = prefs.getString(_themeModeKey);
    return UserPreferences(
      themeMode: _parseThemeMode(themeRaw),
      notificationsEnabled: prefs.getBool(_notificationsKey) ?? true,
      localeCode: prefs.getString(_localeKey) ?? defaultLocaleCode,
    );
  }

  Future<void> save(UserPreferences preferences) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, _themeModeToString(preferences.themeMode));
    await prefs.setBool(_notificationsKey, preferences.notificationsEnabled);
    await prefs.setString(_localeKey, preferences.localeCode);
  }

  static ThemeMode _parseThemeMode(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.system:
        return 'system';
      case ThemeMode.dark:
        return 'dark';
    }
  }
}

final userPreferencesStorage = UserPreferencesStorage.instance;
