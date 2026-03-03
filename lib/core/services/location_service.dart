import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/map_constants.dart';

class LocationService {
  /// Request location permission and return current position.
  /// Throws [LocationException] if permission denied or service disabled.
  static Future<Position> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationException('위치 서비스가 비활성화되어 있습니다.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationException('위치 권한이 거부되었습니다.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationException('위치 권한이 영구 거부되었습니다. 설정에서 허용해 주세요.');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  /// Returns true if [targetLat]/[targetLng] is within [MapConstants.reportMaxDistanceMeters]
  /// of the user's current position [userLat]/[userLng].
  static bool isWithinReportRadius({
    required double userLat,
    required double userLng,
    required double targetLat,
    required double targetLng,
  }) {
    final distance = _haversineDistance(userLat, userLng, targetLat, targetLng);
    return distance <= MapConstants.reportMaxDistanceMeters;
  }

  /// Returns the haversine distance in metres between user and target.
  static double distanceMeters({
    required double userLat,
    required double userLng,
    required double targetLat,
    required double targetLng,
  }) {
    return _haversineDistance(userLat, userLng, targetLat, targetLng);
  }

  /// Haversine distance in metres between two lat/lng coordinates.
  static double _haversineDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const R = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  static double _toRad(double deg) => deg * math.pi / 180;
}

class LocationException implements Exception {
  final String message;
  LocationException(this.message);
  @override
  String toString() => message;
}

/// Riverpod provider that exposes the current GPS position.
final currentPositionProvider = FutureProvider<Position>((ref) async {
  return LocationService.getCurrentPosition();
});
