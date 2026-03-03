import 'dart:math' show cos, sin, pi;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../bookmark/data/bookmark_repository.dart';
import '../../../core/services/badge_service.dart';
import '../../../core/services/places_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/db_classifier.dart';
import '../../../features/map/domain/spot_model.dart';
import '../../../features/profile/presentation/widgets/badge_earned_popup.dart';
import '../../../features/report/data/report_repository.dart';

// ──────────────────────────────────────────────────────────────
// Providers
// ──────────────────────────────────────────────────────────────

final _hourlyNoiseProvider = FutureProvider.autoDispose
    .family<List<(int, double)>, String>(
  (ref, spotId) =>
      ref.read(reportRepositoryProvider).getSpotHourlyNoise(spotId),
);

/// Live report count + average dB from DB — overrides stale SpotModel values.
/// Public so report_screen can invalidate after submission.
final spotLiveStatsProvider = FutureProvider.autoDispose
    .family<({int count, double avgDb}), String>(
  (ref, spotId) =>
      ref.read(reportRepositoryProvider).getSpotStats(spotId),
);

/// Public so report_screen can invalidate after submission.
final spotRecentReportsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>(
  (ref, spotId) =>
      ref.read(reportRepositoryProvider).getSpotRecentReports(spotId, limit: 30),
);

/// Fetches a photo URL for the given spot.
/// - Admin-uploaded photos (Supabase Storage URLs) are permanent → use from DB.
/// - Google Places CDN URLs expire after ~1 day → always fetch fresh from API.
final _spotPhotoProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, googlePlaceId) async {
  // Google Places spots: always fetch a fresh CDN URL.
  if (googlePlaceId.isEmpty) return null;
  return ref.read(placesServiceProvider).getPhotoUrl(googlePlaceId);
});

// ──────────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────────

String _timeAgo(DateTime? dt) {
  if (dt == null) return '측정 없음';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return '방금';
  if (diff.inHours < 1) return '${diff.inMinutes}분 전';
  if (diff.inDays < 1) return '${diff.inHours}시간 전';
  return '${diff.inDays}일 전';
}

List<String> _deriveVibeTags(SpotModel spot) {
  final tags = <String>[];
  if (spot.representativeSticker != null) {
    tags.add('#${spot.representativeSticker!.label}');
  }
  if (spot.reportCount >= 20) tags.add('#자주 방문');
  if (spot.trustScore >= 2) tags.add('#신뢰도 높음');
  return tags;
}

// ──────────────────────────────────────────────────────────────
// SpotDetailScreen
// ──────────────────────────────────────────────────────────────

class SpotDetailScreen extends ConsumerStatefulWidget {
  final SpotModel spot;
  const SpotDetailScreen({super.key, required this.spot});

  @override
  ConsumerState<SpotDetailScreen> createState() => _SpotDetailScreenState();
}

