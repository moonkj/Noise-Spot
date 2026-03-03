import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/db_classifier.dart';
import '../../map/domain/spot_model.dart';
import '../../map/presentation/widgets/spot_marker_widget.dart';
import '../../report/data/report_repository.dart';

// ──────────────────────────────────────────────────────────────
// Provider
// ──────────────────────────────────────────────────────────────

final myMapSpotsProvider = FutureProvider.autoDispose<List<SpotModel>>((ref) {
  return ref.watch(reportRepositoryProvider).getMyReportedSpots();
});

// ──────────────────────────────────────────────────────────────
// Screen
// ──────────────────────────────────────────────────────────────

class MyMapScreen extends ConsumerWidget {
  const MyMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spotsAsync = ref.watch(myMapSpotsProvider);

    return Scaffold(
      body: Stack(
        children: [
          // ── 지도 또는 로딩/에러 ─────────────────────────────────
          spotsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '데이터를 불러오지 못했어요.\n잠시 후 다시 시도해주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
            data: (spots) => _MapBody(spots: spots),
          ),

          // ── 뒤로가기 버튼 ────────────────────────────────────────
          Positioned(
            top: 0,
            left: 16,
            child: SafeArea(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => context.canPop() ? context.pop() : context.go('/profile'),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.arrow_back,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ── 타이틀 ──────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    '내 탐험 지도',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ),

          // ── 통계 카드 (데이터 로드 후만 표시) ───────────────────
          if (spotsAsync.asData?.value != null)
            _StatsCardOverlay(spots: spotsAsync.asData!.value),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Map Body
// ──────────────────────────────────────────────────────────────

class _MapBody extends StatefulWidget {
  final List<SpotModel> spots;
  const _MapBody({required this.spots});

  @override
  State<_MapBody> createState() => _MapBodyState();
}

class _MapBodyState extends State<_MapBody> {
  GoogleMapController? _mapController;
  String? _mapStyleString;
  Brightness? _lastBrightness;
  Set<Marker> _markers = {};
  final Map<String, BitmapDescriptor> _bitmapCache = {};
  SpotModel? _selectedSpot;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    if (_lastBrightness != brightness) {
      _lastBrightness = brightness;
      _loadMapStyle(brightness);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _buildMarkersAsync();
    });
  }

  @override
  void didUpdateWidget(_MapBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spots != widget.spots) {
      _buildMarkersAsync();
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadMapStyle(Brightness brightness) async {
    final path = brightness == Brightness.dark
        ? 'assets/map_style_dark.json'
        : 'assets/map_style_light.json';
    final style = await rootBundle.loadString(path);
    if (mounted) setState(() => _mapStyleString = style);
  }

  Future<void> _buildMarkersAsync() async {
    if (widget.spots.isEmpty) {
      if (mounted) setState(() => _markers = {});
      return;
    }
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final newMarkers = <Marker>{};

    for (final spot in widget.spots) {
      if (!mounted) return; // ← mounted 체크 (각 await 전)

      BitmapDescriptor descriptor;
      if (_bitmapCache.containsKey(spot.id)) {
        descriptor = _bitmapCache[spot.id]!;
      } else {
        try {
          descriptor = await SpotMarkerWidget.toBitmapDescriptor(spot, pixelRatio);
        } catch (_) {
          descriptor = BitmapDescriptor.defaultMarker;
        }
        if (!mounted) return; // ← await 후 재확인
        _bitmapCache[spot.id] = descriptor;
      }
      newMarkers.add(Marker(
        markerId: MarkerId(spot.id),
        position: LatLng(spot.lat, spot.lng),
        icon: descriptor,
        onTap: () {
          if (mounted) setState(() => _selectedSpot = spot);
        },
      ));
    }
    if (mounted) setState(() => _markers = newMarkers);
  }

  CameraUpdate _boundsUpdate() {
    final spots = widget.spots;
    if (spots.isEmpty) {
      return CameraUpdate.newCameraPosition(
        const CameraPosition(target: LatLng(37.5665, 126.9780), zoom: 11),
      );
    }
    if (spots.length == 1) {
      return CameraUpdate.newLatLngZoom(LatLng(spots[0].lat, spots[0].lng), 14);
    }
    double south = spots[0].lat, north = spots[0].lat;
    double west = spots[0].lng, east = spots[0].lng;
    for (final s in spots) {
      if (s.lat < south) south = s.lat;
      if (s.lat > north) north = s.lat;
      if (s.lng < west) west = s.lng;
      if (s.lng > east) east = s.lng;
    }
    return CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(south - 0.005, west - 0.005),
        northeast: LatLng(north + 0.005, east + 0.005),
      ),
      60.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: LatLng(37.5665, 126.9780),
            zoom: 11,
          ),
          markers: _markers,
          style: _mapStyleString,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          compassEnabled: false,
          onMapCreated: (ctrl) {
            _mapController = ctrl;
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) ctrl.animateCamera(_boundsUpdate());
            });
          },
          onTap: (_) => setState(() => _selectedSpot = null),
        ),
        // 마커 탭 미니 카드
        if (_selectedSpot != null)
          Positioned(
            bottom: 100,
            left: 16,
            right: 16,
            child: _MiniInfoCard(
              spot: _selectedSpot!,
              onClose: () => setState(() => _selectedSpot = null),
            ),
          ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Mini Info Card (마커 탭 시)
// ──────────────────────────────────────────────────────────────

class _MiniInfoCard extends StatelessWidget {
  final SpotModel spot;
  final VoidCallback onClose;
  const _MiniInfoCard({required this.spot, required this.onClose});

  static String _shortDistrict(String? address) {
    if (address == null || address.isEmpty) return '';
    final parts = address.trim().split(' ');
    return parts.length >= 2 ? parts[1] : parts[0];
  }

  @override
  Widget build(BuildContext context) {
    final hasData = spot.reportCount > 0;
    final dbColor = hasData ? DbClassifier.colorFromDb(spot.averageDb) : null;
    final district = _shortDistrict(spot.formattedAddress);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  spot.name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (district.isNotEmpty)
                  Text(
                    district,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: hasData
                  ? dbColor!.withValues(alpha: 0.15)
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              hasData ? '${spot.averageDb.toStringAsFixed(1)} dB' : '측정 없음',
              style: TextStyle(
                color: hasData ? dbColor! : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: Padding(
              padding: const EdgeInsets.all(13), // (44-18)/2 → WCAG 44pt 확보
              child: Icon(
                Icons.close,
                size: 18,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Stats Card Overlay (하단 플로팅)
// ──────────────────────────────────────────────────────────────

class _StatsCardOverlay extends StatelessWidget {
  final List<SpotModel> spots;
  const _StatsCardOverlay({required this.spots});

  static Map<String, int> _buildDistrictMap(List<SpotModel> spots) {
    final map = <String, int>{};
    for (final s in spots) {
      final addr = (s.formattedAddress ?? '').trim();
      if (addr.isEmpty) {
        map['기타'] = (map['기타'] ?? 0) + 1;
        continue;
      }
      final parts = addr.split(' ');
      final d = parts.length >= 2 ? '${parts[0]} ${parts[1]}' : parts[0];
      map[d] = (map[d] ?? 0) + 1;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final districtMap = _buildDistrictMap(spots);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: GestureDetector(
          onTap: () => _showDistrictSheet(context, spots, districtMap),
          child: Container(
            padding: EdgeInsets.fromLTRB(
              24, 16, 24, 16 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.80)
                  : Colors.white.withValues(alpha: 0.92),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                _StatPill(
                  icon: Icons.local_cafe_rounded,
                  label: '${spots.length}개 카페 탐험',
                ),
                const SizedBox(width: 12),
                _StatPill(
                  icon: Icons.map_outlined,
                  label: '${districtMap.length}개 동네 방문',
                ),
                const Spacer(),
                Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
    );
  }

  void _showDistrictSheet(
    BuildContext context,
    List<SpotModel> spots,
    Map<String, int> districtMap,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DistrictSheet(
        totalCafes: spots.length,
        districtMap: districtMap,
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.mintGreen),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.mintGreen,
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
// District Bottom Sheet
// ──────────────────────────────────────────────────────────────

class _DistrictSheet extends StatelessWidget {
  final int totalCafes;
  final Map<String, int> districtMap;
  const _DistrictSheet({required this.totalCafes, required this.districtMap});

  @override
  Widget build(BuildContext context) {
    final sortedEntries = districtMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: CustomScrollView(
            controller: scrollCtrl,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    // 드래그 핸들
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // 헤더
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          const Text(
                            '탐험 현황',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.mintGreen.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${districtMap.length}개 동네',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.mintGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        '카페 5곳 측정 달성 시 🏆 동네탐험가 배지',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                  ],
                ),
              ),
              if (sortedEntries.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        '아직 측정한 카페가 없어요',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _DistrictTile(
                      district: sortedEntries[index].key,
                      count: sortedEntries[index].value,
                    ),
                    childCount: sortedEntries.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        );
      },
    );
  }
}

class _DistrictTile extends StatelessWidget {
  final String district;
  final int count;
  const _DistrictTile({required this.district, required this.count});

  static String _shortDistrict(String district) {
    final parts = district.split(' ');
    return parts.length >= 2 ? parts[1] : district;
  }

  @override
  Widget build(BuildContext context) {
    final isAchieved = count >= 5;
    final progress = (count / 5.0).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _shortDistrict(district),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              if (isAchieved) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '🏆 동네탐험가 달성!',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB8860B),
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                '$count곳',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isAchieved
                      ? AppColors.mintGreen
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor:
                  Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(
                isAchieved ? AppColors.mintGreen : AppColors.mintGreen.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            isAchieved ? '목표 달성 완료!' : '목표: 5곳 ($count/5)',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
