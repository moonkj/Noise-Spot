import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/location_service.dart';
import '../../../features/map/data/spots_repository.dart';
import '../../../features/map/domain/spot_model.dart';

// ──────────────────────────────────────────────────────────────
// Provider: 내 주변 3km 카페 목록 (자동 탐색)
// ──────────────────────────────────────────────────────────────
final _nearbySpotsProvider = FutureProvider.autoDispose<List<SpotModel>>((ref) async {
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
enum _SortMode { nearest, popular }

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  StickerType? _activeFilter; // null = 전체
  _SortMode _sortMode = _SortMode.nearest;

  List<SpotModel> _applyFilter(List<SpotModel> spots) {
    final filtered = _activeFilter == null
        ? spots
        : spots.where((s) => s.representativeSticker == _activeFilter).toList();

    if (_sortMode == _SortMode.popular) {
      filtered.sort((a, b) => b.reportCount.compareTo(a.reportCount));
    }
    // nearest: already sorted by distance from RPC
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final spotsAsync = ref.watch(_nearbySpotsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F1),
      body: spotsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.mintGreen),
        ),
        error: (e, _) => _ErrorView(onRetry: () => ref.invalidate(_nearbySpotsProvider)),
        data: (spots) {
          final filtered = _applyFilter(spots);
          return CustomScrollView(
            slivers: [
              SliverPersistentHeader(
                delegate: _ExploreAppBar(count: filtered.length),
                pinned: true,
              ),
              _FilterRow(
                activeFilter: _activeFilter,
                sortMode: _sortMode,
                onFilterChanged: (f) => setState(() => _activeFilter = f),
                onSortChanged: (s) => setState(() => _sortMode = s),
              ),
              if (filtered.isEmpty)
                const SliverFillRemaining(child: _EmptyView())
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _CafeListTile(spot: filtered[i]),
                    childCount: filtered.length,
                  ),
                ),
              // bottom padding for nav bar
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/report'),
        backgroundColor: AppColors.mintGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(AppStrings.exploreAddCafe),
        elevation: 4,
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
      color: const Color(0xFFF8F6F1),
      padding: EdgeInsets.only(top: top, left: 20, right: 20, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            AppStrings.exploreTitle,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
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
            Container(width: 1, height: 28, margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4), color: Colors.grey.shade300),
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
            color: isActive ? AppColors.mintGreen : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? AppColors.mintGreen : Colors.grey.shade300,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive ? Colors.white : const Color(0xFF555555),
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Cafe List Tile
// ──────────────────────────────────────────────────────────────
class _CafeListTile extends StatelessWidget {
  final SpotModel spot;
  const _CafeListTile({required this.spot});

  /// 카페 이름 첫 글자의 배경 색상 (일관된 색상)
  Color _avatarColor() {
    final colors = [
      const Color(0xFFBBDEFB), // light blue
      const Color(0xFFB2EBF2), // light cyan
      const Color(0xFFDCEDC8), // light green
      const Color(0xFFFFCCBC), // light orange
      const Color(0xFFE1BEE7), // light purple
      const Color(0xFFFFE0B2), // light amber
    ];
    return colors[spot.name.codeUnitAt(0) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final sticker = spot.representativeSticker;
    final dbColor = AppColors.dbColor(spot.averageDb);
    final firstChar = spot.name.isNotEmpty ? spot.name[0] : '?';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _avatarColor(),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              firstChar,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF444444),
              ),
            ),
          ),
        ),
        title: Text(
          spot.name,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (spot.formattedAddress != null) ...[
              const SizedBox(height: 2),
              Text(
                spot.formattedAddress!,
                style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                if (sticker != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: dbColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${sticker.label} ${spot.averageDb.toStringAsFixed(0)}dB',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: dbColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(Icons.bar_chart, size: 13, color: Colors.grey.shade400),
                const SizedBox(width: 2),
                Text(
                  '${spot.reportCount}회 측정',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ],
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.grey.shade300),
        onTap: () => context.push('/spot/${spot.id}', extra: spot),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Empty / Error states
// ──────────────────────────────────────────────────────────────
class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.coffee_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            AppStrings.exploreEmpty,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
          Text(
            '첫 번째 카페를 등록해 보세요!',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
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
          Icon(Icons.wifi_off_outlined, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('위치를 불러올 수 없어요', style: TextStyle(color: Colors.grey.shade600)),
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
