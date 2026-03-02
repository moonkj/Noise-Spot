import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cafe_vibe/core/services/rep_badge_service.dart';

/// Riverpod Notifier async 로드를 안전하게 기다리는 헬퍼
/// container dispose 전에 _load() future가 state= 호출 전에 완료되도록 보장
Future<ProviderContainer> _makeContainer() async {
  final container = ProviderContainer();
  // 초기 상태를 읽어 provider를 활성화
  container.read(repBadgeProvider);
  // SharedPreferences 비동기 로드 완료 대기
  await Future.delayed(const Duration(milliseconds: 30));
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── 초기 상태 ─────────────────────────────────────────────
  group('RepBadgeNotifier — 초기 상태 (저장 없음)', () {
    test('동기적 초기 상태는 null', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      expect(container.read(repBadgeProvider), isNull);
      await Future.delayed(const Duration(milliseconds: 30)); // _load() 완료 대기
      container.dispose();
    });
  });

  group('RepBadgeNotifier — 저장된 값이 있는 경우', () {
    test('로드 완료 후 저장된 badge ID 반환', () async {
      SharedPreferences.setMockInitialValues({'rep_badge_id': 'B05'});
      final container = await _makeContainer();
      expect(container.read(repBadgeProvider), 'B05');
      container.dispose();
    });
  });

  // ── set() ─────────────────────────────────────────────────
  group('RepBadgeNotifier.set()', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('set() 호출 시 상태가 badge ID로 변경', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(repBadgeProvider.notifier).set('B03');
      expect(container.read(repBadgeProvider), 'B03');
    });

    test('set() 호출 시 SharedPreferences에 저장됨', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(repBadgeProvider.notifier).set('B07');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('rep_badge_id'), 'B07');
    });

    test('set()을 두 번 호출하면 마지막 값으로 덮어씀', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(repBadgeProvider.notifier).set('B01');
      await container.read(repBadgeProvider.notifier).set('B10');
      expect(container.read(repBadgeProvider), 'B10');
    });

    test('B01~B30 유효한 ID 저장', () async {
      for (int i = 1; i <= 30; i++) {
        SharedPreferences.setMockInitialValues({});
        final container = ProviderContainer();
        final id = 'B${i.toString().padLeft(2, '0')}';
        await container.read(repBadgeProvider.notifier).set(id);
        expect(container.read(repBadgeProvider), id, reason: '$id 저장 실패');
        container.dispose();
      }
    });
  });

  // ── clear() ───────────────────────────────────────────────
  group('RepBadgeNotifier.clear()', () {
    test('clear() 후 상태가 null로 변경', () async {
      SharedPreferences.setMockInitialValues({'rep_badge_id': 'B12'});
      final container = await _makeContainer();
      await container.read(repBadgeProvider.notifier).clear();
      expect(container.read(repBadgeProvider), isNull);
      container.dispose();
    });

    test('clear() 후 SharedPreferences에서 삭제됨', () async {
      SharedPreferences.setMockInitialValues({'rep_badge_id': 'B12'});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(repBadgeProvider.notifier).clear();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('rep_badge_id'), isNull);
    });
  });

  // ── resetAll() — 정적 메서드 ──────────────────────────────
  group('RepBadgeNotifier.resetAll()', () {
    test('저장된 badge ID 삭제', () async {
      SharedPreferences.setMockInitialValues({'rep_badge_id': 'B20'});
      await RepBadgeNotifier.resetAll();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('rep_badge_id'), isNull);
    });

    test('이미 없어도 예외 없이 완료', () async {
      SharedPreferences.setMockInitialValues({});
      await expectLater(RepBadgeNotifier.resetAll(), completes);
    });
  });
}
