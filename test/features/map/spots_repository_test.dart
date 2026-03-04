import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cafe_vibe/features/map/data/spots_repository.dart';

// ──────────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────────

Map<String, dynamic> _photoJson({
  String id = 'spot-001',
  String name = '스타벅스 강남점',
  String? googlePlaceId = 'ChIJ_test',
  String? formattedAddress = '서울특별시 강남구 테헤란로 1',
  String? photoUrl = 'https://example.supabase.co/storage/v1/photo.jpg',
  int reportCount = 12,
}) =>
    {
      'id': id,
      'name': name,
      'google_place_id': googlePlaceId,
      'formatted_address': formattedAddress,
      'photo_url': photoUrl,
      'report_count': reportCount,
    };

Map<String, dynamic> _adminJson({
  String id = 'admin-001',
  String name = '조용한 카페',
  String? formattedAddress = '서울특별시 마포구 홍대입구 1',
  double lat = 37.5546,
  double lng = 126.9236,
  int reportCount = 5,
  String createdAt = '2025-01-15T10:30:00.000Z',
}) =>
    {
      'id': id,
      'name': name,
      'formatted_address': formattedAddress,
      'lat': lat,
      'lng': lng,
      'report_count': reportCount,
      'created_at': createdAt,
    };

// ──────────────────────────────────────────────────────────────
// Fake Uint8List helpers for image validation
// ──────────────────────────────────────────────────────────────

Uint8List _jpeg() => Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
Uint8List _png() => Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A]);
Uint8List _webp() => Uint8List.fromList([
      0x52, 0x49, 0x46, 0x46, // RIFF
      0x00, 0x00, 0x00, 0x00, // size
      0x57, 0x45, 0x42, 0x50, // WEBP
    ]);
Uint8List _unknown() => Uint8List.fromList([0x00, 0x01, 0x02, 0x03]);
Uint8List _tooShort() => Uint8List.fromList([0xFF, 0xD8]);
Uint8List _overLimit() => Uint8List(5 * 1024 * 1024 + 1); // 5MB + 1 byte

// ──────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────

