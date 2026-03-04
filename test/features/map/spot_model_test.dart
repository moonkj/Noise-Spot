import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cafe_vibe/features/map/domain/spot_model.dart';
import 'package:cafe_vibe/core/constants/map_constants.dart';

// ──────────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────────

Map<String, dynamic> _baseJson({
  String id = 'spot-001',
  String name = '조용한 카페',
  String? googlePlaceId = 'ChIJ_test',
  String? formattedAddress = '서울특별시 종로구 1번지',
  double lat = 37.5759,
  double lng = 126.9769,
  double averageDb = 52.5,
  String? representativeSticker,
  int reportCount = 10,
  double trustScore = 2.0,
  int recent24hCount = 3,
  String? lastReportAt,
}) =>
    {
      'id': id,
      'name': name,
      'google_place_id': googlePlaceId,
      'formatted_address': formattedAddress,
      'lat': lat,
      'lng': lng,
      'average_db': averageDb,
      'representative_sticker': representativeSticker,
      'report_count': reportCount,
      'trust_score': trustScore,
      'recent_24h_count': recent24hCount,
      'last_report_at': lastReportAt,
    };

// ──────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────

void main() {
  // ── SpotModel.fromJson ────────────────────────────────────
  group('SpotModel.fromJson — 기본 파싱', () {
    test('필수 필드 파싱', () {
      final spot = SpotModel.fromJson(_baseJson());
      expect(spot.id, 'spot-001');
      expect(spot.name, '조용한 카페');
      expect(spot.lat, 37.5759);
      expect(spot.lng, 126.9769);
      expect(spot.averageDb, 52.5);
      expect(spot.reportCount, 10);
      expect(spot.trustScore, 2.0);
      expect(spot.recent24hCount, 3);
    });

    test('선택적 필드 — null 허용', () {
      final spot = SpotModel.fromJson(_baseJson(
        googlePlaceId: null,
        formattedAddress: null,
        representativeSticker: null,
        lastReportAt: null,
      ));
      expect(spot.googlePlaceId, isNull);
      expect(spot.formattedAddress, isNull);
      expect(spot.representativeSticker, isNull);
      expect(spot.lastReportAt, isNull);
    });

    test('recent_24h_count 누락 시 0으로 기본값', () {
      final json = _baseJson();
      json.remove('recent_24h_count');
      final spot = SpotModel.fromJson(json);
      expect(spot.recent24hCount, 0);
    });

    test('representativeSticker — 유효한 키 파싱', () {
      final spot = SpotModel.fromJson(_baseJson(representativeSticker: 'STUDY'));
      expect(spot.representativeSticker, StickerType.study);
    });

    test('representativeSticker — RELAX 파싱', () {
      final spot = SpotModel.fromJson(_baseJson(representativeSticker: 'RELAX'));
      expect(spot.representativeSticker, StickerType.relax);
    });

    test('lastReportAt — ISO8601 파싱', () {
      final spot = SpotModel.fromJson(
        _baseJson(lastReportAt: '2025-03-01T10:00:00.000Z'),
      );
      expect(spot.lastReportAt, isNotNull);
      expect(spot.lastReportAt!.year, 2025);
      expect(spot.lastReportAt!.month, 3);
      expect(spot.lastReportAt!.day, 1);
    });

    test('averageDb: int 형태 num도 double로 변환', () {
      final json = _baseJson();
      json['average_db'] = 60; // int
      final spot = SpotModel.fromJson(json);
      expect(spot.averageDb, 60.0);
      expect(spot.averageDb, isA<double>());
    });
  });

  // ── SpotModel.isStale ─────────────────────────────────────
  group('SpotModel.isStale — 데이터 신선도', () {
    test('lastReportAt=null → isStale=true', () {
      final spot = SpotModel.fromJson(_baseJson(lastReportAt: null));
      expect(spot.isStale, isTrue);
    });

    test('오래된 리포트(spotFadeAfterDays 초과) → isStale=true', () {
      final old = DateTime.now()
          .subtract(Duration(days: MapConstants.spotFadeAfterDays + 1));
      final spot = SpotModel.fromJson(
        _baseJson(lastReportAt: old.toIso8601String()),
      );
      expect(spot.isStale, isTrue);
    });

    test('최근 리포트(spotFadeAfterDays 미만) → isStale=false', () {
      final recent = DateTime.now().subtract(const Duration(days: 1));
      final spot = SpotModel.fromJson(
        _baseJson(lastReportAt: recent.toIso8601String()),
      );
      expect(spot.isStale, isFalse);
    });
  });

  // ── SpotModel.markerOpacity ───────────────────────────────
  group('SpotModel.markerOpacity', () {
    test('활성 스팟 → 1.0', () {
      final recent = DateTime.now().subtract(const Duration(hours: 1));
      final spot = SpotModel.fromJson(
        _baseJson(lastReportAt: recent.toIso8601String()),
      );
      expect(spot.markerOpacity, 1.0);
    });

    test('오래된 스팟 → 0.4', () {
      final old = DateTime.now()
          .subtract(Duration(days: MapConstants.spotFadeAfterDays + 5));
      final spot = SpotModel.fromJson(
        _baseJson(lastReportAt: old.toIso8601String()),
      );
      expect(spot.markerOpacity, 0.4);
    });
  });

  // ── SpotModel.markerBorderWidth ───────────────────────────
  group('SpotModel.markerBorderWidth — trustScore 기반 테두리', () {
    test('trustScore=0 (기본) → 0.5', () {
      final spot = SpotModel.fromJson(_baseJson(trustScore: 0.0));
      expect(spot.markerBorderWidth, 0.5);
    });

    test('trustScore=1.0 → 1.5', () {
      final spot = SpotModel.fromJson(_baseJson(trustScore: 1.0));
      expect(spot.markerBorderWidth, 1.5);
    });

    test('trustScore=2.0 → 2.5', () {
      final spot = SpotModel.fromJson(_baseJson(trustScore: 2.0));
      expect(spot.markerBorderWidth, 2.5);
    });

    test('trustScore=3.0 → 3.5', () {
      final spot = SpotModel.fromJson(_baseJson(trustScore: 3.0));
      expect(spot.markerBorderWidth, 3.5);
    });

    test('trustScore=5.0 → 3.5 (최대)', () {
      final spot = SpotModel.fromJson(_baseJson(trustScore: 5.0));
      expect(spot.markerBorderWidth, 3.5);
    });
  });

  // ── SpotModel.markerColor ─────────────────────────────────
  group('SpotModel.markerColor — dB 기반 색상', () {
    test('averageDb < 40 → Mint Green 계열', () {
      final spot = SpotModel.fromJson(_baseJson(averageDb: 35.0));
      expect(spot.markerColor, isA<Color>());
    });

    test('averageDb > 85 → Red 계열', () {
      final spot = SpotModel.fromJson(_baseJson(averageDb: 90.0));
      final loudSpot = SpotModel.fromJson(_baseJson(averageDb: 35.0));
      // 시끄러운 스팟과 조용한 스팟의 색상이 다르다
      expect(spot.markerColor, isNot(equals(loudSpot.markerColor)));
    });
  });

  // ── StickerType 열거형 ────────────────────────────────────
  group('StickerType — 18개 타입 존재', () {
    test('18개 타입이 정의돼 있다', () {
      expect(StickerType.values.length, 18);
    });

    test('key — DB 저장 키 대문자 형식', () {
      expect(StickerType.study.key, 'STUDY');
      expect(StickerType.meeting.key, 'MEETING');
      expect(StickerType.relax.key, 'RELAX');
      expect(StickerType.studyZone.key, 'STUDY_ZONE');
      expect(StickerType.nomad.key, 'NOMAD');
    });

    test('label — 한글 표시 이름', () {
      expect(StickerType.study.label, '딥 포커스');
      expect(StickerType.meeting.label, '소셜 버즈');
      expect(StickerType.relax.label, '소프트 바이브');
      expect(StickerType.work.label, '재택 성지');
    });

    test('emoji — 비어 있지 않다', () {
      for (final type in StickerType.values) {
        expect(type.emoji.isNotEmpty, isTrue, reason: '${type.name} emoji 누락');
      }
    });

    test('filterLabel은 label과 동일', () {
      for (final type in StickerType.values) {
        expect(type.filterLabel, type.label);
      }
    });
  });

  // ── SpotModel.photoUrl ────────────────────────────────────
  group('SpotModel — photoUrl 파싱', () {
    test('photo_url 값이 있을 때 저장', () {
      final json = _baseJson();
      json['photo_url'] = 'https://example.com/photo.jpg';
      final spot = SpotModel.fromJson(json);
      expect(spot.photoUrl, 'https://example.com/photo.jpg');
    });

    test('photo_url 키 없을 때 null', () {
      final spot = SpotModel.fromJson(_baseJson());
      expect(spot.photoUrl, isNull);
    });
  });

  // ── SpotModel == / hashCode ───────────────────────────────
  group('SpotModel.operator== / hashCode', () {
    test('같은 id → 동등', () {
      final a = SpotModel.fromJson(_baseJson(id: 'spot-eq'));
      final b = SpotModel.fromJson(_baseJson(id: 'spot-eq', averageDb: 99.0));
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('다른 id → 비동등', () {
      final a = SpotModel.fromJson(_baseJson(id: 'spot-a'));
      final b = SpotModel.fromJson(_baseJson(id: 'spot-b'));
      expect(a, isNot(equals(b)));
    });

    test('identical → 동등', () {
      final a = SpotModel.fromJson(_baseJson());
      // ignore: unrelated_type_equality_checks
      expect(a == a, isTrue);
    });

    test('non-SpotModel 타입과 비교 → false', () {
      final a = SpotModel.fromJson(_baseJson());
      // ignore: unrelated_type_equality_checks
      expect(a == 'other', isFalse);
    });
  });

  group('StickerTypeX.fromKey — 문자열 → enum 변환', () {
    test('대소문자 구분 없이 파싱', () {
      expect(StickerTypeX.fromKey('study'), StickerType.study);
      expect(StickerTypeX.fromKey('STUDY'), StickerType.study);
      expect(StickerTypeX.fromKey('Study'), StickerType.study);
    });

    test('모든 유효한 키가 올바른 타입으로 변환된다', () {
      final mapping = {
        'STUDY': StickerType.study,
        'MEETING': StickerType.meeting,
        'RELAX': StickerType.relax,
        'VIBE': StickerType.vibe,
        'HEALING': StickerType.healing,
        'WORK': StickerType.work,
        'STUDY_ZONE': StickerType.studyZone,
        'NOMAD': StickerType.nomad,
        'DATE': StickerType.date,
        'GATHERING': StickerType.gathering,
        'FAMILY': StickerType.family,
        'COZY': StickerType.cozy,
        'INSTA': StickerType.insta,
        'RETRO': StickerType.retro,
        'MINIMAL': StickerType.minimal,
        'GREEN': StickerType.green,
        'PEAK': StickerType.peak,
        'MUSIC': StickerType.music,
      };
      mapping.forEach((key, expected) {
        expect(StickerTypeX.fromKey(key), expected, reason: '$key 변환 실패');
      });
    });

    test('알 수 없는 키 → 기본값 relax', () {
      expect(StickerTypeX.fromKey('UNKNOWN'), StickerType.relax);
      expect(StickerTypeX.fromKey(''), StickerType.relax);
    });

    test('key → fromKey 왕복 변환 (round-trip)', () {
      for (final type in StickerType.values) {
        expect(StickerTypeX.fromKey(type.key), type,
            reason: '${type.key} 왕복 변환 실패');
      }
    });
  });
}
