import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's chosen representative badge ID (e.g. 'B01').
/// null means "use initial letter" (default behaviour).
class RepBadgeNotifier extends Notifier<String?> {
  static const _key = 'rep_badge_id';

  /// Call on account deletion to wipe the stored preference.
  static Future<void> resetAll() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
  }

  @override
  String? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_key);
  }

  Future<void> set(String badgeId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, badgeId);
    state = badgeId;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    state = null;
  }
}

final repBadgeProvider = NotifierProvider<RepBadgeNotifier, String?>(
  RepBadgeNotifier.new,
);
