import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/constants/admin_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/map_constants.dart';
import '../../../core/services/att_service.dart';
import '../../../core/services/places_service.dart';
import '../../auth/data/auth_repository.dart';
import '../../../core/utils/db_classifier.dart';
import '../data/spots_repository.dart';
import '../domain/spot_model.dart';
import 'map_controller.dart';
import 'widgets/filter_bar.dart';
import 'widgets/spot_marker_widget.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  GoogleMapController? _mapController;
  double _currentZoom = MapConstants.defaultZoom;
  SpotModel? _selectedSpot;
  Brightness? _lastBrightness;
  String? _mapStyleString;

  // Search result selection state
  PlacePrediction? _searchPrediction;
  PlaceLatLng? _searchLatLng;
  Marker? _searchMarker;

  // Custom markers (async built from SpotMarkerWidget)
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  List<SpotModel> _lastBuiltSpots = const [];
  static const int _maxBitmapCacheSize = 100;
  final Map<String, BitmapDescriptor> _bitmapCache = {};
  SpotDisplayMode _lastDisplayMode = SpotDisplayMode.hidden;
  bool _hasMovedToUser = false;
  int _markerGeneration = 0; // 경쟁 조건 방지: 구버전 rebuild가 신버전 결과를 덮어쓰지 않도록

  static const _initialCamera = CameraPosition(
    target: LatLng(MapConstants.defaultLat, MapConstants.defaultLng),
    zoom: MapConstants.defaultZoom,
  );

  bool get _hasBottomCard => _selectedSpot != null || _searchPrediction != null;

  @override
  void initState() {
    super.initState();
    // ATT 권한 요청 — iOS 전용, notDetermined 상태일 때만 팝업 표시
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AttService.requestIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapControllerProvider);
    final displayMode = MapController.displayMode(_currentZoom);

    // Apply map style when brightness changes
    final brightness = Theme.of(context).brightness;
    if (_lastBrightness != brightness) {
      _lastBrightness = brightness;
      _loadMapStyle(brightness);
    }

    // spots 갱신 시 선택된 카드도 최신 데이터로 업데이트 (측정 제출 후 즉시 반영)
    ref.listen(mapControllerProvider.select((s) => s.spots), (prev, spots) {
      final sel = _selectedSpot;
      if (sel == null) return;
      final updated = spots.where((s) => s.id == sel.id).firstOrNull;
      if (updated != null && mounted) setState(() => _selectedSpot = updated);
    });

    // 탐색 탭에서 "지도에서 보기" 요청 처리
    ref.listen(mapFocusProvider, (prev, focus) {
      if (focus == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(focus, 16),
          );
        }
      });
      ref.read(mapFocusProvider.notifier).clear();
    });

    // Auto-center map when user location is first resolved
    final userPos = mapState.userPosition;
    if (userPos != null && !_hasMovedToUser) {
      _hasMovedToUser = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(userPos.latitude, userPos.longitude),
              MapConstants.defaultZoom,
            ),
          );
        }
      });
    }

    // Rebuild markers whenever spots or zoom-mode changes
    final currentSpots = mapState.spots;
    if (!identical(_lastBuiltSpots, currentSpots)) {
      _lastBuiltSpots = currentSpots;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _rebuildMarkersAsync(currentSpots, MapController.displayMode(_currentZoom));
        }
      });
    }

    return Scaffold(
      resizeToAvoidBottomInset: false, // 키보드 표시 시 지도 밀림 방지
      body: MediaQuery(
        // 키보드 insets를 0으로 덮어써서 자식 위젯이 키보드를 인지하지 못하게 함
        data: MediaQuery.of(context).copyWith(viewInsets: EdgeInsets.zero),
        child: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: _initialCamera,
            style: _mapStyleString,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
              ref.read(mapControllerProvider.notifier).mapController = controller;
              _moveToUserLocation();
            },
            onCameraIdle: () async {
              if (_mapController == null) return;
              final bounds = await _mapController!.getVisibleRegion();
              ref
                  .read(mapControllerProvider.notifier)
                  .onCameraIdle(bounds, _currentZoom);
            },
            onCameraMove: (pos) {
              setState(() => _currentZoom = pos.zoom);
              final newMode = MapController.displayMode(pos.zoom);
              if (newMode != _lastDisplayMode) {
                _lastDisplayMode = newMode;
                _rebuildMarkersAsync(
                  ref.read(mapControllerProvider).spots,
                  newMode,
                );
              }
            },
            markers: {..._markers, ?_searchMarker},
            circles: {
                ..._circles,
                if (mapState.userPosition != null && _currentZoom >= MapConstants.zoomMinLoad)
                  Circle(
                    circleId: const CircleId('_radius'),
                    center: LatLng(
                      mapState.userPosition!.latitude,
                      mapState.userPosition!.longitude,
                    ),
                    radius: MapConstants.defaultRadiusMeters,
                    fillColor: AppColors.mintGreen.withValues(alpha: 0.06),
                    strokeColor: AppColors.mintGreen.withValues(alpha: 0.35),
                    strokeWidth: 1,
                  ),
              },
            onTap: (_) => setState(() {
              _selectedSpot = null;
              _searchPrediction = null;
              _searchLatLng = null;
              _searchMarker = null;
            }),
            onLongPress: _isAdmin ? _onAdminLongPress : null,
          ),

          // Empty state overlay (no spots in this area)
          if (!mapState.isLoading &&
              mapState.spots.isEmpty &&
              displayMode != SpotDisplayMode.hidden)
            Positioned(
              bottom: _hasBottomCard ? 320 : 94,
              left: 40,
              right: 40,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Text(
                    '이 지역에 아직 소음 기록이 없어요\n근처 카페를 검색해서 측정해 보세요!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),

          // Top search bar
          _SearchBar(
            onPlaceSelected: _onPlaceSelected,
            onLocalSpotSelected: _onLocalSpotSelected,
            userLat: mapState.userPosition?.latitude,
            userLng: mapState.userPosition?.longitude,
          ),

          // Filter bar — 카드가 열릴 때 숨김 (BackdropFilter 블러 겹침 방지)
          Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _hasBottomCard ? 0.0 : 1.0,
              child: IgnorePointer(
                ignoring: _hasBottomCard,
                child: FilterBar(
                  activeFilter: mapState.activeFilter,
                  onFilterChanged: (filter) =>
                      ref.read(mapControllerProvider.notifier).setFilter(filter),
                ),
              ),
            ),
          ),

          // Spot info card (tap on existing marker) — slides up from bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: (_selectedSpot != null && _searchPrediction == null)
                  ? SpotInfoCard(
                      key: ValueKey(_selectedSpot!.id),
                      spot: _selectedSpot!,
                      onReport: () {
                        context.push(
                          '/report'
                          '?spotId=${_selectedSpot!.id}'
                          '&spotName=${Uri.encodeComponent(_selectedSpot!.name)}'
                          '&lat=${_selectedSpot!.lat}'
                          '&lng=${_selectedSpot!.lng}',
                        );
                      },
                      onDetail: () {
                        context.push('/spot/${_selectedSpot!.id}', extra: _selectedSpot!);
                      },
                    )
                  : const SizedBox.shrink(),
            ),
          ),

          // Search place card (search result selected, not yet a spot)
          if (_searchPrediction != null && _searchLatLng != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _SearchPlaceCard(
                prediction: _searchPrediction!,
                latLng: _searchLatLng!,
                onDismiss: () => setState(() {
                  _searchPrediction = null;
                  _searchLatLng = null;
                  _searchMarker = null;
                }),
                onMeasure: _onMeasureSearchedPlace,
              ),
            ),

          // FAB: back to current location
          Positioned(
            right: 16,
            bottom: _hasBottomCard ? 320 : 94,
            child: FloatingActionButton.small(
              onPressed: () {
                ref.read(mapControllerProvider.notifier).refreshLocation();
                _moveToUserLocation();
                setState(() {
                  _selectedSpot = null;
                  _searchPrediction = null;
                  _searchLatLng = null;
                  _searchMarker = null;
                });
              },
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: AppColors.mintGreen,
              elevation: 4,
              child: const Icon(Icons.my_location_rounded),
            ),
          ),

          // Loading indicator
          if (mapState.isLoading)
            const Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.mintGreen,
                  ),
                ),
              ),
            ),

          // Error banner — 데이터 로드 실패 시 상단에 표시
          if (mapState.error != null)
            _ErrorBanner(
              onRetry: () =>
                  ref.read(mapControllerProvider.notifier).reloadSpots(),
            ),

        ],
        ),
      ),
    );
  }

  /// Builds markers/circles for the given [mode].
  Future<void> _rebuildMarkersAsync(
    List<SpotModel> spots,
    SpotDisplayMode mode,
  ) async {
    final gen = ++_markerGeneration; // 이 rebuild의 세대 번호 고정
    if (!mounted) return;
    try {

    // 측정 기록 없는 스팟(Google Places 자동발견, report_count=0)은 마커 제외.
    // 탐색/검색에서는 계속 표시되고, 첫 측정 제출 후 지도에 나타남.
    final reportedSpots = spots.where((s) => s.reportCount > 0).toList();

    if (mode == SpotDisplayMode.hidden) {
      if (_markerGeneration == gen && mounted) setState(() { _markers = {}; _circles = {}; });
      return;
    }

    if (mode == SpotDisplayMode.heatmap) {
      final newCircles = reportedSpots.map((spot) {
        final color = DbClassifier.colorFromDb(spot.averageDb);
        return Circle(
          circleId: CircleId(spot.id),
          center: LatLng(spot.lat, spot.lng),
          radius: 250,
          fillColor: color.withValues(alpha: 0.18),
          strokeColor: color.withValues(alpha: 0.5),
          strokeWidth: 1,
        );
      }).toSet();
      if (_markerGeneration == gen && mounted) setState(() { _markers = {}; _circles = newCircles; });
      return;
    }

    // individual or reduced: bitmap markers
    final isReduced = mode == SpotDisplayMode.reduced;
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final newMarkers = <Marker>{};

    for (final spot in reportedSpots) {
      final cacheKey = '${spot.id}_$isReduced';
      if (!_bitmapCache.containsKey(cacheKey)) {
        // Evict oldest entry when cache is full (FIFO)
        if (_bitmapCache.length >= _maxBitmapCacheSize) {
          _bitmapCache.remove(_bitmapCache.keys.first);
        }
        _bitmapCache[cacheKey] = await SpotMarkerWidget.toBitmapDescriptor(
          spot,
          pixelRatio,
          isReduced: isReduced,
        );
        if (_markerGeneration != gen || !mounted) return; // 신버전 rebuild로 대체됨
      }
      newMarkers.add(Marker(
        markerId: MarkerId(spot.id),
        position: LatLng(spot.lat, spot.lng),
        icon: _bitmapCache[cacheKey]!,
        alpha: spot.markerOpacity,
        onTap: () => setState(() {
          _selectedSpot = spot;
          _searchPrediction = null;
          _searchLatLng = null;
          _searchMarker = null;
        }),
      ));
    }

    if (_markerGeneration == gen && mounted) setState(() { _markers = newMarkers; _circles = {}; });
    } catch (e, st) {
      debugPrint('[MapScreen] _rebuildMarkersAsync error: $e\n$st');
    }
  }

  Future<void> _loadMapStyle(Brightness brightness) async {
    final path = brightness == Brightness.dark
        ? 'assets/map_style_dark.json'
        : 'assets/map_style_light.json';
    final style = await rootBundle.loadString(path);
    if (mounted) setState(() => _mapStyleString = style);
  }

  void _moveToUserLocation() {
    final pos = ref.read(mapControllerProvider).userPosition;
    if (pos != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(pos.latitude, pos.longitude),
          MapConstants.defaultZoom,
        ),
      );
    }
  }

  bool get _isAdmin {
    final uid = ref.read(authRepositoryProvider).currentUser?.id;
    return uid != null && AdminConfig.adminUserIds.contains(uid);
  }

  void _onAdminLongPress(LatLng position) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('카페 직접 추가'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '카페 이름',
            hintText: '예) 스타벅스 청주점',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(dialogCtx);
              try {
                await ref.read(spotsRepositoryProvider).createSpot(
                      name: name,
                      googlePlaceId: null,
                      lat: position.latitude,
                      lng: position.longitude,
                    );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('"$name" 추가 완료')),
                  );
                  // Reload spots
                  final pos = ref.read(mapControllerProvider).userPosition;
                  if (pos != null) {
                    ref.read(mapControllerProvider.notifier).refreshLocation();
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('추가 실패. 다시 시도하세요.')),
                  );
                }
              }
            },
            child: const Text('추가', style: TextStyle(color: AppColors.mintGreen)),
          ),
        ],
      ),
    );
  }

  void _onPlaceSelected(PlacePrediction prediction, PlaceLatLng latLng) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(latLng.lat, latLng.lng),
        MapConstants.defaultZoom,
      ),
    );
    setState(() {
      _selectedSpot = null;
      _searchPrediction = prediction;
      _searchLatLng = latLng;
      _searchMarker = Marker(
        markerId: const MarkerId('_search_result'),
        position: LatLng(latLng.lat, latLng.lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      );
    });
    // Trigger spot reload at new location
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_mapController == null || !mounted) return;
      final bounds = await _mapController!.getVisibleRegion();
      ref.read(mapControllerProvider.notifier).onCameraIdle(bounds, _currentZoom);
    });
  }

  /// DB에 이미 등록된 카페를 검색창에서 선택했을 때 호출.
  /// 카메라 이동 + SpotInfoCard 표시 (API 호출 없음).
  void _onLocalSpotSelected(SpotModel spot) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(spot.lat, spot.lng), 16),
    );
    setState(() {
      _selectedSpot = spot;
      _searchPrediction = null;
      _searchLatLng = null;
      _searchMarker = null;
    });
  }

  /// Navigate to report screen for a search-selected place.
  /// Checks if the spot already exists in DB (via google_place_id).
  Future<void> _onMeasureSearchedPlace() async {
    final prediction = _searchPrediction;
    final latLng = _searchLatLng;
    if (prediction == null || latLng == null) return;

    // Check if spot already exists in DB
    final existingSpotId = await ref
        .read(spotsRepositoryProvider)
        .getSpotIdByPlaceId(prediction.placeId);

    if (!mounted) return;

    if (existingSpotId != null) {
      // Spot exists → go directly to report with spotId + coordinates for proximity check
      context.push(
        '/report'
        '?spotId=$existingSpotId'
        '&spotName=${Uri.encodeComponent(prediction.mainText)}'
        '&lat=${latLng.lat}'
        '&lng=${latLng.lng}',
      );
    } else {
      // New spot → pass placeId + coordinates for spot creation on submit
      context.push(
        '/report'
        '?spotName=${Uri.encodeComponent(prediction.mainText)}'
        '&placeId=${prediction.placeId}'
        '&lat=${latLng.lat}'
        '&lng=${latLng.lng}',
      );
    }
  }
}

