import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Device-local history for special-source video searches.
///
/// Kept apart from [LocalModeStorageService] normal history and from the
/// server-backed `search_history` cache.
class SpecialSearchHistoryStore {
  static const String prefsKey = 'special_video_search_history';
  static const int maxEntries = 20;

  static Future<List<String>> read() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(prefsKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! List) {
        return [];
      }
      return decoded.map((item) => item.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> add(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final history = await read();
    history.remove(trimmed);
    history.insert(0, trimmed);
    if (history.length > maxEntries) {
      history.removeRange(maxEntries, history.length);
    }
    await _write(history);
  }

  static Future<void> remove(String keyword) async {
    final history = await read();
    history.remove(keyword);
    await _write(history);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
  }

  static Future<void> _write(List<String> history) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, jsonEncode(history));
  }
}
