import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/admin_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/nickname_service.dart';
import '../../../core/services/rep_badge_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/level_service.dart';
import '../../bookmark/data/bookmark_repository.dart';
import '../../map/domain/spot_model.dart';
import '../../report/data/report_repository.dart';
import '../../report/domain/report_model.dart';
import '../data/profile_repository.dart';
import 'badge_detail_sheet.dart';
import 'nickname_setup_sheet.dart';
import 'widgets/level_up_animation.dart';

/// Admin-only: when true, all badges are shown as unlocked in profile.
class _AdminBadgePreviewNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
}

final adminBadgePreviewProvider =
    NotifierProvider<_AdminBadgePreviewNotifier, bool>(
  _AdminBadgePreviewNotifier.new,
);

/// Public so report_screen.dart can invalidate these after a submission.
final profileStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.watch(reportRepositoryProvider).getMyStats();
});

/// Returns (BadgeStats, earnedBadgeIds) for the badge section.
final profileBadgeDataProvider =
    FutureProvider.autoDispose<(BadgeStats, Set<String>)>((ref) {
  return ref.watch(reportRepositoryProvider).getMyBadgeStats();
});

final profileReportsProvider = FutureProvider.autoDispose<List<ReportModel>>((ref) {
  return ref.watch(reportRepositoryProvider).getMyReports();
});

