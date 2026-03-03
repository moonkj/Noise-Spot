import 'package:flutter_test/flutter_test.dart';
import 'package:cafe_vibe/features/admin/data/cafe_requests_repository.dart';

// ──────────────────────────────────────────────────────────────
// Helper: 완전한 JSON 맵 (모든 필드 포함)
// ──────────────────────────────────────────────────────────────

Map<String, dynamic> _fullJson({
  String id = 'req-001',
  String userId = 'user-abc',
  String cafeName = '스타벅스 강남점',
  String address = '서울특별시 강남구 테헤란로 1',
  String note = '이 카페를 추가해주세요',
  String status = 'pending',
  String createdAt = '2024-03-15T10:30:00.000Z',
}) =>
    {
      'id': id,
      'user_id': userId,
      'cafe_name': cafeName,
      'address': address,
      'note': note,
      'status': status,
      'created_at': createdAt,
    };

void main() {
  // ── CafeRequest.fromJson — 필드 파싱 ──────────────────────
  group('CafeRequest.fromJson — 전체 필드 파싱', () {
    test('id 필드가 올바르게 파싱된다', () {
      final req = CafeRequest.fromJson(_fullJson(id: 'abc-123'));
      expect(req.id, 'abc-123');
    });

    test('user_id 필드가 올바르게 파싱된다', () {
      final req = CafeRequest.fromJson(_fullJson(userId: 'uid-xyz'));
      expect(req.userId, 'uid-xyz');
    });

    test('cafe_name 필드가 올바르게 파싱된다', () {
      final req = CafeRequest.fromJson(_fullJson(cafeName: '이디야 서초점'));
      expect(req.cafeName, '이디야 서초점');
    });

    test('address 필드가 올바르게 파싱된다', () {
      final req = CafeRequest.fromJson(_fullJson(address: '서울특별시 서초구 반포대로 1'));
      expect(req.address, '서울특별시 서초구 반포대로 1');
    });

    test('note 필드가 올바르게 파싱된다', () {
      final req = CafeRequest.fromJson(_fullJson(note: '빠른 추가 부탁드립니다'));
      expect(req.note, '빠른 추가 부탁드립니다');
    });

    test('status 필드가 올바르게 파싱된다', () {
      final req = CafeRequest.fromJson(_fullJson(status: 'rejected'));
      expect(req.status, 'rejected');
    });

    test('created_at이 DateTime으로 파싱된다', () {
      final req = CafeRequest.fromJson(
        _fullJson(createdAt: '2024-01-15T09:00:00.000Z'),
      );
      expect(req.createdAt.year, 2024);
      expect(req.createdAt.month, 1);
      expect(req.createdAt.day, 15);
    });
  });

  group('CafeRequest.fromJson — null 허용 필드', () {
    test('user_id=null → userId=null', () {
      final json = _fullJson()..remove('user_id');
      json['user_id'] = null;
      final req = CafeRequest.fromJson(json);
      expect(req.userId, isNull);
    });

    test('address=null → address=null', () {
      final json = _fullJson()..remove('address');
      json['address'] = null;
      final req = CafeRequest.fromJson(json);
      expect(req.address, isNull);
    });

    test('note=null → note=null', () {
      final json = _fullJson()..remove('note');
      json['note'] = null;
      final req = CafeRequest.fromJson(json);
      expect(req.note, isNull);
    });

    test('address와 note 모두 null인 경우 파싱 성공', () {
      final json = {
        'id': 'req-min',
        'user_id': null,
        'cafe_name': '미니멈 카페',
        'address': null,
        'note': null,
        'status': 'pending',
        'created_at': '2024-06-01T00:00:00.000Z',
      };
      final req = CafeRequest.fromJson(json);
      expect(req.id, 'req-min');
      expect(req.userId, isNull);
      expect(req.address, isNull);
      expect(req.note, isNull);
    });
  });

  group('CafeRequest.fromJson — status 값 다양성', () {
    test('status=pending 파싱', () {
      final req = CafeRequest.fromJson(_fullJson(status: 'pending'));
      expect(req.status, 'pending');
    });

    test('status=approved 파싱', () {
      final req = CafeRequest.fromJson(_fullJson(status: 'approved'));
      expect(req.status, 'approved');
    });

    test('status=rejected 파싱', () {
      final req = CafeRequest.fromJson(_fullJson(status: 'rejected'));
      expect(req.status, 'rejected');
    });
  });

  group('CafeRequest.fromJson — DateTime 엣지 케이스', () {
    test('밀리초 포함 ISO 8601 파싱', () {
      final req = CafeRequest.fromJson(
        _fullJson(createdAt: '2025-12-31T23:59:59.999Z'),
      );
      expect(req.createdAt.year, 2025);
      expect(req.createdAt.month, 12);
      expect(req.createdAt.day, 31);
    });

    test('한국 시간대 오프셋(+09:00) 파싱', () {
      // DateTime.parse는 오프셋 포함 ISO 8601을 지원한다
      final req = CafeRequest.fromJson(
        _fullJson(createdAt: '2024-07-04T12:00:00+09:00'),
      );
      // UTC로 변환되므로 day/hour 검증은 타임존 의존 — 파싱 성공만 확인
      expect(req.createdAt, isA<DateTime>());
    });
  });
}