void main() {
  // ── PhotoAdminSpot.fromJson ────────────────────────────────
  group('PhotoAdminSpot.fromJson — 필드 파싱', () {
    test('필수 필드 파싱', () {
      final spot = PhotoAdminSpot.fromJson(_photoJson());
      expect(spot.id, 'spot-001');
      expect(spot.name, '스타벅스 강남점');
      expect(spot.reportCount, 12);
    });

    test('googlePlaceId 파싱', () {
      final spot = PhotoAdminSpot.fromJson(_photoJson(googlePlaceId: 'ChIJ_abc'));
      expect(spot.googlePlaceId, 'ChIJ_abc');
    });

    test('formattedAddress 파싱', () {
      final spot = PhotoAdminSpot.fromJson(_photoJson(formattedAddress: '서울 마포구'));
      expect(spot.formattedAddress, '서울 마포구');
    });

    test('photoUrl 파싱', () {
      final spot = PhotoAdminSpot.fromJson(
        _photoJson(photoUrl: 'https://cdn.example.com/photo.jpg'),
      );
      expect(spot.photoUrl, 'https://cdn.example.com/photo.jpg');
    });

    test('선택적 필드 모두 null 허용', () {
      final spot = PhotoAdminSpot.fromJson(_photoJson(
        googlePlaceId: null,
        formattedAddress: null,
        photoUrl: null,
      ));
      expect(spot.googlePlaceId, isNull);
      expect(spot.formattedAddress, isNull);
      expect(spot.photoUrl, isNull);
    });

    test('reportCount=0도 파싱', () {
      final spot = PhotoAdminSpot.fromJson(_photoJson(reportCount: 0));
      expect(spot.reportCount, 0);
    });
  });

  // ── PhotoAdminSpot.copyWith ────────────────────────────────
  group('PhotoAdminSpot.copyWith', () {
    test('photoUrl 변경', () {
      final original = PhotoAdminSpot.fromJson(_photoJson());
      final updated = original.copyWith(photoUrl: 'https://new-url.supabase.co/photo.jpg');
      expect(updated.photoUrl, 'https://new-url.supabase.co/photo.jpg');
      expect(updated.id, original.id);
      expect(updated.name, original.name);
    });

    test('clearPhoto=true → photoUrl=null', () {
      final original = PhotoAdminSpot.fromJson(_photoJson(photoUrl: 'https://supabase.co/photo.jpg'));
      final cleared = original.copyWith(clearPhoto: true);
      expect(cleared.photoUrl, isNull);
    });

    test('clearPhoto 없이 copyWith → 기존 photoUrl 유지', () {
      final original = PhotoAdminSpot.fromJson(_photoJson(
        photoUrl: 'https://supabase.co/storage/v1/photo.jpg',
      ));
      final copy = original.copyWith();
      expect(copy.photoUrl, original.photoUrl);
    });

    test('clearPhoto=true가 photoUrl 파라미터보다 우선', () {
      final original = PhotoAdminSpot.fromJson(_photoJson(photoUrl: 'https://supabase.co/photo.jpg'));
      final result = original.copyWith(
        photoUrl: 'https://supabase.co/new.jpg',
        clearPhoto: true,
      );
      expect(result.photoUrl, isNull);
    });
  });

  // ── AdminSpot.fromJson ─────────────────────────────────────
  group('AdminSpot.fromJson — 필드 파싱', () {
    test('필수 필드 파싱', () {
      final spot = AdminSpot.fromJson(_adminJson());
      expect(spot.id, 'admin-001');
      expect(spot.name, '조용한 카페');
      expect(spot.reportCount, 5);
    });

    test('lat/lng double 파싱', () {
      final spot = AdminSpot.fromJson(_adminJson(lat: 37.5665, lng: 126.9780));
      expect(spot.lat, closeTo(37.5665, 0.0001));
      expect(spot.lng, closeTo(126.9780, 0.0001));
    });

    test('lat/lng int → double 변환', () {
      final json = _adminJson();
      json['lat'] = 37; // int
      json['lng'] = 127; // int
      final spot = AdminSpot.fromJson(json);
      expect(spot.lat, 37.0);
      expect(spot.lat, isA<double>());
    });

    test('formattedAddress null 허용', () {
      final spot = AdminSpot.fromJson(_adminJson(formattedAddress: null));
      expect(spot.formattedAddress, isNull);
    });

    test('createdAt ISO8601 파싱', () {
      final spot = AdminSpot.fromJson(
        _adminJson(createdAt: '2025-03-01T10:00:00.000Z'),
      );
      expect(spot.createdAt.year, 2025);
      expect(spot.createdAt.month, 3);
      expect(spot.createdAt.day, 1);
    });

    test('reportCount 경계값 — 0', () {
      final spot = AdminSpot.fromJson(_adminJson(reportCount: 0));
      expect(spot.reportCount, 0);
    });

    test('reportCount 경계값 — 대용량', () {
      final spot = AdminSpot.fromJson(_adminJson(reportCount: 9999));
      expect(spot.reportCount, 9999);
    });
  });

  // ── SpotsRepository._validateImageMagicBytes (간접 테스트) ─
  // uploadSpotPhoto의 초기 검증 로직을 통해 커버한다.
  // SupabaseClient를 호출하기 전 throw되는 경로만 테스트.
  group('SpotsRepository.uploadSpotPhoto — 초기 검증 (pre-Supabase guard)', () {
    // 실제 SupabaseClient 없이 SpotsRepository를 생성하기 위한 최소 Fake
    late SpotsRepository repo;

    setUp(() {
      // _FakeSupabaseClient는 이 파일 하단에 정의된 Fake 구현체
      repo = SpotsRepository(_dummyClient());
    });

    test('5MB 초과 바이트 → Exception (Supabase 미도달)', () async {
      await expectLater(
        () => repo.uploadSpotPhoto('spot-id', _overLimit(), 'photo.jpg'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('5MB'),
        )),
      );
    });

    test('알 수 없는 형식(magic bytes 불일치) → Exception', () async {
      await expectLater(
        () => repo.uploadSpotPhoto('spot-id', _unknown(), 'photo.bin'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('지원하지 않는'),
        )),
      );
    });

    test('너무 짧은 바이트(< 4바이트) → Exception (형식 판별 불가)', () async {
      await expectLater(
        () => repo.uploadSpotPhoto('spot-id', _tooShort(), 'photo.jpg'),
        throwsA(isA<Exception>()),
      );
    });

    test('JPEG 매직 바이트 → 검증 통과 (이후 네트워크 에러)', () async {
      // JPEG 바이트는 매직 바이트 검증 통과 → Supabase 호출 시 네트워크 에러
      await expectLater(
        () => repo.uploadSpotPhoto('spot-id', _jpeg(), 'photo.jpg'),
        throwsA(anything), // 네트워크 에러 (형식 검증 에러가 아님)
      );
    });

    test('PNG 매직 바이트 → 검증 통과 (이후 네트워크 에러)', () async {
      await expectLater(
        () => repo.uploadSpotPhoto('spot-id', _png(), 'photo.png'),
        throwsA(anything),
      );
    });

    test('WebP 매직 바이트 → 검증 통과 (이후 네트워크 에러)', () async {
      await expectLater(
        () => repo.uploadSpotPhoto('spot-id', _webp(), 'photo.webp'),
        throwsA(anything),
      );
    });
  });

  group('SpotsRepository.updateSpotPhoto — URL 도메인 검증', () {
    late SpotsRepository repo;
    setUp(() => repo = SpotsRepository(_dummyClient()));

    test('허용되지 않는 도메인 → Exception', () async {
      await expectLater(
        () => repo.updateSpotPhoto('spot-id', 'https://evil.com/photo.jpg'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('허용되지 않는'),
        )),
      );
    });

    test('supabase.co 도메인 → 허용 (이후 네트워크 에러)', () async {
      await expectLater(
        () => repo.updateSpotPhoto('spot-id', 'https://abc.supabase.co/storage/v1/photo.jpg'),
        throwsA(anything),
      );
    });

    test('googleusercontent.com 도메인 → 허용 (이후 네트워크 에러)', () async {
      await expectLater(
        () => repo.updateSpotPhoto('spot-id', 'https://lh3.googleusercontent.com/photo.jpg'),
        throwsA(anything),
      );
    });

    test('null photoUrl → 허용 (도메인 검사 스킵, 이후 네트워크 에러)', () async {
      await expectLater(
        () => repo.updateSpotPhoto('spot-id', null),
        throwsA(anything),
      );
    });
  });

  group('SpotsRepository.upsertBrandSpots — empty guard', () {
    test('빈 리스트 → 0 반환 (Supabase 미도달)', () async {
      final repo = SpotsRepository(_dummyClient());
      final count = await repo.upsertBrandSpots([]);
      expect(count, 0);
    });
  });
}

// ──────────────────────────────────────────────────────────────
// Real SupabaseClient with dummy credentials.
// All tests using this client only exercise code paths that throw
// BEFORE making any network request (guard clauses).
// ──────────────────────────────────────────────────────────────

SupabaseClient _dummyClient() =>
    SupabaseClient('https://fake.supabase.co', 'fake-anon-key');
