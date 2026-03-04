import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/level_service.dart' show LevelService;
import '../../../features/map/domain/spot_model.dart';
import '../data/ranking_repository.dart';

class RankingScreen extends ConsumerStatefulWidget {
  const RankingScreen({super.key});

  @override
  ConsumerState<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends ConsumerState<RankingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // 랭킹 탭 진입 시 항상 최신 데이터로 갱신
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(quietCafeRankingProvider);
      ref.invalidate(userRankingProvider);
      ref.invalidate(weeklyCafeRankingProvider);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBgBase
          : const Color(0xFFF8F6F1),
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBgSurface : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? AppColors.darkDivider
                      : AppColors.mintGreen.withValues(alpha: 0.1),
                ),
              ),
            ),
            padding: EdgeInsets.only(top: top),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Text(
                  AppStrings.rankingTitle,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  labelColor: AppColors.mintGreen,
                  unselectedLabelColor: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                  indicatorColor: AppColors.mintGreen,
                  indicatorWeight: 2,
                  dividerHeight: 0,
                  labelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: const TextStyle(fontSize: 13),
                  tabs: const [
                    Tab(text: AppStrings.rankingTabQuiet),
                    Tab(text: AppStrings.rankingTabMeasurers),
                    Tab(text: AppStrings.rankingTabWeekly),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _QuietCafeTab(),
                _MeasurerTab(),
                _WeeklyTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Tab 1: 잔잔한 카페 TOP
// ──────────────────────────────────────────────────────────────
class _QuietCafeTab extends ConsumerWidget {
  const _QuietCafeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(quietCafeRankingProvider);
    return RefreshIndicator(
      color: AppColors.mintGreen,
      onRefresh: () async {
        ref.invalidate(quietCafeRankingProvider);
        await ref.read(quietCafeRankingProvider.future).catchError((_) => <QuietCafeRankItem>[]);
      },
      child: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.mintGreen)),
        error: (err, st) =>
            _RetryView(onRetry: () => ref.invalidate(quietCafeRankingProvider)),
        data: (list) => list.isEmpty
            ? const _EmptyRankView()
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: list.length,
              itemBuilder: (ctx, i) {
                final item = list[i];
                final dbColor = AppColors.dbColor(item.averageDb);
                final sticker = item.representativeSticker != null
                    ? StickerTypeX.fromKey(item.representativeSticker!)
                    : null;
                return _GlassRankCard(
                  rank: i + 1,
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${item.averageDb.toStringAsFixed(1)} dB',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: dbColor,
                        ),
                      ),
                      if (sticker != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: dbColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            sticker.label,
                            style: TextStyle(
                                fontSize: 10,
                                color: dbColor,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                  child: _CafeRankInfo(
                    name: item.name,
                    address: item.formattedAddress,
                    subLabel: '${item.reportCount}회 측정',
                  ),
                );
              },
            ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Tab 2: 바이브 탐험가 TOP
// ──────────────────────────────────────────────────────────────
class _MeasurerTab extends ConsumerWidget {
  const _MeasurerTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final async = ref.watch(userRankingProvider);
    return RefreshIndicator(
      color: AppColors.mintGreen,
      onRefresh: () async {
        ref.invalidate(userRankingProvider);
        await ref.read(userRankingProvider.future).catchError((_) => <UserRankItem>[]);
      },
      child: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.mintGreen)),
        error: (err, st) =>
            _RetryView(onRetry: () => ref.invalidate(userRankingProvider)),
        data: (list) => list.isEmpty
            ? const _EmptyMeasurerView()
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: list.length,
              itemBuilder: (ctx, i) {
                final item = list[i];
                final userLevel = LevelService.calcLevel(item.totalXp);
                final lv = userLevel.level;
                final lvName = AppStrings.levelNames[(lv - 1).clamp(0, AppStrings.levelNames.length - 1)];
                return _GlassRankCard(
                  rank: i + 1,
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${item.totalReports}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.mintGreen,
                        ),
                      ),
                      Text(
                        '총 측정',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.mintGreen.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            userLevel.icon,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              item.nickname,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Lv.$lv $lvName',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Tab 3: 이번 주 인기 바이브 카페
// ──────────────────────────────────────────────────────────────
class _WeeklyTab extends ConsumerWidget {
  const _WeeklyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(weeklyCafeRankingProvider);
    return RefreshIndicator(
      color: AppColors.mintGreen,
      onRefresh: () async {
        ref.invalidate(weeklyCafeRankingProvider);
        await ref.read(weeklyCafeRankingProvider.future).catchError((_) => <WeeklyCafeRankItem>[]);
      },
      child: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.mintGreen)),
        error: (err, st) =>
            _RetryView(onRetry: () => ref.invalidate(weeklyCafeRankingProvider)),
        data: (list) => list.isEmpty
            ? const _EmptyRankView()
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: list.length,
              itemBuilder: (ctx, i) {
                final item = list[i];
                final trendUp = item.weeklyCount > 0 &&
                    item.totalCount > 0 &&
                    (item.weeklyCount / item.totalCount) > 0.3;
                return _GlassRankCard(
                  rank: i + 1,
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${item.weeklyCount}회',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.mintGreen,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            trendUp
                                ? Icons.trending_up
                                : Icons.trending_flat,
                            size: 14,
                            color: trendUp
                                ? AppColors.mintGreen
                                : Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            trendUp ? '상승중' : '유지중',
                            style: TextStyle(
                              fontSize: 10,
                              color: trendUp
                                  ? AppColors.mintGreen
                                  : Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  child: _CafeRankInfo(
                    name: item.name,
                    address: item.formattedAddress,
                    subLabel: '총 ${item.totalCount}회',
                  ),
                );
              },
            ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Glassmorphism 카드
// ──────────────────────────────────────────────────────────────
class _GlassRankCard extends StatelessWidget {
  final int rank;
  final Widget child;
  final Widget trailing;

  const _GlassRankCard({
    required this.rank,
    required this.child,
    required this.trailing,
  });

  static const _medalColors = [
    Color(0xFFFFD700),
    Color(0xFFC0C0C0),
    Color(0xFFCD7F32),
  ];

  @override
  Widget build(BuildContext context) {
    final isMedal = rank <= 3;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.8),
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.2)
                      : AppColors.mintGreen.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isMedal
                        ? _medalColors[rank - 1].withValues(alpha: 0.18)
                        : isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : AppColors.mintGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: isMedal
                        ? const Text('🏅', style: TextStyle(fontSize: 18))
                        : Text(
                            '$rank',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.textSecondary,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: child),
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CafeRankInfo extends StatelessWidget {
  final String name;
  final String? address;
  final String subLabel;

  const _CafeRankInfo({
    required this.name,
    this.address,
    required this.subLabel,
  });

  String get _neighborhood {
    if (address == null) return '';
    final parts = address!.split(' ');
    for (final p in parts.reversed) {
      if (p.endsWith('동') || p.endsWith('구') || p.endsWith('로')) return p;
    }
    return parts.last;
  }

  @override
  Widget build(BuildContext context) {
    final nb = _neighborhood;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          name,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            if (nb.isNotEmpty) ...[
              Icon(Icons.location_on_outlined,
                  size: 12,
                  color: isDark
                      ? AppColors.darkTextHint
                      : AppColors.textSecondary),
              const SizedBox(width: 2),
              Text(nb,
                  style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary)),
              const SizedBox(width: 8),
            ],
            Icon(Icons.bar_chart,
                size: 12,
                color: isDark
                    ? AppColors.darkTextHint
                    : AppColors.textSecondary),
            const SizedBox(width: 2),
            Text(subLabel,
                style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary)),
          ],
        ),
      ],
    );
  }
}

class _EmptyRankView extends StatelessWidget {
  const _EmptyRankView();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events_outlined,
              size: 64,
              color: isDark ? AppColors.darkTextHint : AppColors.textHint),
          const SizedBox(height: 12),
          Text('아직 데이터가 없어요',
              style: TextStyle(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary)),
          Text('첫 측정을 해보세요!',
              style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.darkTextHint
                      : AppColors.textHint)),
        ],
      ),
    );
  }
}

class _EmptyMeasurerView extends StatelessWidget {
  const _EmptyMeasurerView();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_outlined,
                size: 64,
                color: isDark ? AppColors.darkTextHint : AppColors.textHint),
            const SizedBox(height: 12),
            Text(
              '랭킹 집계 준비 중',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '카페를 측정할수록\n랭킹에 반영됩니다',
              style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.darkTextHint
                      : AppColors.textHint),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _RetryView extends StatelessWidget {
  final VoidCallback onRetry;
  const _RetryView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined,
              size: 48,
              color: isDark ? AppColors.darkTextHint : AppColors.textHint),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            child: const Text('다시 시도',
                style: TextStyle(color: AppColors.mintGreen)),
          ),
        ],
      ),
    );
  }
}
