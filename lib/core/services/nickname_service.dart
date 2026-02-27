import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the user's display nickname stored in SharedPreferences.
/// Reactive — UI updates automatically on [set] or [clear].
class NicknameNotifier extends Notifier<String?> {
  static const _key = 'user_nickname';

  @override
  String? build() {
    // Load asynchronously after build returns null (initial state).
    _load();
    return null;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_key);
  }

  Future<void> set(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, trimmed);
    state = trimmed;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    state = null;
  }
}

final nicknameProvider = NotifierProvider<NicknameNotifier, String?>(
  NicknameNotifier.new,
);
