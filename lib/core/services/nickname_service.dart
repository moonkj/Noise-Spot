import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the user's display nickname stored in SharedPreferences.
/// Reactive — UI updates automatically on [set] or [clear].
class NicknameNotifier extends Notifier<String?> {
  static const _key = 'user_nickname';
  static const _promptKey = 'nickname_prompt_shown';

  static Future<bool> hasShownPrompt() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_promptKey) ?? false;
  }

  static Future<void> markPromptShown() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_promptKey, true);
  }

  /// Clears nickname and prompt flag — call on account deletion.
  static Future<void> resetAll() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
    await p.remove(_promptKey);
  }

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
