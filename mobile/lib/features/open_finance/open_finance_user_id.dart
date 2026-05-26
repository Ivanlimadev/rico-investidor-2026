import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'open_finance_client_user_id';

Future<String> getOpenFinanceClientUserId() async {
  final prefs = await SharedPreferences.getInstance();
  final existing = prefs.getString(_prefsKey);
  if (existing != null && existing.length >= 8) return existing;

  final created = 'rico-${DateTime.now().microsecondsSinceEpoch}';
  await prefs.setString(_prefsKey, created);
  return created;
}
