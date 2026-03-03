import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cafe_vibe/core/services/suggestion_limit_service.dart';

// ──────────────────────────────────────────────────────────────
// Helper: 오늘 날짜 문자열 (yyyy-MM-dd)
// ──────────────────────────────────────────────────────────────

String _today() {
  final now = DateTime.now().toLocal();
  return '${now.year}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

String _yesterday() {
  final now = DateTime.now().toLocal().subtract(const Duration(days: 1));
  return '${now.year}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── isLimitReached() ──────────────────────────────────────
  group('SuggestionLimitService.isLimitReached() — 새 날 / 초기 상태', () {
    test('SharedPreferences가 비어있으면 false (새 날로 처리)', () async {
      SharedPreferences.setMockInitialValues({});
      final result = await SuggestionLimitService.isLimitReached();
      expect(result, isFalse);
    });

    test('빈 상태에서 isLimitReached() 호출 후 오늘 날짜가 저장된다', () async {
      SharedPreferences.setMockInitialValues({});
      await SuggestionLimitService.isLimitReached();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('suggestion_daily_date'), _today());
    });

    test('빈 상태에서 isLimitReached() 호출 후 count=0이 설정된다', () async {
      SharedPreferences.setMockInitialValues({});
      await SuggestionLimitService.isLimitReached();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('suggestion_daily_count'), 0);
    });

    test('어제 날짜 저장 시 → false (새 날 리셋)', () async {
      SharedPreferences.setMockInitialValues({
        'suggestion_daily_date': _yesterday(),
        'suggestion_daily_count': 5,
      });
      final result = await SuggestionLimitService.isLimitReached();
      expect(result, isFalse);
    });

    test('어제 날짜에서 리셋 후 count가 0으로 초기화', () async {
      SharedPreferences.setMockInitialValues({
        'suggestion_daily_date': _yesterday(),
        'suggestion_daily_count': 5,
      });
      await SuggestionLimitService.isLimitReached();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('suggestion_daily_count'), 0);
    });
  });

  group('SuggestionLimitService.isLimitReached() — 오늘 카운트', () {
    test('오늘 count=0 → false', () async {
      SharedPreferences.setMockInitialValues({
        'suggestion_daily_date': _today(),
        'suggestion_daily_count': 0,
      });
      expect(await SuggestionLimitService.isLimitReached(), isFalse);
    });

    test('오늘 count=1 → false', () async {
      SharedPreferences.setMockInitialValues({
        'suggestion_daily_date': _today(),
        'suggestion_daily_count': 1,
      });
      expect(await SuggestionLimitService.isLimitReached(), isFalse);
    });

    test('오늘 count=2 → false (임계값 직전)', () async {
      SharedPreferences.setMockInitialValues({
        'suggestion_daily_date': _today(),
        'suggestion_daily_count': 2,
      });
      expect(await SuggestionLimitService.isLimitReached(), isFalse);
    });

    test('오늘 count=3 → true (한도 초과)', () async {
      SharedPreferences.setMockInitialValues({
        'suggestion_daily_date': _today(),
        'suggestion_daily_count': 3,
      });
      expect(await SuggestionLimitService.isLimitReached(), isTrue);
    });

    test('오늘 count=10 → true (한도 초과)', () async {
      SharedPreferences.setMockInitialValues({
        'suggestion_daily_date': _today(),
        'suggestion_daily_count': 10,
      });
      expect(await SuggestionLimitService.isLimitReached(), isTrue);
    });
  });

  // ── dailyMax 상수 ─────────────────────────────────────────
  group('SuggestionLimitService.dailyMax', () {
    test('dailyMax는 3이다', () {
      expect(SuggestionLimitService.dailyMax, 3);
    });
  });

  // ── increment() ───────────────────────────────────────────
  group('SuggestionLimitService.increment()', () {
    test('count=0에서 increment() → count=1', () async {
      SharedPreferences.setMockInitialValues({
        'suggestion_daily_date': _today(),
        'suggestion_daily_count': 0,
      });
      await SuggestionLimitService.increment();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('suggestion_daily_count'), 1);
    });

    test('count=2에서 increment() → count=3', () async {
      SharedPreferences.setMockInitialValues({
        'suggestion_daily_date': _today(),
        'suggestion_daily_count': 2,
      });
      await SuggestionLimitService.increment();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('suggestion_daily_count'), 3);
    });

    test('count 키 없는 상태에서 increment() → count=1 (기본값 0에서 증가)', () async {
      SharedPreferences.setMockInitialValues({
        'suggestion_daily_date': _today(),
      });
      await SuggestionLimitService.increment();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('suggestion_daily_count'), 1);
    });

    test('increment() 3회 → isLimitReached() = true', () async {
      SharedPreferences.setMockInitialValues({
        'suggestion_daily_date': _today(),
        'suggestion_daily_count': 0,
      });
      await SuggestionLimitService.increment();
      await SuggestionLimitService.increment();
      await SuggestionLimitService.increment();
      expect(await SuggestionLimitService.isLimitReached(), isTrue);
    });

    test('increment() 2회 → isLimitReached() = false', () async {
      SharedPreferences.setMockInitialValues({
        'suggestion_daily_date': _today(),
        'suggestion_daily_count': 0,
      });
      await SuggestionLimitService.increment();
      await SuggestionLimitService.increment();
      expect(await SuggestionLimitService.isLimitReached(), isFalse);
    });
  });

  // ── todayCount() ──────────────────────────────────────────
  group('SuggestionLimitService.todayCount()', () {
    test('빈 상태 → 0 반환', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await SuggestionLimitService.todayCount(), 0);
    });

    test('어제 날짜 저장 시 → 0 (새 날이므로 0)', () async {
      SharedPreferences.setMockInitialValues({
        'suggestion_daily_date': _yesterday(),
        'suggestion_daily_count': 3,
      });
      expect(await SuggestionLimitService.todayCount(), 0);
    });

    test('오늘 count=2 → 2 반환', () async {
      SharedPreferences.setMockInitialValues({
        'suggestion_daily_date': _today(),
        'suggestion_daily_count': 2,
      });
      expect(await SuggestionLimitService.todayCount(), 2);
    });

    test('오늘 count=3 → 3 반환', () async {
      SharedPreferences.setMockInitialValues({
        'suggestion_daily_date': _today(),
        'suggestion_daily_count': 3,
      });
      expect(await SuggestionLimitService.todayCount(), 3);
    });
  });

  // ── resetAll() ────────────────────────────────────────────
  group('SuggestionLimitService.resetAll()', () {
    test('날짜 키와 카운트 키 모두 삭제', () async {
      SharedPreferences.setMockInitialValues({
        'suggestion_daily_date': _today(),
        'suggestion_daily_count': 2,
      });
      await SuggestionLimitService.resetAll();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('suggestion_daily_date'), isFalse);
      expect(prefs.containsKey('suggestion_daily_count'), isFalse);
    });

    test('resetAll 후 isLimitReached() → false (새 날로 처리)', () async {
      SharedPreferences.setMockInitialValues({
        'suggestion_daily_date': _today(),
        'suggestion_daily_count': 3,
      });
      await SuggestionLimitService.resetAll();
      expect(await SuggestionLimitService.isLimitReached(), isFalse);
    });

    test('resetAll 후 todayCount() → 0', () async {
      SharedPreferences.setMockInitialValues({
        'suggestion_daily_date': _today(),
        'suggestion_daily_count': 2,
      });
      await SuggestionLimitService.resetAll();
      expect(await SuggestionLimitService.todayCount(), 0);
    });

    test('빈 상태에서 resetAll() — 예외 없이 완료', () async {
      SharedPreferences.setMockInitialValues({});
      await expectLater(SuggestionLimitService.resetAll(), completes);
    });
  });
}
