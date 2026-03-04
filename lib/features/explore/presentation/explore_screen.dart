import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/location_service.dart';
import '../../../features/map/data/spots_repository.dart';
import '../../../features/map/domain/spot_model.dart';

// ──────────────────────────────────────────────────────────────
// Provider: 내 주변 3km 카페 목록 (자동 탐색)
// keepAlive — 탭 전환 시 데이터 유지, RefreshIndicator로만 갱신
// ──────────────────────────────────────────────────────────────
final _nearbySpotsProvider = FutureProvider<List<SpotModel>>((ref) async {
  final position = await ref.watch(currentPositionProvider.future);
  return ref.read(spotsRepositoryProvider).getSpotsNear(
    lat: position.latitude,
    lng: position.longitude,
    radiusMeters: 3000,
  );
});

// ──────────────────────────────────────────────────────────────
// Sort mode
// ──────────────────────────────────────────────────────────────
enum _SortMode { nearest, popular, recent }

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  StickerType? _activeFilter; // null = 전체
  _SortMode _sortMode = _SortMode.nearest;
  String _searchQuery = '';

  List<SpotModel> _applyFilter(List<SpotModel> spots) {
    var filtered = _activeFilter == null
        ? List<SpotModel>.from(spots)
        : spots.where((s) => s.representativeSticker == _activeFilter).toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((s) => s.name.toLowerCase().contains(q)).toList();
    }

    if (_sortMode == _SortMode.popular) {
      filtered.sort((a, b) => b.reportCount.compareTo(a.reportCount));
    } else if (_sortMode == _SortMode.recent) {
      filtered.sort((a, b) =>
          (b.lastReportAt ?? DateTime(2000))
              .compareTo(a.lastReportAt ?? DateTime(2000)));
    }
    // nearest: already sorted by distance from RPC
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final spotsAsync = ref.watch(_nearbySpotsProvider);
    final userPos = ref.watch(currentPositionProvider).asData?.value;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: spotsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.mintGreen),
        ),
        error: (e, _) => _ErrorView(onRetry: () => ref.invalidate(_nearbySpotsProvider)),
        data: (spots) {
          final filtered = _applyFilter(spots);
          return RefreshIndicator(
            color: AppColors.mintGreen,
            onRefresh: () async {
              ref.invalidate(currentPositionProvider);
              ref.invalidate(_nearbySpotsProvider);
              await ref
                  .read(_nearbySpotsProvider.future)
                  .catchError((_) => <SpotModel>[]);
            },
            child: CustomScrollView(
            slivers: [
              SliverPersistentHeader(
                delegate: _ExploreAppBar(count: filtered.length),
                pinned: true,
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                    decoration: InputDecoration(
                      hintText: '카페 이름 검색',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                    ),
                  ),
                ),
              ),
              _FilterRow(
                activeFilter: _activeFilter,
                sortMode: _sortMode,
                onFilterChanged: (f) => setState(() => _activeFilter = f),
                onSortChanged: (s) => setState(() => _sortMode = s),
              ),
              if (filtered.isEmpty)
                SliverFillRemaining(
                  child: _EmptyView(
                    hasFilter: _activeFilter != null,
                    onClearFilter: () => setState(() => _activeFilter = null),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _CafeListTile(
                      spot: filtered[i],
                      userPos: userPos,
                    ),
                    childCount: filtered.length,
                  ),
                ),
              // bottom padding for nav bar
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
            ),
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// SliverAppBar
// ──────────────────────────────────────────────────────────────
class _ExploreAppBar extends SliverPersistentHeaderDelegate {
  final int count;
  const _ExploreAppBar({required this.count});

  @override
  double get minExtent => 76;
  @override
  double get maxExtent => 76;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: EdgeInsets.only(top: top, left: 20, right: 20, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            AppStrings.exploreTitle,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.mintGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              AppStrings.exploreCafeCount(count),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.mintGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_ExploreAppBar old) => old.count != count;
}

// ──────────────────────────────────────────────────────────────
// Filter Row — 가로 스크롤 chips
// ──────────────────────────────────────────────────────────────
class _FilterRow extends StatelessWidget {
  final StickerType? activeFilter;
  final _SortMode sortMode;
  final ValueChanged<StickerType?> onFilterChanged;
  final ValueChanged<_SortMode> onSortChanged;

  const _FilterRow({
    required this.activeFilter,
    required this.sortMode,
    required this.onFilterChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            // 타입 필터
            _Chip(
              label: AppStrings.exploreFilterAll,
              isActive: activeFilter == null,
              onTap: () => onFilterChanged(null),
            ),
            ...StickerType.values.map((t) => _Chip(
              label: t.filterLabel,
              isActive: activeFilter == t,
              onTap: () => onFilterChanged(t),
            )),
            // 구분선
            const SizedBox(width: 4),
            Container(width: 1, height: 28, margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4), color: Theme.of(context).dividerColor),
            const SizedBox(width: 4),
            // 정렬
            _Chip(
              label: AppStrings.exploreSortNearest,
              isActive: sortMode == _SortMode.nearest,
              onTap: () => onSortChanged(_SortMode.nearest),
              isSort: true,
            ),
            _Chip(
              label: AppStrings.exploreSortPopular,
              isActive: sortMode == _SortMode.popular,
              onTap: () => onSortChanged(_SortMode.popular),
              isSort: true,
            ),
            _Chip(
              label: AppStrings.exploreSortRecent,
              isActive: sortMode == _SortMode.recent,
              onTap: () => onSortChanged(_SortMode.recent),
              isSort: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool isSort;

  const _Chip({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.isSort = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? AppColors.mintGreen : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? AppColors.mintGreen : Theme.of(context).dividerColor,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Cafe List Tile — visual card with dB bar + press animation
// ──────────────────────────────────────────────────────────────
class _CafeListTile extends StatefulWidget {
  final SpotModel spot;
  final Position? userPos;
  const _CafeListTile({required this.spot, this.userPos});

  @override
  State<_CafeListTile> createState() => _CafeListTileState();
}

class _CafeListTileState extends State<_CafeListTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  SpotModel get spot => widget.spot;
  Position? get userPos => widget.userPos;

  String _relativeTime(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  String? _distanceLabel() {
    if (userPos == null) return null;
    final m = LocationService.distanceMeters(
      userLat: userPos!.latitude,
      userLng: userPos!.longitude,
      targetLat: spot.lat,
      targetLng: spot.lng,
    );
    if (m < 1000) return '${m.round()}m';
    return '${(m / 1000).toStringAsFixed(1)}km';
  }

  @override
  Widget build(BuildContext context) {
    final sticker = spot.representativeSticker;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasData = spot.reportCount > 0;
    final dbColor = hasData
        ? AppColors.dbColor(spot.averageDb)
        : (isDark ? AppColors.darkDisabled : const Color(0xFFBBBBBB));
    final distLabel = _distanceLabel();
    final subTextColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);

    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) {
        _pressCtrl.reverse();
        context.push('/spot/${spot.id}', extra: spot);
      },
      onTapCancel: () => _pressCtrl.reverse(),
      child: AnimatedBuilder(
        animation: _pressScale,
        builder: (context, child) => Transform.scale(scale: _pressScale.value, child: child),
        child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              // ── Left dB color bar ──────────────────────────────
              Container(
                width: 5,
                height: 86,
                color: dbColor,
              ),
              // ── Content ───────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ── Main info ────────────────────────────
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              spot.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (spot.formattedAddress != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                spot.formattedAddress!,
                                style: TextStyle(fontSize: 12, color: subTextColor),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if (sticker != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: dbColor.withValues(alpha: 0.13),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      sticker.label,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: dbColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Icon(Icons.bar_chart, size: 12, color: subTextColor),
                                const SizedBox(width: 2),
                                Text(
                                  '${spot.reportCount}회',
                                  style: TextStyle(fontSize: 11, color: subTextColor),
                                ),
                                if (distLabel != null) ...[
                                  const SizedBox(width: 8),
                                  Icon(Icons.near_me_rounded, size: 11, color: subTextColor),
                                  const SizedBox(width: 2),
                                  Text(
                                    distLabel,
                                    style: TextStyle(fontSize: 11, color: subTextColor),
                                  ),
                                ],
                                () {
                                  final t = _relativeTime(spot.lastReportAt);
                                  return t.isNotEmpty
                                      ? Row(children: [
                                          const SizedBox(width: 8),
                                          Icon(Icons.access_time_rounded,
                                              size: 11, color: subTextColor),
                                          const SizedBox(width: 2),
                                          Text(t,
                                              style: TextStyle(
                                                  fontSize: 11, color: subTextColor)),
                                        ])
                                      : const SizedBox.shrink();
                                }(),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // ── dB number ────────────────────────────
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            hasData ? spot.averageDb.toStringAsFixed(0) : '--',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: dbColor,
                              height: 1.0,
                            ),
                          ),
                          Text(
                            'dB',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: dbColor.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        ),  // Container
      ),    // AnimatedBuilder
    );      // GestureDetector
  }
}

// ──────────────────────────────────────────────────────────────
// Empty / Error states
// ──────────────────────────────────────────────────────────────
class _EmptyView extends StatelessWidget {
  final bool hasFilter;
  final VoidCallback? onClearFilter;

  const _EmptyView({this.hasFilter = false, this.onClearFilter});

  @override
  Widget build(BuildContext context) {
    final subColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.coffee_outlined, size: 64, color: subColor),
          const SizedBox(height: 16),
          Text(
            hasFilter ? '해당 필터의 카페가 없어요' : AppStrings.exploreEmpty,
            style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55)),
          ),
          const SizedBox(height: 8),
          if (hasFilter && onClearFilter != null)
            TextButton(
              onPressed: onClearFilter,
              child: const Text(
                '필터 초기화',
                style: TextStyle(color: AppColors.mintGreen),
              ),
            )
          else
            Text(
              '첫 번째 카페를 등록해 보세요!',
              style: TextStyle(fontSize: 13, color: subColor),
            ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_outlined, size: 48, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(
            '위치를 불러올 수 없어요',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            child: const Text('다시 시도', style: TextStyle(color: AppColors.mintGreen)),
          ),
        ],
      ),
    );
  }
}
