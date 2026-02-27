import 'dart:async';
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
  final _boundsCache = BoundsCache();
  // Brand cafe discovery uses a separate cache with 30min TTL to limit API usage
  final _discoveryCache = BoundsCache(ttlSeconds: 1800);
  GoogleMapController? mapController;

  @override
  MapState build() {
    ref.onDispose(() => _debounceTimer?.cancel());
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

        // Discover brand cafes (background, throttled to 30min per area)
        if (!_discoveryCache.isCached(bounds)) {
          _discoveryCache.set(bounds);
          unawaited(_discoverBrandCafes(lat: center.latitude, lng: center.longitude));
        }

        // Load spots from DB (debounced, skips cached bounds)
        if (_boundsCache.isCached(bounds)) return;
        _boundsCache.set(bounds);
        await _loadSpots(lat: center.latitude, lng: center.longitude);
      },
    );
  }

  /// Queries Google Places Nearby Search for brand cafes, upserts new ones to DB,
  /// then refreshes the map if new spots were added.
  Future<void> _discoverBrandCafes({
    required double lat,
    required double lng,
  }) async {
    try {
      final places = await ref
          .read(placesServiceProvider)
          .nearbyBrandCafes(lat: lat, lng: lng);
      if (places.isEmpty) return;

      final created = await ref
          .read(spotsRepositoryProvider)
          .upsertBrandSpots(places);

      if (created > 0) {
        // New brand cafes added — refresh map spots
        await _loadSpots(lat: lat, lng: lng);
      }
    } catch (e) {
      debugPrint('[MapController] brand discovery error: $e');
    }
  }

  Future<void> _loadSpots({required double lat, required double lng}) async {
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
    final isToggle = state.activeFilter == filter;
    state = state.copyWith(
      activeFilter: isToggle ? null : filter,
      clearFilter: isToggle,
    );
    _boundsCache.clear();
    final pos = state.userPosition;
    if (pos != null) _loadSpots(lat: pos.latitude, lng: pos.longitude);
  }

  void refreshLocation() {
    _boundsCache.clear();
    _initLocation();
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
}

final mapControllerProvider = NotifierProvider<MapController, MapState>(
  MapController.new,
);
