import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:cafe_vibe/core/services/places_service.dart';

// ──────────────────────────────────────────────────────────────
// Mock HTTP client — returns StreamedResponse with utf8-encoded body
// so Korean characters in JSON don't cause Latin-1 encoding errors.
// ──────────────────────────────────────────────────────────────

typedef _StreamHandler = Future<http.StreamedResponse> Function(http.BaseRequest);

class _MockClient extends http.BaseClient {
  final _StreamHandler handler;
  _MockClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => handler(request);
}

http.StreamedResponse _ok(String jsonBody) => http.StreamedResponse(
      Stream.fromIterable([utf8.encode(jsonBody)]),
      200,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );

http.StreamedResponse _err(int code) =>
    http.StreamedResponse(Stream.fromIterable([]), code);

PlacesService _svc(_StreamHandler h) => PlacesService(client: _MockClient(h));

// ──────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────

void main() {
  // ── autocomplete ──────────────────────────────────────────
  group('PlacesService.autocomplete', () {
    test('빈(공백만) 입력 → HTTP 호출 없이 빈 리스트 반환', () async {
      var called = false;
      final svc = _svc((_) async {
        called = true;
        return _ok('');
      });
      expect(await svc.autocomplete('  '), isEmpty);
      expect(called, isFalse);
    });

    test('정상 응답 — structured_formatting 포함 predictions 파싱', () async {
      final body = jsonEncode({
        'status': 'OK',
        'predictions': [
          {
            'place_id': 'place_001',
            'structured_formatting': {
              'main_text': '스타벅스 강남점',
              'secondary_text': '서울 강남구',
            },
          },
          {
            'place_id': 'place_002',
            'structured_formatting': {
              'main_text': '메가커피 종로점',
              'secondary_text': '서울 종로구',
            },
          },
        ],
      });
      final svc = _svc((_) async => _ok(body));
      final result = await svc.autocomplete('스타벅스');
      expect(result.length, 2);
      expect(result[0].placeId, 'place_001');
      expect(result[0].mainText, '스타벅스 강남점');
      expect(result[0].secondaryText, '서울 강남구');
    });

    test('structured_formatting 없을 때 description fallback', () async {
      final body = jsonEncode({
        'status': 'OK',
        'predictions': [
          {
            'place_id': 'place_003',
            'description': '카페베이지 홍대점',
            'structured_formatting': {},
          },
        ],
      });
      final svc = _svc((_) async => _ok(body));
      final result = await svc.autocomplete('카페');
      expect(result[0].mainText, '카페베이지 홍대점');
      expect(result[0].secondaryText, '');
    });

    test('predictions 빈 배열 → 빈 리스트', () async {
      final body = jsonEncode({'status': 'ZERO_RESULTS', 'predictions': []});
      final svc = _svc((_) async => _ok(body));
      expect(await svc.autocomplete('없는검색어'), isEmpty);
    });

    test('HTTP 500 오류 → 빈 리스트', () async {
      final svc = _svc((_) async => _err(500));
      expect(await svc.autocomplete('test'), isEmpty);
    });

    test('네트워크 예외(timeout 등) → 빈 리스트', () async {
      final svc = _svc((_) => Future.error(const _FakeException('timeout')));
      expect(await svc.autocomplete('test'), isEmpty);
    });

    test('lat/lng 제공 시 요청 URL에 location 파라미터 포함', () async {
      Uri? captured;
      final body = jsonEncode({'status': 'OK', 'predictions': []});
      final svc = _svc((req) async {
        captured = req.url;
        return _ok(body);
      });
      await svc.autocomplete('test', lat: 37.5, lng: 127.0);
      expect(captured?.queryParameters['location'], '37.5,127.0');
      expect(captured?.queryParameters['radius'], '50000');
    });

    test('lat/lng 없을 때 location 파라미터 미포함', () async {
      Uri? captured;
      final body = jsonEncode({'status': 'OK', 'predictions': []});
      final svc = _svc((req) async {
        captured = req.url;
        return _ok(body);
      });
      await svc.autocomplete('test');
      expect(captured?.queryParameters.containsKey('location'), isFalse);
    });
  });

  // ── getDetails ────────────────────────────────────────────
  group('PlacesService.getDetails', () {
    test('정상 응답 — lat/lng 파싱', () async {
      final body = jsonEncode({
        'status': 'OK',
        'result': {
          'geometry': {
            'location': {'lat': 37.5665, 'lng': 126.9780},
          },
        },
      });
      final svc = _svc((_) async => _ok(body));
      final result = await svc.getDetails('ChIJ_test');
      expect(result, isNotNull);
      expect(result!.lat, closeTo(37.5665, 0.0001));
      expect(result.lng, closeTo(126.9780, 0.0001));
    });

    test('HTTP 오류 → null', () async {
      final svc = _svc((_) async => _err(500));
      expect(await svc.getDetails('ChIJ_test'), isNull);
    });

    test('result 없음(geometry 없음) → null', () async {
      final body = jsonEncode({'status': 'OK', 'result': {}});
      final svc = _svc((_) async => _ok(body));
      expect(await svc.getDetails('ChIJ_test'), isNull);
    });

    test('geometry location 없음 → null', () async {
      final body = jsonEncode({
        'status': 'OK',
        'result': {'geometry': {}},
      });
      final svc = _svc((_) async => _ok(body));
      expect(await svc.getDetails('ChIJ_test'), isNull);
    });

    test('네트워크 예외 → null', () async {
      final svc = _svc((_) => Future.error(const _FakeException('timeout')));
      expect(await svc.getDetails('ChIJ_test'), isNull);
    });
  });

  // ── geocodeAddress ────────────────────────────────────────
  group('PlacesService.geocodeAddress', () {
    test('빈(공백) 주소 → HTTP 호출 없이 null', () async {
      var called = false;
      final svc = _svc((_) async {
        called = true;
        return _ok('');
      });
      expect(await svc.geocodeAddress('   '), isNull);
      expect(called, isFalse);
    });

    test('정상 응답 — 좌표 파싱', () async {
      final body = jsonEncode({
        'status': 'OK',
        'results': [
          {
            'geometry': {
              'location': {'lat': 37.5546, 'lng': 126.9706},
            },
          },
        ],
      });
      final svc = _svc((_) async => _ok(body));
      final result = await svc.geocodeAddress('서울역');
      expect(result, isNotNull);
      expect(result!.lat, closeTo(37.5546, 0.001));
      expect(result.lng, closeTo(126.9706, 0.001));
    });

    test('status ZERO_RESULTS → null', () async {
      final body = jsonEncode({'status': 'ZERO_RESULTS', 'results': []});
      final svc = _svc((_) async => _ok(body));
      expect(await svc.geocodeAddress('존재하지않는주소xyz'), isNull);
    });

    test('results 빈 배열 → null', () async {
      final body = jsonEncode({'status': 'OK', 'results': []});
      final svc = _svc((_) async => _ok(body));
      expect(await svc.geocodeAddress('서울역'), isNull);
    });

    test('HTTP 오류 → null', () async {
      final svc = _svc((_) async => _err(500));
      expect(await svc.geocodeAddress('서울역'), isNull);
    });

    test('네트워크 예외 → null', () async {
      final svc = _svc((_) => Future.error(const _FakeException('timeout')));
      expect(await svc.geocodeAddress('서울역'), isNull);
    });
  });

  // ── nearbyBrandCafes ──────────────────────────────────────
  group('PlacesService.nearbyBrandCafes', () {
    test('브랜드 카페만 필터링 — 스타벅스 포함/개인 카페 제외', () async {
      final body = jsonEncode({
        'status': 'OK',
        'results': [
          {
            'place_id': 'brand_001',
            'name': '스타벅스 강남역점',
            'geometry': {'location': {'lat': 37.498, 'lng': 127.028}},
          },
          {
            'place_id': 'indie_001',
            'name': '작은 개인 카페',
            'geometry': {'location': {'lat': 37.499, 'lng': 127.029}},
          },
        ],
      });
      final svc = _svc((_) async => _ok(body));
      final result = await svc.nearbyBrandCafes(lat: 37.5, lng: 127.0);
      expect(result.length, 1);
      expect(result[0].name, '스타벅스 강남역점');
      expect(result[0].placeId, 'brand_001');
    });

    test('메가커피 — 브랜드로 인식', () async {
      final body = jsonEncode({
        'status': 'OK',
        'results': [
          {
            'place_id': 'mega_001',
            'name': '메가MGC커피 홍대점',
            'geometry': {'location': {'lat': 37.555, 'lng': 126.923}},
          },
        ],
      });
      final svc = _svc((_) async => _ok(body));
      final result = await svc.nearbyBrandCafes(lat: 37.5, lng: 127.0);
      expect(result.length, 1);
    });

    test('geometry 없는 결과는 무시', () async {
      final body = jsonEncode({
        'status': 'OK',
        'results': [
          {
            'place_id': 'brand_002',
            'name': 'Starbucks no-geo',
            // geometry 없음
          },
        ],
      });
      final svc = _svc((_) async => _ok(body));
      final result = await svc.nearbyBrandCafes(lat: 37.5, lng: 127.0);
      expect(result, isEmpty);
    });

    test('ZERO_RESULTS → 빈 리스트', () async {
      final body = jsonEncode({'status': 'ZERO_RESULTS', 'results': []});
      final svc = _svc((_) async => _ok(body));
      expect(await svc.nearbyBrandCafes(lat: 37.5, lng: 127.0), isEmpty);
    });

    test('HTTP 오류 → 빈 리스트', () async {
      final svc = _svc((_) async => _err(500));
      expect(await svc.nearbyBrandCafes(lat: 37.5, lng: 127.0), isEmpty);
    });

    test('네트워크 예외 → 빈 리스트', () async {
      final svc = _svc((_) => Future.error(const _FakeException('fail')));
      expect(await svc.nearbyBrandCafes(lat: 37.5, lng: 127.0), isEmpty);
    });

    test('radiusMeters 파라미터 URL에 반영', () async {
      Uri? captured;
      final body = jsonEncode({'status': 'OK', 'results': []});
      final svc = _svc((req) async {
        captured = req.url;
        return _ok(body);
      });
      await svc.nearbyBrandCafes(lat: 37.5, lng: 127.0, radiusMeters: 5000);
      expect(captured?.queryParameters['radius'], '5000');
    });
  });

  // ── nearbyCafes ───────────────────────────────────────────
  group('PlacesService.nearbyCafes', () {
    test('단일 페이지 — 모든 카페 반환 (브랜드 필터 없음)', () async {
      final body = jsonEncode({
        'status': 'OK',
        'results': [
          {
            'place_id': 'cafe_001',
            'name': '카페A',
            'geometry': {'location': {'lat': 37.500, 'lng': 127.000}},
            'vicinity': '서울 강남구',
          },
          {
            'place_id': 'cafe_002',
            'name': '카페B',
            'geometry': {'location': {'lat': 37.501, 'lng': 127.001}},
            // vicinity 없음 → null
          },
        ],
      });
      final svc = _svc((_) async => _ok(body));
      final result = await svc.nearbyCafes(lat: 37.5, lng: 127.0);
      expect(result.length, 2);
      expect(result[0].placeId, 'cafe_001');
      expect(result[0].formattedAddress, '서울 강남구');
      expect(result[1].placeId, 'cafe_002');
      expect(result[1].formattedAddress, isNull);
    });

    test('ZERO_RESULTS → 빈 리스트', () async {
      final body = jsonEncode({'status': 'ZERO_RESULTS', 'results': []});
      final svc = _svc((_) async => _ok(body));
      expect(await svc.nearbyCafes(lat: 37.5, lng: 127.0), isEmpty);
    });

    test('geometry 없는 결과는 무시', () async {
      final body = jsonEncode({
        'status': 'OK',
        'results': [
          {
            'place_id': 'cafe_no_geo',
            'name': '위치없는카페',
            // geometry 없음
          },
        ],
      });
      final svc = _svc((_) async => _ok(body));
      final result = await svc.nearbyCafes(lat: 37.5, lng: 127.0);
      expect(result, isEmpty);
    });

    test('HTTP 오류 → 빈 리스트', () async {
      final svc = _svc((_) async => _err(500));
      expect(await svc.nearbyCafes(lat: 37.5, lng: 127.0), isEmpty);
    });

    test('status 오류 코드 → 빈 리스트', () async {
      final body = jsonEncode({'status': 'REQUEST_DENIED', 'results': []});
      final svc = _svc((_) async => _ok(body));
      expect(await svc.nearbyCafes(lat: 37.5, lng: 127.0), isEmpty);
    });

    test('네트워크 예외 → 빈 리스트', () async {
      final svc = _svc((_) => Future.error(const _FakeException('fail')));
      expect(await svc.nearbyCafes(lat: 37.5, lng: 127.0), isEmpty);
    });
  });

  // ── getPhotoUrl ───────────────────────────────────────────
  group('PlacesService.getPhotoUrl', () {
    test('빌드 시 MAPS_API_KEY 미설정(빈 문자열) → HTTP 호출 없이 null 반환', () async {
      // In test environment: String.fromEnvironment('MAPS_API_KEY') == ''
      // → getPhotoUrl() returns null immediately without HTTP call
      var called = false;
      final svc = _svc((_) async {
        called = true;
        return _ok('');
      });
      final result = await svc.getPhotoUrl('ChIJ_test');
      expect(result, isNull);
      expect(called, isFalse, reason: 'API 키 없으면 HTTP 호출 하지 않아야 함');
    });
  });

  // ── PlacePrediction / PlaceLatLng / PlaceResult 모델 ──────
  group('PlacePrediction 모델', () {
    test('필드 저장 확인', () {
      const p = PlacePrediction(
        placeId: 'id_001',
        mainText: '스타벅스',
        secondaryText: '강남구',
      );
      expect(p.placeId, 'id_001');
      expect(p.mainText, '스타벅스');
      expect(p.secondaryText, '강남구');
    });
  });

  group('PlaceLatLng 모델', () {
    test('lat/lng 필드 저장 확인', () {
      const ll = PlaceLatLng(lat: 37.5665, lng: 126.9780);
      expect(ll.lat, 37.5665);
      expect(ll.lng, 126.9780);
    });
  });

  group('PlaceResult 모델', () {
    test('필수 필드 저장 확인', () {
      const r = PlaceResult(
        placeId: 'res_001',
        name: '메가커피',
        lat: 37.0,
        lng: 127.0,
      );
      expect(r.placeId, 'res_001');
      expect(r.formattedAddress, isNull);
    });

    test('선택 필드(formattedAddress) 저장 확인', () {
      const r = PlaceResult(
        placeId: 'res_002',
        name: '카페',
        lat: 37.0,
        lng: 127.0,
        formattedAddress: '서울 강남구',
      );
      expect(r.formattedAddress, '서울 강남구');
    });
  });
}

// ── Network error stub ────────────────────────────────────────
class _FakeException implements Exception {
  final String message;
  const _FakeException(this.message);
}
