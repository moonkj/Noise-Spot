import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cafe_vibe/core/services/calibration_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CalibrationService — 미보정 상태 (빈 SharedPreferences)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('getOffset() → 0.0 반환 (기본값)', () async {
      final offset = await CalibrationService.getOffset();
      expect(offset, 0.0);
    });

    test('isCalibrated() → false 반환', () async {
      final result = await CalibrationService.isCalibrated();
      expect(result, isFalse);
    });
  });

  group('CalibrationService — 보정 완료 상태', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'mic_offset': 38.5,
        'calibration_done': true,
      });
    });

    test('getOffset() → 저장된 offset 반환', () async {
      final offset = await CalibrationService.getOffset();
      expect(offset, 38.5);
    });

    test('isCalibrated() → true 반환', () async {
      final result = await CalibrationService.isCalibrated();
      expect(result, isTrue);
    });
  });

  group('CalibrationService — 극단값 offset', () {
    test('offset=0.0 저장 시 반환', () async {
      SharedPreferences.setMockInitialValues({'mic_offset': 0.0, 'calibration_done': true});
      final offset = await CalibrationService.getOffset();
      expect(offset, 0.0);
    });

    test('offset=119.9 저장 시 반환', () async {
      SharedPreferences.setMockInitialValues({'mic_offset': 119.9, 'calibration_done': true});
      final offset = await CalibrationService.getOffset();
      expect(offset, closeTo(119.9, 0.001));
    });

    test('mic_offset 키 없고 calibration_done=true → offset=0.0', () async {
      SharedPreferences.setMockInitialValues({'calibration_done': true});
      final offset = await CalibrationService.getOffset();
      expect(offset, 0.0);
    });
  });
}
