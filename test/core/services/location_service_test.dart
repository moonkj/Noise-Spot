import 'package:flutter_test/flutter_test.dart';
import 'package:cafe_vibe/core/services/location_service.dart';

void main() {
  // 서울 광화문 기준 좌표
  const baseLat = 37.5759;
  const baseLng = 126.9769;

  // reportMaxDistanceMeters = 65m (MapConstants.reportMaxDistanceMeters)
  group('LocationService.isWithinReportRadius — Haversine 65m 게이트', () {
    test('동일한 위치(0m)는 반경 내에 있다', () {
      expect(
        LocationService.isWithinReportRadius(
          userLat: baseLat, userLng: baseLng,
          targetLat: baseLat, targetLng: baseLng,
        ),
        isTrue,
      );
    });

    test('약 22m 북쪽은 반경 내에 있다 (65m 한계 내)', () {
      // 22m ≈ 0.000198° 위도 차이
      expect(
        LocationService.isWithinReportRadius(
          userLat: baseLat, userLng: baseLng,
          targetLat: baseLat + 0.000198, targetLng: baseLng,
        ),
        isTrue,
      );
    });

    test('약 64m(65m 미만)는 반경 내에 있다', () {
      // 64m ≈ 0.000576° 위도 차이
      expect(
        LocationService.isWithinReportRadius(
          userLat: baseLat, userLng: baseLng,
          targetLat: baseLat + 0.000576, targetLng: baseLng,
        ),
        isTrue,
      );
    });

    test('약 70m(65m 초과)는 반경 밖에 있다', () {
      // 70m ≈ 0.000630° 위도 차이
      expect(
        LocationService.isWithinReportRadius(
          userLat: baseLat, userLng: baseLng,
          targetLat: baseLat + 0.000630, targetLng: baseLng,
        ),
        isFalse,
      );
    });

    test('약 200m(3배 이상)는 반경 밖에 있다', () {
      // 200m ≈ 0.001800° 위도 차이
      expect(
        LocationService.isWithinReportRadius(
          userLat: baseLat, userLng: baseLng,
          targetLat: baseLat + 0.001800, targetLng: baseLng,
        ),
        isFalse,
      );
    });

    test('서울→부산 약 325km는 반경 밖에 있다', () {
      const busanLat = 35.1796;
      const busanLng = 129.0756;
      expect(
        LocationService.isWithinReportRadius(
          userLat: baseLat, userLng: baseLng,
          targetLat: busanLat, targetLng: busanLng,
        ),
        isFalse,
      );
    });

    test('경도 방향 이동 — 약 40m(위도 37° 기준)는 반경 내에 있다', () {
      // 위도 37°에서 경도 1° ≈ 88,000m
      // 40m ≈ 0.000455° 경도 차이
      expect(
        LocationService.isWithinReportRadius(
          userLat: baseLat, userLng: baseLng,
          targetLat: baseLat, targetLng: baseLng + 0.000455,
        ),
        isTrue,
      );
    });

    test('경도 방향 이동 — 약 70m는 반경 밖에 있다', () {
      // 70m ≈ 0.000795° 경도 차이
      expect(
        LocationService.isWithinReportRadius(
          userLat: baseLat, userLng: baseLng,
          targetLat: baseLat, targetLng: baseLng + 0.000795,
        ),
        isFalse,
      );
    });

    test('대각선 이동(북동) — 약 22m 북 + 22m 동 ≈ 31m → 반경 내', () {
      // 22m 북 ≈ 0.000198°, 22m 동 ≈ 0.000250°
      // 합산 약 31m → 65m 이내
      expect(
        LocationService.isWithinReportRadius(
          userLat: baseLat, userLng: baseLng,
          targetLat: baseLat + 0.000198,
          targetLng: baseLng + 0.000250,
        ),
        isTrue,
      );
    });

    test('대각선 이동(북동) — 약 50m 북 + 50m 동 ≈ 70.7m → 반경 밖', () {
      // 50m 북 ≈ 0.000450°, 50m 동 ≈ 0.000568°
      // 합산 약 70.7m → 65m 초과
      expect(
        LocationService.isWithinReportRadius(
          userLat: baseLat, userLng: baseLng,
          targetLat: baseLat + 0.000450,
          targetLng: baseLng + 0.000568,
        ),
        isFalse,
      );
    });
  });

  // ── LocationService.distanceMeters() ─────────────────────
  group('LocationService.distanceMeters()', () {
    test('동일 위치 → 0m', () {
      final d = LocationService.distanceMeters(
        userLat: baseLat, userLng: baseLng,
        targetLat: baseLat, targetLng: baseLng,
      );
      expect(d, closeTo(0.0, 0.01));
    });

    test('약 22m 북쪽 → 22m 근사', () {
      // 22m ≈ 0.000198° 위도
      final d = LocationService.distanceMeters(
        userLat: baseLat, userLng: baseLng,
        targetLat: baseLat + 0.000198, targetLng: baseLng,
      );
      expect(d, closeTo(22.0, 2.0));
    });

    test('서울→부산 → 약 325km', () {
      const busanLat = 35.1796;
      const busanLng = 129.0756;
      final d = LocationService.distanceMeters(
        userLat: baseLat, userLng: baseLng,
        targetLat: busanLat, targetLng: busanLng,
      );
      // 325km ± 5km 허용
      expect(d, greaterThan(320000));
      expect(d, lessThan(330000));
    });

    test('distanceMeters와 isWithinReportRadius 일관성: 같은 거리', () {
      // ~30m — isWithinReportRadius=true, distanceMeters < 65
      const dlat = 0.000270; // ≈ 30m
      final d = LocationService.distanceMeters(
        userLat: baseLat, userLng: baseLng,
        targetLat: baseLat + dlat, targetLng: baseLng,
      );
      final within = LocationService.isWithinReportRadius(
        userLat: baseLat, userLng: baseLng,
        targetLat: baseLat + dlat, targetLng: baseLng,
      );
      expect(d, lessThanOrEqualTo(65.0));
      expect(within, isTrue);
    });
  });

  // ── LocationException ─────────────────────────────────────
  group('LocationException', () {
    test('message가 올바르게 저장된다', () {
      final ex = LocationException('위치 서비스가 비활성화되어 있습니다.');
      expect(ex.message, '위치 서비스가 비활성화되어 있습니다.');
    });

    test('toString()이 message를 반환한다', () {
      final ex = LocationException('테스트 오류');
      expect(ex.toString(), '테스트 오류');
    });

    test('Exception을 구현한다', () {
      expect(LocationException('x'), isA<Exception>());
    });
  });
}
