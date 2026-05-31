import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const _historyKey = 'asset_search_history_v1';
const kMaxSearchHistoryEntries = 10;

class SearchHistoryStorage {
  SearchHistoryStorage._();
  static final SearchHistoryStorage instance = SearchHistoryStorage._();

  Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null) return [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> record(String query) async {
    final normalized = query.trim();
    if (normalized.length < 2) return;

    final items = await load();
    items.removeWhere((item) => item.toLowerCase() == normalized.toLowerCase());
    items.insert(0, normalized);
    if (items.length > kMaxSearchHistoryEntries) {
      items.removeRange(kMaxSearchHistoryEntries, items.length);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey, jsonEncode(items));
  }

  Future<void> remove(String query) async {
    final normalized = query.trim();
    final items = await load()
      ..removeWhere((item) => item.toLowerCase() == normalized.toLowerCase());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey, jsonEncode(items));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }
}

final searchHistoryStorage = SearchHistoryStorage.instance;
