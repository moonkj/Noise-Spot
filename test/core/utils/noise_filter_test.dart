import 'package:flutter_test/flutter_test.dart';
import 'package:cafe_vibe/core/utils/noise_filter.dart';

void main() {
  group('NoiseFilter.isValid', () {
    test('정상 범위 값은 유효하다', () {
      expect(NoiseFilter.isValid(30.0), isTrue);
      expect(NoiseFilter.isValid(55.0), isTrue);
      expect(NoiseFilter.isValid(85.0), isTrue);
      expect(NoiseFilter.isValid(119.9), isTrue);
    });

    test('0dB는 유효하다', () {
      expect(NoiseFilter.isValid(0.0), isTrue);
    });

    test('120dB 이상은 무효 (환경 노이즈 차단)', () {
      expect(NoiseFilter.isValid(120.0), isFalse);
      expect(NoiseFilter.isValid(150.0), isFalse);
    });

    test('음수 값은 무효', () {
      expect(NoiseFilter.isValid(-1.0), isFalse);
      expect(NoiseFilter.isValid(-0.001), isFalse);
    });

    test('NaN과 Infinity는 무효', () {
      expect(NoiseFilter.isValid(double.nan), isFalse);
      expect(NoiseFilter.isValid(double.infinity), isFalse);
      expect(NoiseFilter.isValid(double.negativeInfinity), isFalse);
    });
  });

  group('NoiseFilter.filterOutliers', () {
    test('정상 분포에서 이상치를 제거한다', () {
      // 9개 정상값(50dB) + 이상치(200dB): mean=65, stddev=45, threshold=112.5
      // |200 - 65| = 135 > 112.5 → 이상치로 제거됨
      final readings = [50.0, 50.0, 50.0, 50.0, 50.0, 50.0, 50.0, 50.0, 50.0, 200.0];
      final filtered = NoiseFilter.filterOutliers(readings);
      expect(filtered.contains(200.0), isFalse);
      expect(filtered.length, lessThan(readings.length));
    });

    test('빈 리스트 입력 시 빈 리스트 반환', () {
      expect(NoiseFilter.filterOutliers([]), isEmpty);
    });

    test('단일 원소는 그대로 반환', () {
      final result = NoiseFilter.filterOutliers([55.0]);
      expect(result, [55.0]);
    });

    test('모두 같은 값이면 전부 유지', () {
      final all60 = List.filled(10, 60.0);
      final result = NoiseFilter.filterOutliers(all60);
      expect(result.length, 10);
    });

    test('2개 원소(length < 3) → 그대로 반환', () {
      final result = NoiseFilter.filterOutliers([40.0, 80.0]);
      expect(result, [40.0, 80.0]);
    });

    test('원본 리스트는 변경하지 않는다', () {
      final original = [40.0, 50.0, 60.0, 200.0];
      NoiseFilter.filterOutliers(original);
      expect(original.length, 4); // 원본 보존
    });
  });
}
