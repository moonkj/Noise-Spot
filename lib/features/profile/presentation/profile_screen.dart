import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/nickname_service.dart';
import '../../../core/utils/db_classifier.dart';
import '../../report/data/report_repository.dart';
import '../../report/domain/report_model.dart';
import '../../map/domain/spot_model.dart';

final _statsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(reportRepositoryProvider).getMyStats();
});

final _myReportsProvider = FutureProvider.autoDispose<List<ReportModel>>((ref) async {
  return ref.watch(reportRepositoryProvider).getMyReports();
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_statsProvider);
    final reportsAsync = ref.watch(_myReportsProvider);
    final nickname = ref.watch(nicknameProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('마이페이지'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.go('/map'),
        ),
      ),
      body: statsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.mintGreen)),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (stats) => CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile header
                    _ProfileHeader(
                      nickname: nickname,
                      totalReports: stats['total'] as int? ?? 0,
                      onEditTap: () => context.go('/settings'),
                    ),
                    const SizedBox(height: 24),
                    // Stats cards
                    _StatsRow(stats: stats),
                    const SizedBox(height: 24),
                    // Trust grade
                    _TrustGradeCard(totalReports: stats['total'] as int),
                    const SizedBox(height: 24),
                    Text(
                      '측정 기록',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            // Report list
            reportsAsync.when(
              loading: () => const SliverToBoxAdapter(
                child: Center(child: CircularProgressIndicator(color: AppColors.mintGreen)),
              ),
              error: (e, _) =>
                  SliverToBoxAdapter(child: Center(child: Text(e.toString()))),
              data: (reports) => reports.isEmpty
                  ? const SliverToBoxAdapter(child: _EmptyReports())
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _ReportListTile(report: reports[i]),
                        childCount: reports.length,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String? nickname;
  final int totalReports;
  final VoidCallback onEditTap;

  const _ProfileHeader({
    required this.nickname,
    required this.totalReports,
    required this.onEditTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasName = nickname != null && nickname!.isNotEmpty;
    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.bgGradient,
          ),
          child: const Icon(Icons.person_rounded, color: Colors.white, size: 30),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasName ? nickname! : '익명 사용자',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: hasName
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                hasName ? '측정 $totalReports회' : '설정에서 이름을 정해보세요',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit_rounded, size: 18, color: AppColors.textHint),
          onPressed: onEditTap,
          tooltip: '설정',
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final total = stats['total'] as int? ?? 0;
    final avgDb = (stats['avg_db'] as num? ?? 0).toDouble();

    return Row(
      children: [
        _StatCard(
          label: AppStrings.totalReports,
          value: '$total회',
          icon: Icons.bar_chart_rounded,
          color: AppColors.mintGreen,
        ),
        const SizedBox(width: 12),
        _StatCard(
          label: AppStrings.avgDb,
          value: '${avgDb.toStringAsFixed(1)} dB',
          icon: Icons.graphic_eq_rounded,
          color: DbClassifier.colorFromDb(avgDb),
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
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _TrustGradeCard extends StatelessWidget {
  final int totalReports;
  const _TrustGradeCard({required this.totalReports});

  @override
  Widget build(BuildContext context) {
    final (grade, color, next, nextCount) = _gradeInfo(totalReports);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.1), Colors.white],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium_rounded, color: color),
              const SizedBox(width: 8),
              Text(
                grade,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          if (next != null) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: _progress(totalReports),
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              minHeight: 6,
            ),
            const SizedBox(height: 6),
            Text(
              '$next 달성까지 ${nextCount! - totalReports}회 남았어요',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }

  (String grade, Color color, String? next, int? nextCount) _gradeInfo(
      int count) {
    if (count >= 50) return ('Gold', AppColors.trustGold, null, null);
    if (count >= 20) return ('Silver', AppColors.trustSilver, 'Gold', 50);
    if (count >= 5) return ('Bronze', AppColors.trustBronze, 'Silver', 20);
    return ('Member', AppColors.textHint, 'Bronze', 5);
  }

  double _progress(int count) {
    if (count >= 50) return 1.0;
    if (count >= 20) return (count - 20) / 30;
    if (count >= 5) return (count - 5) / 15;
    return count / 5;
  }
}

class _EmptyReports extends StatelessWidget {
  const _EmptyReports();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Column(
        children: [
          Icon(
            Icons.graphic_eq_rounded,
            size: 48,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 16),
          const Text(
            '아직 측정 기록이 없어요',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '지도에서 스팟을 선택하고\n첫 번째 소음을 측정해 보세요!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textHint,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportListTile extends StatelessWidget {
  final ReportModel report;
  const _ReportListTile({required this.report});

  @override
  Widget build(BuildContext context) {
    final color = DbClassifier.colorFromDb(report.measuredDb);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Text(
            report.selectedSticker.emoji,
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.selectedSticker.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  _formatDate(report.createdAt),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${report.measuredDb.toStringAsFixed(1)} dB',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }
}