class _SpotDetailScreenState extends ConsumerState<SpotDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Award B04 (카페 상세 첫 방문) if not yet earned
    WidgetsBinding.instance.addPostFrameCallback((_) => _awardB04());
  }

  Future<void> _awardB04() async {
    try {
      final client = ref.read(supabaseClientProvider);
      final badge = await BadgeService.awardInstantBadge(
        client: client,
        badgeId: 'B04',
      );
      if (badge != null && mounted) {
        await showBadgeEarnedPopup(context, badge);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final spot = widget.spot;
    final liveStats = ref.watch(spotLiveStatsProvider(spot.id)).asData?.value;
    final liveCount = liveStats?.count ?? spot.reportCount;
    final liveAvgDb = (liveStats != null && liveStats.count > 0)
        ? liveStats.avgDb
        : spot.averageDb;
    final dbColor = DbClassifier.colorFromDb(liveAvgDb);
    final hourlyAsync = ref.watch(_hourlyNoiseProvider(spot.id));
    final recentAsync = ref.watch(spotRecentReportsProvider(spot.id));
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ── Hero AppBar ──────────────────────────────────
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: AppColors.skyBlue,
                foregroundColor: Colors.white,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  onPressed: () => context.pop(),
                ),
                actions: [
                  _BookmarkButton(spot: spot),
                  IconButton(
                    icon: const Icon(Icons.ios_share_outlined, size: 22),
                    onPressed: () {
                      final avgDb = liveAvgDb > 0 ? liveAvgDb : spot.averageDb;
                      final label = DbClassifier.labelFromDb(avgDb);
                      final addr = spot.formattedAddress?.isNotEmpty == true
                          ? '\n📍 ${spot.formattedAddress}'
                          : '';
                      Share.share(
                        '☕ ${spot.name}$addr\n'
                        '🎵 평균 ${avgDb.toStringAsFixed(1)}dB — $label\n\n'
                        '카페바이브 앱에서 조용한 카페를 찾아보세요\n'
                        '#카페바이브 #조용한카페 #소음측정',
                        subject: '${spot.name} — 카페바이브',
                      );
                    },
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding:
                      const EdgeInsets.only(left: 56, right: 48, bottom: 12),
                  title: Text(
                    spot.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  background: _HeroBackground(spot: spot, dbColor: dbColor),
                ),
              ),

              // ── Summary Banner ───────────────────────────────
              SliverToBoxAdapter(
                child: _SummaryBanner(
                  spot: spot,
                  dbColor: dbColor,
                  liveCount: liveCount,
                  liveAvgDb: liveAvgDb,
                ),
              ),

              // ── Hourly Chart ─────────────────────────────────
              SliverToBoxAdapter(
                child: _HourlyChartCard(
                  hourlyAsync: hourlyAsync,
                  dbColor: dbColor,
                ),
              ),

              // ── Vibe Tags ────────────────────────────────────
              SliverToBoxAdapter(
                child: _VibeTagsCard(spot: spot, recentAsync: recentAsync),
              ),

              // ── Recent Measurements ──────────────────────────
              SliverToBoxAdapter(
                child: _RecentReportsCard(
                  recentAsync: recentAsync,
                  dbColor: dbColor,
                ),
              ),

              // bottom safe area for sticky button
              SliverToBoxAdapter(
                child: SizedBox(height: bottomPad + 80),
              ),
            ],
          ),

          // ── Sticky bottom button ─────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _StickyMeasureButton(spot: spot, bottomPad: bottomPad),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Hero Background
// ──────────────────────────────────────────────────────────────

class _HeroBackground extends ConsumerWidget {
  final SpotModel spot;
  final Color dbColor;
  const _HeroBackground({required this.spot, required this.dbColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Admin-uploaded photos (Supabase Storage) are permanent — use directly.
    // Google Places CDN URLs expire — fetch fresh via provider.
    final cachedUrl = spot.photoUrl;
    final isSupabaseUrl = cachedUrl != null && cachedUrl.contains('supabase.co/storage');
    final googlePhotoUrl = (spot.googlePlaceId != null && !isSupabaseUrl)
        ? ref.watch(_spotPhotoProvider(spot.googlePlaceId!)).asData?.value
        : null;
    final photoUrl = isSupabaseUrl ? cachedUrl : googlePhotoUrl;

    if (photoUrl != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            photoUrl,
            fit: BoxFit.cover,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) return child;
              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                child: child,
              );
            },
            errorBuilder: (context, error, stack) => _gradientBackground(),
          ),
          // Dark gradient overlay so AppBar title stays readable
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x4D000000), Color(0x99000000)],
              ),
            ),
          ),
        ],
      );
    }

    return _gradientBackground();
  }

  Widget _gradientBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.skyBlue, AppColors.mintGreen],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Icon(
                  Icons.local_cafe_rounded,
                  size: 36,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (spot.formattedAddress != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.place_outlined,
                        size: 13, color: Colors.white70),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        spot.formattedAddress!,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white70),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Summary Banner
// ──────────────────────────────────────────────────────────────

class _SummaryBanner extends StatelessWidget {
  final SpotModel spot;
  final Color dbColor;
  final int liveCount;
  final double liveAvgDb;
  const _SummaryBanner({
    required this.spot,
    required this.dbColor,
    required this.liveCount,
    required this.liveAvgDb,
  });

