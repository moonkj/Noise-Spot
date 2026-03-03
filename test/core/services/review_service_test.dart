import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cafe_vibe/core/services/review_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ReviewService.requestIfEligible()은 InAppReview 플랫폼 채널 의존성으로
  // 단위 테스트 불가 — resetAll()만 검증한다.

  group('ReviewService.resetAll()', () {
    test('저장된 review_requested 플래그 삭제', () async {
      SharedPreferences.setMockInitialValues({'review_requested': true});
      await ReviewService.resetAll();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('review_requested'), isNull);
    });

    test('삭제 후 containsKey → false (false 저장이 아닌 완전 삭제)', () async {
      SharedPreferences.setMockInitialValues({'review_requested': true});
      await ReviewService.resetAll();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('review_requested'), isFalse);
    });

    test('키가 없는 상태에서 resetAll() — 예외 없이 완료', () async {
      SharedPreferences.setMockInitialValues({});
      await expectLater(ReviewService.resetAll(), completes);
    });

    test('resetAll 후 다시 resetAll() — 예외 없이 완료 (멱등성)', () async {
      SharedPreferences.setMockInitialValues({'review_requested': true});
      await ReviewService.resetAll();
      await expectLater(ReviewService.resetAll(), completes);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('review_requested'), isFalse);
    });
  });
}
