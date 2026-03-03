import 'dart:async';
import 'package:noise_meter/noise_meter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// First-launch microphone calibration.
/// Samples for 3 seconds to compute an ambient-noise offset,
/// then stores it in SharedPreferences for subsequent dB corrections.
class CalibrationService {
  static const String _offsetKey = 'mic_offset';
  static const Duration _sampleDuration = Duration(seconds: 3);

  /// Run calibration and return the measured offset (ambient baseline dB).
  Future<double> calibrate() async {
    final readings = <double>[];
    final meter = NoiseMeter();
    StreamSubscription? sub;

    final completer = Completer<void>();
    sub = meter.noise.listen(
      (NoiseReading reading) {
        if (reading.meanDecibel >= 0 &&
            reading.meanDecibel < 120 &&
            reading.meanDecibel.isFinite) {
          readings.add(reading.meanDecibel);
        }
      },
      onError: (_) => completer.complete(),
    );

    await Future.delayed(_sampleDuration);
    await sub.cancel();

    final offset = readings.isEmpty
        ? 0.0
        : readings.reduce((a, b) => a + b) / readings.length;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_offsetKey, offset);
    await prefs.setBool('calibration_done', true);

    return offset;
  }

  /// Returns the stored mic offset, defaulting to 0.
  static Future<double> getOffset() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_offsetKey) ?? 0.0;
  }

  /// Returns true if calibration has been completed previously.
  static Future<bool> isCalibrated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('calibration_done') ?? false;
  }

  /// Clears calibration data (call on account reset).
  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_offsetKey);
    await prefs.remove('calibration_done');
  }
}