  @override
  Widget build(BuildContext context) {
    final sticker = spot.representativeSticker;
    return Container(
      color: dbColor.withValues(alpha: 0.10),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.graphic_eq, size: 16, color: dbColor),
          const SizedBox(width: 6),
          Text(
            liveCount == 0 ? '측정 없음' : '평균 ${liveAvgDb.toStringAsFixed(1)}dB',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: dbColor,
            ),
          ),
          if (sticker != null && liveCount > 0) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: dbColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${sticker.emoji} ${sticker.label}',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: dbColor),
              ),
            ),
          ],
          const Spacer(),
          Text(
            '$liveCount회 측정',
            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Hourly Chart Card
// ──────────────────────────────────────────────────────────────

class _HourlyChartCard extends StatelessWidget {
  final AsyncValue<List<(int, double)>> hourlyAsync;
  final Color dbColor;
  const _HourlyChartCard(
      {required this.hourlyAsync, required this.dbColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '시간대별 소음 수준',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface),
          ),
          hourlyAsync.when(
            loading: () => const SizedBox(
              height: 120,
              child:
                  Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => SizedBox(
              height: 80,
              child: Center(
                  child: Text('데이터를 불러올 수 없어요',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)))),
            ),
            data: (data) {
              if (data.length < 2) {
                return SizedBox(
                  height: 80,
                  child: Center(
                    child: Text(
                      '측정 데이터가 부족해요\n더 많은 측정이 쌓이면 표시됩니다',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          height: 1.6),
                    ),
                  ),
                );
              }
              final minDb = data
                  .map((e) => e.$2)
                  .reduce((a, b) => a < b ? a : b);
              final maxDb = data
                  .map((e) => e.$2)
                  .reduce((a, b) => a > b ? a : b);
              final rangeLabel =
                  '범위: ${minDb.toStringAsFixed(0)}~${maxDb.toStringAsFixed(0)}dB';
              final startHour = data.first.$1;
              final endHour = data.last.$1;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '오전 ${_fmtHour(startHour)} ~ '
                        '${_fmtHour(endHour, suffix: true)}',
                        style: TextStyle(
                            fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(rangeLabel,
                            style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    child: CustomPaint(
                      size: const Size(double.infinity, 120),
                      painter: _HourlyChartPainter(
                        data: data,
                        lineColor: dbColor,
                        gridColor: Theme.of(context).dividerColor,
                        dotBorderColor: Theme.of(context).colorScheme.surface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // X-axis labels
                  _XAxisLabels(data: data),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _fmtHour(int h, {bool suffix = false}) {
    final period = h < 12 ? '오전' : '오후';
    final display = h == 0
        ? 12
        : h > 12
            ? h - 12
            : h;
    return suffix ? '$period $display시' : '$display시';
  }
}

class _XAxisLabels extends StatelessWidget {
  final List<(int, double)> data;
  const _XAxisLabels({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    // Show first, middle, last
    final indices = <int>{0, data.length ~/ 2, data.length - 1};
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final step = data.length > 1 ? w / (data.length - 1) : w;
      return SizedBox(
        height: 16,
        child: Stack(
          children: [
            for (final i in indices)
              Positioned(
                left: (i * step - 16).clamp(0, w - 32),
                child: SizedBox(
                  width: 32,
                  child: Text(
                    '${data[i].$1}시',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}

class _HourlyChartPainter extends CustomPainter {
  final List<(int, double)> data;
  final Color lineColor;
  final Color gridColor;
  final Color dotBorderColor;
  static const double _minDb = 20;
  static const double _maxDb = 90;

  const _HourlyChartPainter({
    required this.data,
    required this.lineColor,
    required this.gridColor,
    required this.dotBorderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final fillPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    final dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;
    final dotBorderPaint = Paint()
      ..color = dotBorderColor
      ..style = PaintingStyle.fill;

    // Grid lines at 30/60/90dB
    for (final db in [30.0, 60.0, 90.0]) {
      final y = _toY(db, size.height);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Map data points to canvas coordinates
    Offset toOffset(int index) {
      final x = index / (data.length - 1) * size.width;
      final y = _toY(data[index].$2, size.height);
      return Offset(x, y);
    }

    // Build smooth path using quadratic bezier
    final path = Path();
    final fillPath = Path();
    final points = List.generate(data.length, (i) => toOffset(i));

    path.moveTo(points[0].dx, points[0].dy);
    fillPath.moveTo(points[0].dx, size.height);
    fillPath.lineTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final mid = Offset(
        (points[i].dx + points[i + 1].dx) / 2,
        (points[i].dy + points[i + 1].dy) / 2,
      );
      path.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
      fillPath.quadraticBezierTo(
          points[i].dx, points[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    fillPath.lineTo(points.last.dx, points.last.dy);
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    // Dots
    for (final pt in points) {
      canvas.drawCircle(pt, 5, dotBorderPaint);
      canvas.drawCircle(pt, 3.5, dotPaint);
    }
  }

  double _toY(double db, double height) {
    final clamped = db.clamp(_minDb, _maxDb);
    return height - ((clamped - _minDb) / (_maxDb - _minDb)) * height;
  }

  @override
  bool shouldRepaint(_HourlyChartPainter old) =>
      old.data != data || old.lineColor != lineColor ||
      old.gridColor != gridColor || old.dotBorderColor != dotBorderColor;
}

// ──────────────────────────────────────────────────────────────
// Vibe Tags Card
// ──────────────────────────────────────────────────────────────

class _VibeTagsCard extends StatelessWidget {
  final SpotModel spot;
  final AsyncValue<List<Map<String, dynamic>>> recentAsync;
  const _VibeTagsCard({required this.spot, required this.recentAsync});

  /// Collect unique tag_text values from visitor reports, ordered by frequency.
  List<String> _visitorTags(List<Map<String, dynamic>> reports) {
    final freq = <String, int>{};
    for (final r in reports) {
      final t = r['tag_text'] as String?;
      if (t != null && t.trim().isNotEmpty) {
        freq[t.trim()] = (freq[t.trim()] ?? 0) + 1;
      }
    }
    final sorted = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => '#${e.key.replaceFirst(RegExp(r'^#+'), '')}').toList();
  }

  @override
  Widget build(BuildContext context) {
    final autoTags = _deriveVibeTags(spot);
    final rawVisitorTags = recentAsync.asData?.value != null
        ? _visitorTags(recentAsync.asData!.value)
        : <String>[];
    // autoTags와 중복되는 visitorTags 제거
    final visitorTags =
        rawVisitorTags.where((t) => !autoTags.contains(t)).toList();

    final allTags = [...autoTags, ...visitorTags];
    if (allTags.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '분위기 태그',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Auto-derived tags (sticker + dB based)
              ...autoTags.map((tag) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )),
              // Visitor-entered tags (mint accent)
              ...visitorTags.map((tag) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.mintGreen.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.mintGreen.withValues(alpha: 0.30)),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.mintGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )),
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Recent Reports Card
// ──────────────────────────────────────────────────────────────

class _RecentReportsCard extends StatelessWidget {
  final AsyncValue<List<Map<String, dynamic>>> recentAsync;
  final Color dbColor;
  const _RecentReportsCard(
      {required this.recentAsync, required this.dbColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          recentAsync.when(
            loading: () => const SizedBox(
              height: 60,
              child:
                  Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => const SizedBox.shrink(),
            data: (reports) {
              if (reports.isEmpty) {
                return SizedBox(
                  height: 60,
                  child: Center(
                    child: Text(
                      '아직 측정 기록이 없어요',
                      style:
                          TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                    ),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '최근 측정',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${reports.length}회 측정됨',
                        style: TextStyle(
                            fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...reports.map((r) => _RecentReportTile(
                        report: r,
                        dbColor: DbClassifier.colorFromDb(
                            (r['measured_db'] as num).toDouble()),
                      )),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RecentReportTile extends StatelessWidget {
  final Map<String, dynamic> report;
  final Color dbColor;
  const _RecentReportTile({required this.report, required this.dbColor});

  @override
  Widget build(BuildContext context) {
    final nickname = report['nickname'] as String? ?? '익명';
    final measuredDb = (report['measured_db'] as num).toDouble();
    final stickerKey = report['selected_sticker'] as String?;
    final sticker =
        stickerKey != null ? StickerTypeX.fromKey(stickerKey) : null;
    final createdAt = report['created_at'] != null
        ? DateTime.tryParse(report['created_at'] as String)
        : null;
    final moodTag = report['mood_tag'] as String?;
    final tagText = report['tag_text'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 닉네임 + 스티커/태그 + dB  ···  시간
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                nickname,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              // Sticker badge OR custom #tag badge
              if (sticker != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: dbColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${sticker.emoji} ${sticker.label}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: dbColor),
                  ),
                ),
              ] else if (tagText != null && tagText.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.mintGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '#$tagText',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mintGreen),
                  ),
                ),
              ],
              const SizedBox(width: 6),
              Text(
                '${measuredDb.toStringAsFixed(0)}dB',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: dbColor,
                ),
              ),
              const Spacer(),
              Text(
                _timeAgo(createdAt),
                style: TextStyle(
                    fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
            ],
          ),
          // 방문자 메모
          if (moodTag != null && moodTag.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              moodTag,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Sticky Measure Button
// ──────────────────────────────────────────────────────────────

class _StickyMeasureButton extends StatelessWidget {
  final SpotModel spot;
  final double bottomPad;
  const _StickyMeasureButton(
      {required this.spot, required this.bottomPad});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
          left: 16, right: 16, top: 10, bottom: bottomPad + 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -4)),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => context.push(
            '/report'
            '?spotId=${spot.id}'
            '&spotName=${Uri.encodeComponent(spot.name)}'
            '&lat=${spot.lat}'
            '&lng=${spot.lng}',
          ),
          icon: const Icon(Icons.graphic_eq, size: 20),
          label: const Text(
            '바이브 체크하기',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.mintGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// _BookmarkButton — 하트 버튼 + 파티클 애니메이션
// ──────────────────────────────────────────────────────────────

class _BookmarkButton extends ConsumerStatefulWidget {
  final SpotModel spot;
  const _BookmarkButton({required this.spot});

  @override
  ConsumerState<_BookmarkButton> createState() => _BookmarkButtonState();
}

class _BookmarkButtonState extends ConsumerState<_BookmarkButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    duration: const Duration(milliseconds: 650),
    vsync: this,
  );
  bool _showParticles = false;
  // 낙관적 업데이트용 로컬 상태 (null = 서버 값 사용)
  bool? _localBookmarked;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final current = _localBookmarked ??
        ref.read(isBookmarkedProvider(widget.spot.id)).asData?.value ??
        false;
    final newValue = !current;
    setState(() => _localBookmarked = newValue);

    try {
      await ref
          .read(bookmarkRepositoryProvider)
          .toggleBookmark(widget.spot.id);
      // 프로필 찜한 카페 목록 갱신
      ref.invalidate(bookmarkedSpotsProvider);
      ref.invalidate(isBookmarkedProvider(widget.spot.id));

      if (newValue && mounted) {
        setState(() => _showParticles = true);
        await _ctrl.forward(from: 0);
        if (mounted) setState(() => _showParticles = false);
        _ctrl.reset();
      }
    } catch (_) {
      // 실패 시 롤백
      if (mounted) setState(() => _localBookmarked = current);
    }
  }

  @override
  Widget build(BuildContext context) {
    final serverValue =
        ref.watch(isBookmarkedProvider(widget.spot.id)).asData?.value;
    final isBookmarked = _localBookmarked ?? serverValue ?? false;

    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // ── 하트 파티클 8개 (중앙 → 바깥 방사) ─────────────────
          if (_showParticles)
            ...List.generate(8, (i) {
              final angle = i * (2 * pi / 8) - pi / 2;
              final radius = (i % 2 == 0) ? 40.0 : 32.0;
              const colors = [
                Color(0xFFFF4D7D),
                Color(0xFFFF8FAB),
                AppColors.mintGreen,
                Color(0xFFFF6B9D),
              ];
              final color = colors[i % colors.length];
              final heartSize = (i % 3 == 0) ? 14.0 : 10.0;
              return AnimatedBuilder(
                animation: _ctrl,
                builder: (context, child) {
                  final t = _ctrl.value;
                  final progress = Curves.easeOut.transform(t);
                  final animRadius = progress * radius;
                  final currentDx = cos(angle) * animRadius;
                  final currentDy = sin(angle) * animRadius;
                  final opacity =
                      (1 - Curves.easeIn.transform(t)).clamp(0.0, 1.0);
                  return Positioned(
                    left: 28 + currentDx - heartSize / 2,
                    top: 28 + currentDy - heartSize / 2,
                    child: Opacity(opacity: opacity, child: child),
                  );
                },
                child: Icon(Icons.favorite, size: heartSize, color: color),
              );
            }),
          // ── 하트 아이콘 버튼 ───────────────────────────────────
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: child,
              ),
              child: Icon(
                isBookmarked ? Icons.favorite : Icons.favorite_border,
                key: ValueKey(isBookmarked),
                color: isBookmarked
                    ? const Color(0xFFFF6B9D)
                    : Colors.white,
                size: 22,
              ),
            ),
            onPressed: _toggle,
          ),
        ],
      ),
    );
  }
}
