import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/nickname_service.dart';
import '../../../core/utils/level_service.dart';
import '../../map/domain/spot_model.dart';
import '../../report/data/report_repository.dart';
import '../../report/domain/report_model.dart';
import '../data/profile_repository.dart';
import 'nickname_setup_sheet.dart';

final _myStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.watch(reportRepositoryProvider).getMyStats();
});

final _myReportsProvider = FutureProvider.autoDispose<List<ReportModel>>((ref) {
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
      backgroundColor: Colors.white,
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
    final statsAsync = ref.watch(_myStatsProvider);
    final reportsAsync = ref.watch(_myReportsProvider);
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

    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F1),
      body: statsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.mintGreen),
        ),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (stats) {
          final total = stats['total'] as int? ?? 0;
          final totalCafes = stats['total_cafes'] as int? ?? 0;
          final hasQuietCafe = stats['has_quiet_cafe'] as bool? ?? false;
          final level = LevelService.calcLevel(total);
          final points = LevelService.calcPoints(total, totalCafes);
          final badges = LevelService.calcBadges(
            totalReports: total,
            totalCafes: totalCafes,
            hasQuietCafe: hasQuietCafe,
          );

          return CustomScrollView(
            slivers: [
              // ── AppBar ──
              SliverAppBar(
                backgroundColor: Colors.white,
                floating: true,
                pinned: false,
                automaticallyImplyLeading: false,
                elevation: 0,
                title: const Text(
                  '프로필',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: Color(0xFF888888)),
                    onPressed: () => context.go('/settings'),
                  ),
                ],
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      _ProfileHeader(nickname: nickname, level: level),
                      const SizedBox(height: 12),
                      _LevelCard(level: level),
                      const SizedBox(height: 12),
                      _StatsRow(total: total, totalCafes: totalCafes, points: points),
                      const SizedBox(height: 16),
                      _BadgeSection(badges: badges),
                      const SizedBox(height: 20),
                      const Text(
                        '내 측정 기록',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              // ── Report list ──
              reportsAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator(color: AppColors.mintGreen)),
                  ),
                ),
                error: (e, _) =>
                    SliverToBoxAdapter(child: Center(child: Text(e.toString()))),
                data: (reports) => reports.isEmpty
                    ? const SliverToBoxAdapter(child: _EmptyReports())
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => _ReportTile(report: reports[i]),
                          childCount: reports.length,
                        ),
                      ),
              ),

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
class _ProfileHeader extends StatelessWidget {
  final String? nickname;
  final UserLevel level;

  const _ProfileHeader({
    required this.nickname,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = (nickname != null && nickname!.isNotEmpty) ? nickname! : '익명 사용자';
    final initial = displayName.substring(0, 1).toUpperCase();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
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
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.brandGradient,
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.mintGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Lv.${level.level} ${level.name}',
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
        ],
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

  static const _levelEmojis = ['☕', '🎧', '🏆', '⭐', '👑'];

  @override
  Widget build(BuildContext context) {
    final emoji = _levelEmojis[(level.level - 1).clamp(0, 4)];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lv.${level.level} ${level.name}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    Text(
                      level.isMax
                          ? '최고 레벨 달성!'
                          : '다음 레벨까지 ${level.nextTarget - level.current}회',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
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
                  '${level.current}회',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                Text(
                  '${level.nextTarget}회',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
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
  final int points;

  const _StatsRow({required this.total, required this.totalCafes, required this.points});

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
          label: '획득 포인트',
          value: '${points}P',
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
          color: Colors.white,
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
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '획득 뱃지',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: badges.length,
            separatorBuilder: (ctx, i) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) => _BadgeTile(badge: badges[i]),
          ),
        ),
      ],
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final BadgeInfo badge;
  const _BadgeTile({required this.badge});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: badge.unlocked ? Colors.white : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: badge.unlocked
              ? AppColors.mintGreen.withValues(alpha: 0.3)
              : Colors.grey.shade200,
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
              color: badge.unlocked ? const Color(0xFF1A1A1A) : Colors.grey.shade400,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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
        color: Colors.white,
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
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: dbColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        report.selectedSticker.label,
                        style: TextStyle(
                          fontSize: 10,
                          color: dbColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _timeAgo(report.createdAt),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
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
