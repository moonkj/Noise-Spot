import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/constants/map_constants.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/places_service.dart';
import '../../../core/services/seed_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/bounds_cache.dart';
import '../data/spots_repository.dart';
import '../domain/spot_model.dart';

enum SpotDisplayMode { individual, reduced, heatmap, hidden }

class MapState {
  final List<SpotModel> spots;
  final StickerType? activeFilter;
  final bool isLoading;
  final Position? userPosition;
  final String? error;

  const MapState({
    this.spots = const [],
    this.activeFilter,
    this.isLoading = false,
    this.userPosition,
    this.error,
  });

  MapState copyWith({
    List<SpotModel>? spots,
    StickerType? activeFilter,
    bool clearFilter = false,
    bool? isLoading,
    Position? userPosition,
    String? error,
    bool clearError = false,
  }) {
    return MapState(
      spots: spots ?? this.spots,
      activeFilter: clearFilter ? null : (activeFilter ?? this.activeFilter),
      isLoading: isLoading ?? this.isLoading,
      userPosition: userPosition ?? this.userPosition,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Riverpod 3.x Notifier (replaces deprecated StateNotifier)
class MapController extends Notifier<MapState> {
  Timer? _debounceTimer;
  // Discovery cache: 30min TTL to limit Places API calls per area
  final _discoveryCache = BoundsCache(ttlSeconds: 1800);
  GoogleMapController? mapController;
  // Last position where spots were loaded — skip reload if user hasn't moved >300m
  LatLng? _lastLoadPos;

  @override
  MapState build() {
    ref.onDispose(() {
      _debounceTimer?.cancel();
      mapController?.dispose();
      mapController = null;
    });
    _initLocation();
    // Seed brand cafes from bundled JSON (runs once per install, non-blocking)
    unawaited(SeedService.seedIfNeeded(ref.read(supabaseClientProvider)));
    return const MapState();
  }

  Future<void> _initLocation() async {
    try {
      final position = await LocationService.getCurrentPosition();
      state = state.copyWith(userPosition: position);
      await _loadSpots(lat: position.latitude, lng: position.longitude);
      // Proactively discover nearby cafes on first launch (background, non-blocking)
      unawaited(_discoverNearbyCafes(lat: position.latitude, lng: position.longitude));
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Called on onCameraIdle — debounced 300ms, skips cached bounds.
  void onCameraIdle(LatLngBounds bounds, double zoom) {
    if (zoom < MapConstants.zoomMinLoad) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      const Duration(milliseconds: MapConstants.cameraIdleDebounceMs),
      () async {
        final center = _boundsCenter(bounds);

        // Discover nearby cafes (background, throttled to 30min per area)
        if (!_discoveryCache.isCached(bounds)) {
          _discoveryCache.set(bounds);
          unawaited(_discoverNearbyCafes(lat: center.latitude, lng: center.longitude));
        }

        // Spots query: skip if user hasn't moved >300m AND spots are already
        // loaded — prevents constant reloads and marker flicker on every pan.
        // Always reload if spots are empty (first launch, error recovery, etc.)
        final pos = state.userPosition;
        if (pos != null) {
          final cur = LatLng(pos.latitude, pos.longitude);
          final moved = _lastLoadPos == null || _distMeters(_lastLoadPos!, cur) > 300;
          if (moved || state.spots.isEmpty) {
            await _loadSpots(lat: pos.latitude, lng: pos.longitude);
          }
        }
      },
    );
  }

  /// Queries Google Places Nearby Search for ALL cafes within 3km, upserts new ones to DB.
  /// 자동 _loadSpots 호출 없음 — 다음 onCameraIdle에서 자연스럽게 갱신.
  /// (즉시 reload 시 탭 전환 복귀 중 마커가 갑작스럽게 나타나는 현상 방지)
  Future<void> _discoverNearbyCafes({
    required double lat,
    required double lng,
  }) async {
    try {
      final places = await ref
          .read(placesServiceProvider)
          .nearbyCafes(lat: lat, lng: lng);
      if (places.isEmpty) return;

      // 좌표 범위 검증: Google Places가 반경 밖 좌표로 장소를 반환하는 경우 제외.
      // 잘못된 좌표의 스팟이 사용자 위치 위에 겹쳐 보이는 현상을 방지.
      final validPlaces = places.where((p) {
        final dist = LocationService.distanceMeters(
          userLat: lat, userLng: lng,
          targetLat: p.lat, targetLng: p.lng,
        );
        return dist <= MapConstants.defaultRadiusMeters;
      }).toList();
      if (validPlaces.isEmpty) return;

      await ref.read(spotsRepositoryProvider).upsertBrandSpots(validPlaces);
    } catch (e) {
      debugPrint('[MapController] cafe discovery error: $e');
    }
  }

  Future<void> _loadSpots({required double lat, required double lng}) async {
    _lastLoadPos = LatLng(lat, lng);
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final spots = await ref.read(spotsRepositoryProvider).getSpotsNear(
            lat: lat,
            lng: lng,
            sticker: state.activeFilter,
          );
      state = state.copyWith(spots: spots, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setFilter(StickerType? filter) {
    if (filter == null) {
      // null = 전체 버튼 or 활성 칩 재탭 → 항상 clearFilter
      state = state.copyWith(clearFilter: true);
    } else {
      final isToggle = state.activeFilter == filter;
      state = state.copyWith(
        activeFilter: isToggle ? null : filter,
        clearFilter: isToggle,
      );
    }
    final pos = state.userPosition;
    if (pos != null) _loadSpots(lat: pos.latitude, lng: pos.longitude);
  }

  void refreshLocation() {
    _initLocation();
  }

  /// Forces an immediate spot reload — call after report submission so the
  /// map reflects the new average_db / report_count without waiting for camera idle.
  void reloadSpots() {
    final pos = state.userPosition;
    if (pos != null) _loadSpots(lat: pos.latitude, lng: pos.longitude);
  }

  static SpotDisplayMode displayMode(double zoom) {
    if (zoom >= MapConstants.zoomIndividualMin) return SpotDisplayMode.individual;
    if (zoom >= MapConstants.zoomReducedMin) return SpotDisplayMode.reduced;
    if (zoom >= MapConstants.zoomMinLoad) return SpotDisplayMode.heatmap;
    return SpotDisplayMode.hidden;
  }

  LatLng _boundsCenter(LatLngBounds bounds) => LatLng(
        (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
        (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
      );

  /// Approximate flat-earth distance in meters between two LatLng points.
  double _distMeters(LatLng a, LatLng b) {
    const metersPerDegLat = 111320.0;
    final metersPerDegLng =
        111320.0 * math.cos(a.latitude * math.pi / 180);
    final dy = (b.latitude - a.latitude) * metersPerDegLat;
    final dx = (b.longitude - a.longitude) * metersPerDegLng;
    return math.sqrt(dx * dx + dy * dy);
  }

  // ── Admin dummy mode helpers ─────────────────────────────────────────

  /// Overrides user position to [lat]/[lng], loads spots there, and moves camera.
  /// Used by admin dummy mode to simulate being at Gangnam Station.
  Future<void> setDummyLocation(double lat, double lng) async {
    final fake = Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      accuracy: 1.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      isMocked: true,
    );
    state = state.copyWith(userPosition: fake);
    await _loadSpots(lat: lat, lng: lng);
    // Camera may be disposed if map tab is not active — ignore the error.
    try {
      mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(lat, lng), zoom: 15.5),
        ),
      );
    } catch (_) {}
  }

  /// Reverts to real GPS location after dummy mode is turned OFF.
  Future<void> resetRealLocation() async {
    await _initLocation();
  }
}

final mapControllerProvider = NotifierProvider<MapController, MapState>(
  MapController.new,
);

/// 탐색 탭에서 "지도에서 보기" 시 카메라 이동 대상.
/// MapScreen이 소비 후 clear() 호출.
class MapFocusNotifier extends Notifier<LatLng?> {
  @override
  LatLng? build() => null;

  void focus(LatLng latlng) => state = latlng;
  void clear() => state = null;
}

final mapFocusProvider = NotifierProvider<MapFocusNotifier, LatLng?>(
  MapFocusNotifier.new,
);
