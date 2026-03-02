import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cafe_vibe/core/services/nickname_service.dart';

/// Riverpod Notifier async 로드를 안전하게 기다리는 헬퍼
Future<ProviderContainer> _makeContainer() async {
  final container = ProviderContainer();
  container.read(nicknameProvider); // provider 활성화
  await Future.delayed(const Duration(milliseconds: 30));
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── 초기 상태 ─────────────────────────────────────────────
  group('NicknameNotifier — 동기 초기 상태', () {
    test('동기적 초기 상태는 null', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      expect(container.read(nicknameProvider), isNull);
      await Future.delayed(const Duration(milliseconds: 30)); // _load() 완료 대기
      container.dispose();
    });
  });

  group('NicknameNotifier — 저장된 닉네임 로드', () {
    test('로드 완료 후 저장된 닉네임 반환', () async {
      SharedPreferences.setMockInitialValues({'user_nickname': '테스트유저'});
      final container = await _makeContainer();
      expect(container.read(nicknameProvider), '테스트유저');
      container.dispose();
    });

    test('닉네임 없으면 로드 후 null 유지', () async {
      SharedPreferences.setMockInitialValues({});
      final container = await _makeContainer();
      expect(container.read(nicknameProvider), isNull);
      container.dispose();
    });
  });

  // ── set() ─────────────────────────────────────────────────
  group('NicknameNotifier.set()', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('닉네임 설정 시 상태 업데이트', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(nicknameProvider.notifier).set('카페헌터');
      expect(container.read(nicknameProvider), '카페헌터');
    });

    test('앞뒤 공백 제거 (trim)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(nicknameProvider.notifier).set('  바이브  ');
      expect(container.read(nicknameProvider), '바이브');
    });

    test('공백만 있는 경우 no-op (상태 변경 없음)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(nicknameProvider.notifier).set('   ');
      expect(container.read(nicknameProvider), isNull);
    });

    test('빈 문자열은 no-op', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(nicknameProvider.notifier).set('');
      expect(container.read(nicknameProvider), isNull);
    });

    test('SharedPreferences에 저장됨', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(nicknameProvider.notifier).set('노이즈마스터');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_nickname'), '노이즈마스터');
    });

    test('두 번 set() 시 마지막 값으로 교체', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(nicknameProvider.notifier).set('처음이름');
      await container.read(nicknameProvider.notifier).set('바꾼이름');
      expect(container.read(nicknameProvider), '바꾼이름');
    });
  });

  // ── clear() ───────────────────────────────────────────────
  group('NicknameNotifier.clear()', () {
    test('clear() 후 상태 null', () async {
      SharedPreferences.setMockInitialValues({'user_nickname': '기존닉네임'});
      final container = await _makeContainer();
      await container.read(nicknameProvider.notifier).clear();
      expect(container.read(nicknameProvider), isNull);
      container.dispose();
    });

    test('clear() 후 SharedPreferences에서 삭제됨', () async {
      SharedPreferences.setMockInitialValues({'user_nickname': '기존닉네임'});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(nicknameProvider.notifier).clear();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_nickname'), isNull);
    });
  });

  // ── hasShownPrompt() ──────────────────────────────────────
  group('NicknameNotifier.hasShownPrompt()', () {
    test('초기 상태에서 false', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await NicknameNotifier.hasShownPrompt(), isFalse);
    });

    test('플래그 true → true 반환', () async {
      SharedPreferences.setMockInitialValues({'nickname_prompt_shown': true});
      expect(await NicknameNotifier.hasShownPrompt(), isTrue);
    });

    test('플래그 false → false 반환', () async {
      SharedPreferences.setMockInitialValues({'nickname_prompt_shown': false});
      expect(await NicknameNotifier.hasShownPrompt(), isFalse);
    });
  });

  // ── markPromptShown() ─────────────────────────────────────
  group('NicknameNotifier.markPromptShown()', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('markPromptShown() 후 hasShownPrompt()=true', () async {
      await NicknameNotifier.markPromptShown();
      expect(await NicknameNotifier.hasShownPrompt(), isTrue);
    });
  });

  // ── resetAll() ────────────────────────────────────────────
  group('NicknameNotifier.resetAll()', () {
    test('닉네임과 프롬프트 플래그 모두 삭제', () async {
      SharedPreferences.setMockInitialValues({
        'user_nickname': '삭제될닉네임',
        'nickname_prompt_shown': true,
      });
      await NicknameNotifier.resetAll();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_nickname'), isNull);
      expect(prefs.getBool('nickname_prompt_shown'), isNull);
    });

    test('이미 없어도 예외 없이 완료', () async {
      SharedPreferences.setMockInitialValues({});
      await expectLater(NicknameNotifier.resetAll(), completes);
    });
  });

  // ── resetAllLive() ────────────────────────────────────────
  group('NicknameNotifier.resetAllLive()', () {
    test('in-memory 상태가 null로 변경', () async {
      SharedPreferences.setMockInitialValues({
        'user_nickname': '기존닉네임',
        'nickname_prompt_shown': true,
      });
      final container = await _makeContainer();
      await container.read(nicknameProvider.notifier).resetAllLive();
      expect(container.read(nicknameProvider), isNull);
      container.dispose();
    });

    test('SharedPreferences에서도 삭제', () async {
      SharedPreferences.setMockInitialValues({
        'user_nickname': '기존닉네임',
        'nickname_prompt_shown': true,
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(nicknameProvider.notifier).resetAllLive();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_nickname'), isNull);
      expect(prefs.getBool('nickname_prompt_shown'), isNull);
    });
  });
}