/// 지도 데이터 로드 실패 시 상단에 표시되는 에러 배너.
class _ErrorBanner extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorBanner({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.red.shade700.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.red.shade900.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '데이터를 불러올 수 없어요',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  '다시 시도',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card shown when user selects a search result — lets them measure at that place.
class _SearchPlaceCard extends StatelessWidget {
  final PlacePrediction prediction;
  final PlaceLatLng latLng;
  final VoidCallback onDismiss;
  final VoidCallback onMeasure;

  const _SearchPlaceCard({
    required this.prediction,
    required this.latLng,
    required this.onDismiss,
    required this.onMeasure,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.place_rounded, color: AppColors.mintGreen, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  prediction.mainText,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                color: AppColors.textHint,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                onPressed: onDismiss,
              ),
            ],
          ),
          if (prediction.secondaryText.isNotEmpty) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                prediction.secondaryText,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textHint,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onMeasure,
              icon: const Icon(Icons.graphic_eq_rounded, size: 18),
              label: const Text('이 장소 측정하기'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends ConsumerStatefulWidget {
  final void Function(PlacePrediction prediction, PlaceLatLng latLng) onPlaceSelected;
  final void Function(SpotModel spot) onLocalSpotSelected;
  final double? userLat;
  final double? userLng;

  const _SearchBar({
    required this.onPlaceSelected,
    required this.onLocalSpotSelected,
    this.userLat,
    this.userLng,
  });

  @override
  ConsumerState<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends ConsumerState<_SearchBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<PlacePrediction> _suggestions = [];
  List<SpotModel> _localSpots = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() { _suggestions = []; _localSpots = []; });
      return;
    }
    // 로컬 DB 스팟 즉시 필터 (캐시된 데이터 — 네트워크 불필요)
    final q = value.trim().toLowerCase();
    final all = ref.read(mapControllerProvider).spots;
    setState(() {
      _localSpots = all
          .where((s) => s.name.toLowerCase().contains(q))
          .take(8)
          .toList();
    });
    _debounce = Timer(const Duration(milliseconds: 350), () => _fetchSuggestions(value));
  }

  Future<void> _fetchSuggestions(String input) async {
    final results = await ref.read(placesServiceProvider).autocomplete(
      input,
      lat: widget.userLat,
      lng: widget.userLng,
    );
    if (mounted) setState(() => _suggestions = results);
  }

  Future<void> _selectPrediction(PlacePrediction prediction) async {
    _controller.text = prediction.mainText;
    _focusNode.unfocus();
    setState(() => _suggestions = []);
    final details = await ref.read(placesServiceProvider).getDetails(prediction.placeId);
    if (details != null && mounted) {
      widget.onPlaceSelected(prediction, details);
    }
  }

  void _clear() {
    _controller.clear();
    setState(() { _suggestions = []; _localSpots = []; });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: Column(
        children: [
          // Search bar
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: _onChanged,
              scrollPadding: EdgeInsets.zero, // 키보드 노출 시 자동 스크롤 방지
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '카페, 도서관, 공원 검색...',
                hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 15),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textHint, size: 20),
                suffixIcon: ListenableBuilder(
                  listenable: _controller,
                  builder: (context, _) => _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, color: AppColors.textHint, size: 18),
                          onPressed: _clear,
                        )
                      : const SizedBox.shrink(),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
              ),
            ),
          ),
          // Autocomplete dropdown — 로컬 DB 스팟 + Google Places API
          if (_suggestions.isNotEmpty || _localSpots.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              constraints: const BoxConstraints(maxHeight: 320),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: [
                    // ── 등록된 카페 (로컬 DB) ───────────────────────
                    if (_localSpots.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Text(
                          '등록된 카페',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textHint,
                          ),
                        ),
                      ),
                      ..._localSpots.map((spot) => ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.local_cafe_rounded,
                          color: AppColors.mintGreen,
                          size: 18,
                        ),
                        title: Text(
                          spot.name,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        subtitle: spot.formattedAddress != null
                            ? Text(
                                spot.formattedAddress!,
                                style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        onTap: () {
                          _controller.text = spot.name;
                          _focusNode.unfocus();
                          setState(() { _suggestions = []; _localSpots = []; });
                          widget.onLocalSpotSelected(spot);
                        },
                      )),
                    ],
                    // ── 장소 검색 (Google Places) ────────────────────
                    if (_suggestions.isNotEmpty) ...[
                      if (_localSpots.isNotEmpty)
                        const Divider(height: 1, color: AppColors.divider),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Text(
                          '장소 검색',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textHint,
                          ),
                        ),
                      ),
                      ..._suggestions.map((p) => ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.place_rounded,
                          color: AppColors.skyBlue,
                          size: 18,
                        ),
                        title: Text(
                          p.mainText,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        subtitle: p.secondaryText.isNotEmpty
                            ? Text(
                                p.secondaryText,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textHint,
                                ),
                              )
                            : null,
                        onTap: () => _selectPrediction(p),
                      )),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

