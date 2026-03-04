import 'package:flutter_test/flutter_test.dart';
import 'package:cafe_vibe/core/services/admin_dummy_service.dart';

void main() {
  group('AdminDummyService — 상수', () {
    test('gangnamLat는 강남역 위도', () {
      expect(AdminDummyService.gangnamLat, closeTo(37.4979, 0.001));
    });

    test('gangnamLng는 강남역 경도', () {
      expect(AdminDummyService.gangnamLng, closeTo(127.0276, 0.001));
    });
  });

  group('gangnamPosition()', () {
    test('위도/경도가 강남역 좌표', () {
      final pos = gangnamPosition();
      expect(pos.latitude, closeTo(37.4979, 0.001));
      expect(pos.longitude, closeTo(127.0276, 0.001));
    });

    test('isMocked=true (더미 위치임을 표시)', () {
      final pos = gangnamPosition();
      expect(pos.isMocked, isTrue);
    });

    test('accuracy=1.0 (정밀 더미)', () {
      final pos = gangnamPosition();
      expect(pos.accuracy, 1.0);
    });

    test('speed/heading/altitude은 0.0', () {
      final pos = gangnamPosition();
      expect(pos.speed, 0.0);
      expect(pos.heading, 0.0);
      expect(pos.altitude, 0.0);
    });

    test('timestamp는 현재 시각 근처 (10초 이내)', () {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      final pos = gangnamPosition();
      final after = DateTime.now().add(const Duration(seconds: 1));
      expect(pos.timestamp.isAfter(before), isTrue);
      expect(pos.timestamp.isBefore(after), isTrue);
    });
  });
}
