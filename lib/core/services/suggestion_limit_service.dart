import 'package:shared_preferences/shared_preferences.dart';

/// Tracks daily suggestion submission limit (max 3 per day).
/// Uses SharedPreferences with date-based automatic reset.
/// Extracted from _SuggestionSheetState for testability.
class SuggestionLimitService {
  static const _kDateKey = 'suggestion_daily_date';
  static const _kCountKey = 'suggestion_daily_count';
  static const int dailyMax = 3;

  static String _todayStr() {
    final today = DateTime.now().toLocal();
    return '${today.year}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
  }

  /// Returns true if today's submission count has reached [dailyMax].
  /// Automatically resets the counter when called on a new calendar day.
  static Future<bool> isLimitReached() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayStr();
    final savedDate = prefs.getString(_kDateKey);
    if (savedDate != today) {
      await prefs.setString(_kDateKey, today);
      await prefs.setInt(_kCountKey, 0);
      return false;
    }
    return (prefs.getInt(_kCountKey) ?? 0) >= dailyMax;
  }

  /// Increments today's submission count by 1.
  static Future<void> increment() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_kCountKey) ?? 0;
    await prefs.setInt(_kCountKey, count + 1);
  }

  /// Returns today's submission count (0 if a new day or no data).
  static Future<int> todayCount() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString(_kDateKey);
    if (savedDate != _todayStr()) return 0;
    return prefs.getInt(_kCountKey) ?? 0;
  }

  /// Clears all limit data (call on account reset).
  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kDateKey);
    await prefs.remove(_kCountKey);
  }
}
