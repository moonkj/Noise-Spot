import 'package:flutter_test/flutter_test.dart';
import 'package:cafe_vibe/core/constants/map_constants.dart';

void main() {
  // ── 리포팅 반경 ────────────────────────────────────────────
  group('MapConstants — 리포팅 반경', () {
    test('reportMaxDistanceMeters == 65m (비즈니스 규칙)', () {
      expect(MapConstants.reportMaxDistanceMeters, 65.0);
    });
  });

  // ── 조회 반경 ─────────────────────────────────────────────
  group('MapConstants — 조회 반경', () {
    test('defaultRadiusMeters == 3km', () {
      expect(MapConstants.defaultRadiusMeters, 3000.0);
    });

    test('maxRadiusMeters == 5km', () {
      expect(MapConstants.maxRadiusMeters, 5000.0);
    });

    test('maxRadiusMeters > defaultRadiusMeters', () {
      expect(MapConstants.maxRadiusMeters, greaterThan(MapConstants.defaultRadiusMeters));
    });
  });

  // ── 카메라 디바운스 ────────────────────────────────────────
  group('MapConstants — 카메라 디바운스', () {
    test('cameraIdleDebounceMs == 300ms', () {
      expect(MapConstants.cameraIdleDebounceMs, 300);
    });

    test('cameraIdleDebounceMs > 0', () {
      expect(MapConstants.cameraIdleDebounceMs, isPositive);
    });
  });

  // ── 캐시 TTL ──────────────────────────────────────────────
  group('MapConstants — 캐시 TTL', () {
    test('boundsCacheTtlSeconds == 300s (5분)', () {
      expect(MapConstants.boundsCacheTtlSeconds, 300);
    });

    test('boundsCacheTtlSeconds은 양수', () {
      expect(MapConstants.boundsCacheTtlSeconds, isPositive);
    });
  });

  // ── 줌 레벨 임계값 ────────────────────────────────────────
  group('MapConstants — 줌 레벨 논리적 순서', () {
    test('zoomMinLoad == 11.0', () {
      expect(MapConstants.zoomMinLoad, 11.0);
    });

    test('zoomHeatmapMin == zoomMinLoad (함께 시작)', () {
      expect(MapConstants.zoomHeatmapMin, MapConstants.zoomMinLoad);
    });

    test('zoomHeatmapMax < zoomReducedMin (구간 연속성)', () {
      expect(MapConstants.zoomHeatmapMax, lessThan(MapConstants.zoomReducedMin));
    });

    test('zoomReducedMin == 13.0', () {
      expect(MapConstants.zoomReducedMin, 13.0);
    });

    test('zoomReducedMax < zoomIndividualMin (구간 연속성)', () {
      expect(MapConstants.zoomReducedMax, lessThan(MapConstants.zoomIndividualMin));
    });

    test('zoomIndividualMin == 15.0', () {
      expect(MapConstants.zoomIndividualMin, 15.0);
    });

    test('전체 줌 순서: heatmapMin < reducedMin < individualMin', () {
      expect(MapConstants.zoomHeatmapMin, lessThan(MapConstants.zoomReducedMin));
      expect(MapConstants.zoomReducedMin, lessThan(MapConstants.zoomIndividualMin));
    });
  });

  // ── 기본 지도 중심 ────────────────────────────────────────
  group('MapConstants — 기본 지도 중심 (서울 시청)', () {
    test('defaultLat는 유효한 위도 범위(-90~90)', () {
      expect(MapConstants.defaultLat, greaterThanOrEqualTo(-90.0));
      expect(MapConstants.defaultLat, lessThanOrEqualTo(90.0));
    });

    test('defaultLng는 유효한 경도 범위(-180~180)', () {
      expect(MapConstants.defaultLng, greaterThanOrEqualTo(-180.0));
      expect(MapConstants.defaultLng, lessThanOrEqualTo(180.0));
    });

    test('defaultLat는 한국 영역 내 (33~38°N)', () {
      expect(MapConstants.defaultLat, greaterThan(33.0));
      expect(MapConstants.defaultLat, lessThan(38.5));
    });

    test('defaultLng는 한국 영역 내 (124~132°E)', () {
      expect(MapConstants.defaultLng, greaterThan(124.0));
      expect(MapConstants.defaultLng, lessThan(132.0));
    });

    test('defaultZoom > 0', () {
      expect(MapConstants.defaultZoom, isPositive);
    });
  });

  // ── 마커 크기 ─────────────────────────────────────────────
  group('MapConstants — 마커 크기', () {
    test('markerSizeIndividual > markerSizeReduced (개별 > 축소)', () {
      expect(MapConstants.markerSizeIndividual, greaterThan(MapConstants.markerSizeReduced));
    });

    test('markerSizeReduced > 0', () {
      expect(MapConstants.markerSizeReduced, isPositive);
    });
  });

  // ── 데이터 신선도 ─────────────────────────────────────────
  group('MapConstants — 데이터 신선도', () {
    test('spotFadeAfterDays == 30일', () {
      expect(MapConstants.spotFadeAfterDays, 30);
    });

    test('freshDataHours == 24시간', () {
      expect(MapConstants.freshDataHours, 24);
    });

    test('fallbackDataDays > 0', () {
      expect(MapConstants.fallbackDataDays, isPositive);
    });

    test('fallbackDataDays >= freshDataHours / 24 (호환성)', () {
      // freshDataHours=24 → 1일, fallbackDataDays ≥ 1
      expect(
        MapConstants.fallbackDataDays,
        greaterThanOrEqualTo(MapConstants.freshDataHours ~/ 24),
      );
    });
  });

  // ── 쿼리 제한 ─────────────────────────────────────────────
  group('MapConstants — 쿼리 제한', () {
    test('maxSpotsPerQuery > 0', () {
      expect(MapConstants.maxSpotsPerQuery, isPositive);
    });

    test('maxSpotsPerQuery >= 50 (충분한 스팟 로드)', () {
      expect(MapConstants.maxSpotsPerQuery, greaterThanOrEqualTo(50));
    });
  });
}
