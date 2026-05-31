import 'package:shared_preferences/shared_preferences.dart';

/// Persiste se o usuário já passou pela etapa de cadastro (criou conta,
/// fez login ou escolheu continuar sem cadastro).
class AccountOnboardingStorage {
  AccountOnboardingStorage({SharedPreferences? prefs}) : _prefs = prefs;

  static const _completedKey = 'account_onboarding_completed';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _storage async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<bool> isCompleted() async {
    final prefs = await _storage;
    return prefs.getBool(_completedKey) ?? false;
  }

  Future<void> markCompleted() async {
    final prefs = await _storage;
    await prefs.setBool(_completedKey, true);
  }

  Future<void> reset() async {
    final prefs = await _storage;
    await prefs.remove(_completedKey);
  }
}

final accountOnboardingStorage = AccountOnboardingStorage();