/// Loads the nickname from the server (user_profiles table).
final _serverNicknameProvider = FutureProvider.autoDispose<String?>((ref) {
  return ref.watch(profileRepositoryProvider).getMyNickname();
});

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  /// 닉네임 설정 시트가 이미 표시된 적 있는지 추적 (중복 표시 방지)
  bool _sheetShown = false;
  int _prevLevel = 0;
  int _activeTab = 0; // 0: 활동, 1: 찜한 카페

  @override
  void initState() {
    super.initState();
    _checkNicknamePrompt();
  }

  Future<void> _checkNicknamePrompt() async {
    final shown = await NicknameNotifier.hasShownPrompt();
    if (mounted && shown) setState(() => _sheetShown = true);
  }

  void _showNicknameSheet() {
    if (_sheetShown) return;
    setState(() => _sheetShown = true);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const NicknameSetupSheet(),
    ).then((_) {
      // 시트 닫힌 후 닉네임이 여전히 없으면 다시 표시 허용
      if (!mounted) return;
      if (ref.read(nicknameProvider) == null) {
        setState(() => _sheetShown = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(profileStatsProvider);
    final reportsAsync = ref.watch(profileReportsProvider);
    final nickname = ref.watch(nicknameProvider);

    // 서버 닉네임 로드 시: 로컬 동기화 or 없으면 시트 표시
    // 딜레이(300ms)로 NicknameNotifier._load() 레이스 컨디션 방지
    ref.listen(_serverNicknameProvider, (_, next) {
      next.whenData((serverNick) {
        if (serverNick != null && serverNick.isNotEmpty) {
          if (ref.read(nicknameProvider) == null) {
            ref.read(nicknameProvider.notifier).set(serverNick);
          }
        } else {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (!mounted) return;
            if (ref.read(nicknameProvider) != null) return;
            _showNicknameSheet();
          });
        }
      });
    });

    final badgeDataAsync = ref.watch(profileBadgeDataProvider);

    // Level-up detection: compare prev vs current level after stats load
    ref.listen(profileStatsProvider, (_, next) {
      next.whenData((stats) {
        final totalXp = stats['total_xp'] as int? ?? 0;
        final newLevel = LevelService.calcLevel(totalXp).level;
        if (_prevLevel > 0 && newLevel > _prevLevel && mounted) {
          final lvl = LevelService.calcLevel(totalXp);
          showLevelUpAnimation(context, lvl);
        }
        _prevLevel = newLevel;
      });
    });

    final client = ref.watch(supabaseClientProvider);
    final isAdmin = AdminConfig.adminUserIds.contains(client.auth.currentUser?.id);
    final adminPreview = isAdmin && ref.watch(adminBadgePreviewProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: statsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.mintGreen),
        ),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (stats) {
          final total = stats['total'] as int? ?? 0;
          final totalCafes = stats['total_cafes'] as int? ?? 0;
          final totalXp = stats['total_xp'] as int? ?? 0;
          final level = LevelService.calcLevel(totalXp);

          // Resolve badge data (or use empty while loading)
          final badgeData = badgeDataAsync.asData?.value;
          final badgeStats = badgeData?.$1 ?? BadgeStats.empty();
          final earnedIds = badgeData?.$2 ?? <String>{};

          // Admin preview mode: force all badges unlocked for visual testing
          final rawBadges = LevelService.calcBadges(badgeStats, earnedIds);
          final badges = adminPreview
              ? rawBadges.map((b) => b.copyWith(unlocked: true)).toList()
              : rawBadges;

          return CustomScrollView(
            slivers: [
              // ── AppBar ──
              SliverAppBar(
                backgroundColor: Theme.of(context).colorScheme.surface,
                floating: true,
                pinned: false,
                automaticallyImplyLeading: false,
                elevation: 0,
                title: Text(
                  '프로필',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: Color(0xFF888888)),
                    onPressed: () => context.go('/settings'),
                  ),
                ],
              ),

              // Admin preview banner
              if (adminPreview)
                const SliverToBoxAdapter(child: _AdminPreviewBanner()),

              // ── Profile header (항상 표시) ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: _ProfileHeader(
                      nickname: nickname, level: level, badges: badges),
                ),
              ),

              // ── 탭 선택 바 ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: _ProfileTabBar(
                    activeTab: _activeTab,
                    onTap: (i) => setState(() => _activeTab = i),
                  ),
                ),
              ),

              // ══ Tab 0: 활동 ══════════════════════════════════
              if (_activeTab == 0) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LevelCard(level: level),
                        const SizedBox(height: 12),
                        _StatsRow(
                            total: total,
                            totalCafes: totalCafes,
                            totalXp: totalXp),
                        const SizedBox(height: 16),
                        _BadgeSection(badges: badges),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                // Report list
                reportsAsync.when(
                  loading: () => const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.mintGreen)),
                    ),
                  ),
                  error: (e, _) =>
                      SliverToBoxAdapter(child: Center(child: Text(e.toString()))),
                  data: (reports) {
                    if (reports.isEmpty) {
                      return SliverMainAxisGroup(slivers: [
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: Text(
                              '내 측정 기록',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(child: _EmptyReports()),
                      ]);
                    }
                    final displayCount =
                        reports.length > 10 ? 10 : reports.length;
                    final hasMore = reports.length > 10;
                    return SliverMainAxisGroup(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: Row(
                              children: [
                                const Text(
                                  '내 측정 기록',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                                const Spacer(),
                                if (hasMore)
                                  GestureDetector(
                                    onTap: () =>
                                        showAllReportsSheet(context, reports),
                                    child: const Text(
                                      '전체보기',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.mintGreen,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _ReportTile(report: reports[i]),
                            childCount: displayCount,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],

              // ══ Tab 1: 찜한 카페 ═════════════════════════════
              if (_activeTab == 1)
                const _BookmarkedSpotsSection(),

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Profile header card
// ──────────────────────────────────────────────────────────────
class _ProfileHeader extends ConsumerWidget {
  final String? nickname;
  final UserLevel level;
  final List<BadgeInfo> badges;

  const _ProfileHeader({
    required this.nickname,
    required this.level,
    required this.badges,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayName = (nickname != null && nickname!.isNotEmpty) ? nickname! : '익명 사용자';
    final initial = displayName.substring(0, 1).toUpperCase();
    final repBadgeId = ref.watch(repBadgeProvider);
    final repBadge = repBadgeId != null
        ? badges.where((b) => b.id == repBadgeId && b.unlocked).firstOrNull
        : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Avatar (tappable) ──
          GestureDetector(
            onTap: () => _showBadgePicker(context, ref),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.brandGradient,
                  ),
                  child: Center(
                    child: repBadge != null
                        ? Text(repBadge.emoji, style: const TextStyle(fontSize: 30))
                        : Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                // Edit indicator badge
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.mintGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.edit_rounded, size: 10, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.mintGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(level.icon, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        'Lv.${level.level} ${level.name}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mintGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBadgePicker(BuildContext context, WidgetRef ref) {
    final earnedBadges = badges.where((b) => b.unlocked).toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BadgePickerSheet(
        earnedBadges: earnedBadges,
        currentRepBadgeId: ref.read(repBadgeProvider),
        onSelect: (id) => ref.read(repBadgeProvider.notifier).set(id),
        onClear: () => ref.read(repBadgeProvider.notifier).clear(),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Badge picker bottom sheet
// ──────────────────────────────────────────────────────────────
class _BadgePickerSheet extends StatefulWidget {
  final List<BadgeInfo> earnedBadges;
  final String? currentRepBadgeId;
  final ValueChanged<String> onSelect;
  final VoidCallback onClear;

  const _BadgePickerSheet({
    required this.earnedBadges,
    required this.currentRepBadgeId,
    required this.onSelect,
    required this.onClear,
  });

  @override
  State<_BadgePickerSheet> createState() => _BadgePickerSheetState();
}

class _BadgePickerSheetState extends State<_BadgePickerSheet> {
  late String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentRepBadgeId;
  }

  @override
  Widget build(BuildContext context) {
    final badges = widget.earnedBadges;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8F6F1),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Text(
                    '대표 뱃지 선택',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  if (_selected != null)
                    GestureDetector(
                      onTap: () {
                        widget.onClear();
                        Navigator.pop(context);
                      },
                      child: Text(
                        '기본으로 되돌리기',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Sub-label
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  badges.isEmpty
                      ? '아직 획득한 뱃지가 없어요'
                      : '획득한 뱃지 중 프로필에 표시할 1개를 선택하세요',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                ),
              ),
            ),
            // Badge grid
            Expanded(
              child: badges.isEmpty
                  ? Center(
                      child: Text(
                        '뱃지를 획득하면 여기에 표시돼요 🏅',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                      ),
                    )
                  : GridView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: badges.length,
                      itemBuilder: (_, i) {
                        final badge = badges[i];
                        final isActive = _selected == badge.id;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selected = badge.id);
                            widget.onSelect(badge.id);
                            Navigator.pop(context);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.mintGreen.withValues(alpha: 0.15)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isActive
                                    ? AppColors.mintGreen
                                    : Colors.grey.shade200,
                                width: isActive ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Text(badge.emoji,
                                        style: const TextStyle(fontSize: 28)),
                                    if (isActive)
                                      Positioned(
                                        top: -4,
                                        right: -4,
                                        child: Container(
                                          width: 16,
                                          height: 16,
                                          decoration: const BoxDecoration(
                                            color: AppColors.mintGreen,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.check,
                                              size: 10, color: Colors.white),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  badge.label,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: isActive
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isActive
                                        ? AppColors.mintGreen
                                        : const Color(0xFF666666),
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Level progress card
// ──────────────────────────────────────────────────────────────
class _LevelCard extends StatelessWidget {
  final UserLevel level;
  const _LevelCard({required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(level.icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lv.${level.level} ${level.name}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      level.isMax
                          ? '최고 레벨 달성!'
                          : '다음 레벨까지 ${level.nextTarget - level.currentXp} XP',
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: level.progress,
              color: AppColors.mintGreen,
              backgroundColor: AppColors.mintGreen.withValues(alpha: 0.12),
              minHeight: 8,
            ),
          ),
          if (!level.isMax) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${level.currentXp} XP',
                  style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                ),
                Text(
                  '${level.nextTarget} XP',
                  style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Stats row (2 cards)
// ──────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final int total;
  final int totalCafes;
  final int totalXp;

  const _StatsRow({required this.total, required this.totalCafes, required this.totalXp});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(
          label: '총 측정',
          value: '$total회',
          icon: Icons.bar_chart_rounded,
          color: AppColors.mintGreen,
        ),
        const SizedBox(width: 8),
        _StatCard(
          label: '등록 카페',
          value: '$totalCafes곳',
          icon: Icons.coffee_rounded,
          color: const Color(0xFFFF8C69),
        ),
        const SizedBox(width: 8),
        _StatCard(
          label: '누적 XP',
          value: '$totalXp XP',
          icon: Icons.stars_rounded,
          color: AppColors.skyBlue,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Badge section
// ──────────────────────────────────────────────────────────────
class _BadgeSection extends StatelessWidget {
  final List<BadgeInfo> badges;
  const _BadgeSection({required this.badges});

  @override
  Widget build(BuildContext context) {
    final unlockedCount = badges.where((b) => b.unlocked).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '획득 뱃지',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$unlockedCount / ${badges.length}',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => showBadgeDetailSheet(context, badges),
              child: const Text(
                '전체보기',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mintGreen,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: badges.length,
            separatorBuilder: (ctx, i) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) => _BadgeTile(
              badge: badges[i],
              onTap: () => showBadgeDetailSheet(context, badges),
            ),
          ),
        ),
      ],
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final BadgeInfo badge;
  final VoidCallback onTap;
  const _BadgeTile({required this.badge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: badge.unlocked
              ? Theme.of(context).colorScheme.surface
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: badge.unlocked
                ? AppColors.mintGreen.withValues(alpha: 0.3)
                : Theme.of(context).dividerColor,
          ),
          boxShadow: badge.unlocked
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              badge.unlocked ? badge.emoji : '🔒',
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 4),
            Text(
              badge.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: badge.unlocked
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Report tile
// ──────────────────────────────────────────────────────────────
class _ReportTile extends StatelessWidget {
  final ReportModel report;
  const _ReportTile({required this.report});

  @override
  Widget build(BuildContext context) {
    final dbColor = AppColors.dbColor(report.measuredDb);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // dB badge
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: dbColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  report.measuredDb.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: dbColor,
                  ),
                ),
                Text('dB', style: TextStyle(fontSize: 9, color: dbColor)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.spotName ?? '알 수 없는 카페',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (report.selectedSticker != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: dbColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${report.selectedSticker!.emoji} ${report.selectedSticker!.label}',
                          style: TextStyle(
                            fontSize: 10,
                            color: dbColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else if (report.tagText != null && report.tagText!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.mintGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          report.tagText!,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.mintGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const Spacer(),
                    Text(
                      _timeAgo(report.createdAt),
                      style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
                if (report.moodTag != null && report.moodTag!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '"${report.moodTag}"',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 1) return '${diff.inDays}일 전';
    if (diff.inHours >= 1) return '${diff.inHours}시간 전';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}분 전';
    return '방금 전';
  }
}

// ──────────────────────────────────────────────────────────────
// Admin: preview mode active banner
// ──────────────────────────────────────────────────────────────
class _AdminPreviewBanner extends StatelessWidget {
  const _AdminPreviewBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.mintGreen.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.admin_panel_settings_rounded,
              size: 14, color: AppColors.mintGreen),
          const SizedBox(width: 6),
          const Text(
            '관리자 뱃지 미리보기 ON — 모든 뱃지 획득 상태로 표시 중',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.mintGreen,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// All reports bottom sheet
// ──────────────────────────────────────────────────────────────
void showAllReportsSheet(BuildContext context, List<ReportModel> reports) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AllReportsSheet(reports: reports),
  );
}

class _AllReportsSheet extends StatelessWidget {
  final List<ReportModel> reports;
  const _AllReportsSheet({required this.reports});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.8,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text(
                      '내 측정 기록',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.mintGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${reports.length}개',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mintGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.only(bottom: 32),
                  itemCount: reports.length,
                  itemBuilder: (ctx, i) => _ReportTile(report: reports[i]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Empty state
// ──────────────────────────────────────────────────────────────
class _EmptyReports extends StatelessWidget {
  const _EmptyReports();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.graphic_eq_rounded, size: 56, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text(
            '아직 측정 기록이 없어요',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '첫 번째 카페 소음을 측정해 보세요!',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// 프로필 탭 선택 바 (활동 / 찜한 카페)
// ──────────────────────────────────────────────────────────────
class _ProfileTabBar extends StatelessWidget {
  final int activeTab;
  final ValueChanged<int> onTap;

  const _ProfileTabBar({required this.activeTab, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkBgCard
            : const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _TabItem(label: '활동', index: 0, activeTab: activeTab, onTap: onTap),
          _TabItem(
              label: '찜한 카페',
              index: 1,
              activeTab: activeTab,
              onTap: onTap),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final int index;
  final int activeTab;
  final ValueChanged<int> onTap;

  const _TabItem({
    required this.label,
    required this.index,
    required this.activeTab,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == activeTab;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isActive
                ? (isDark ? AppColors.darkBgSurface : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight:
                    isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive
                    ? AppColors.mintGreen
                    : (isDark
                        ? AppColors.darkTextSecondary
                        : const Color(0xFF888888)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// 찜한 카페 탭 콘텐츠
// ──────────────────────────────────────────────────────────────
class _BookmarkedSpotsSection extends ConsumerWidget {
  const _BookmarkedSpotsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spotsAsync = ref.watch(bookmarkedSpotsProvider);
    return spotsAsync.when(
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(
              child: CircularProgressIndicator(color: AppColors.mintGreen)),
        ),
      ),
      error: (e, _) =>
          SliverToBoxAdapter(child: Center(child: Text(e.toString()))),
      data: (spots) {
        if (spots.isEmpty) {
          return const SliverToBoxAdapter(child: _EmptyBookmarks());
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => _BookmarkedSpotTile(spot: spots[i]),
            childCount: spots.length,
          ),
        );
      },
    );
  }
}

class _EmptyBookmarks extends StatelessWidget {
  const _EmptyBookmarks();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.favorite_border,
              size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            '아직 찜한 카페가 없어요',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500),
          ),
          const SizedBox(height: 6),
          Text(
            '카페 상세에서 하트를 눌러 저장해보세요',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}

class _BookmarkedSpotTile extends StatelessWidget {
  final SpotModel spot;
  const _BookmarkedSpotTile({required this.spot});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dbColor = AppColors.dbColor(spot.averageDb);
    final hasData = spot.reportCount > 0;

    return GestureDetector(
      onTap: () => context.push('/spot/${spot.id}', extra: spot),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
              blurRadius: 12,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              // 왼쪽 dB 컬러 바
              Container(width: 5, height: 80, color: dbColor),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              spot.name,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (spot.formattedAddress != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  spot.formattedAddress!,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.bar_chart,
                                    size: 12,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.textSecondary),
                                const SizedBox(width: 2),
                                Text(
                                  '${spot.reportCount}회',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // 오른쪽 dB 숫자
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            hasData
                                ? spot.averageDb.toStringAsFixed(0)
                                : '--',
                            style: TextStyle(
                              fontSize: 28,
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
                      Icon(Icons.chevron_right,
                          size: 18,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.25)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
