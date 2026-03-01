import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/db_classifier.dart';
import '../../../features/map/domain/spot_model.dart';
import '../../../features/report/data/report_repository.dart';

// ──────────────────────────────────────────────────────────────
// Providers
// ──────────────────────────────────────────────────────────────

final _hourlyNoiseProvider = FutureProvider.autoDispose
    .family<List<(int, double)>, String>(
  (ref, spotId) =>
      ref.read(reportRepositoryProvider).getSpotHourlyNoise(spotId),
);

final _recentReportsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>(
  (ref, spotId) =>
      ref.read(reportRepositoryProvider).getSpotRecentReports(spotId),
);

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
  if (spot.averageDb < 45) {
    tags.add('#조용한');
  } else if (spot.averageDb < 60) {
    tags.add('#보통');
  } else {
    tags.add('#활기찬');
  }

  switch (spot.representativeSticker) {
    case StickerType.study:
      tags.addAll(['#집중하기 좋은', '#작업하기 좋은']);
    case StickerType.relax:
      tags.addAll(['#아늑한', '#편안한']);
    case StickerType.meeting:
      tags.addAll(['#대화하기 좋은', '#모임']);
    case null:
      break;
  }
  if (spot.reportCount >= 20) tags.add('#자주 방문');
  if (spot.trustScore >= 2) tags.add('#신뢰도 높음');
  return tags;
}

// ──────────────────────────────────────────────────────────────
// SpotDetailScreen
// ──────────────────────────────────────────────────────────────

class SpotDetailScreen extends ConsumerWidget {
  final SpotModel spot;
  const SpotDetailScreen({super.key, required this.spot});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dbColor = DbClassifier.colorFromDb(spot.averageDb);
    final hourlyAsync = ref.watch(_hourlyNoiseProvider(spot.id));
    final recentAsync = ref.watch(_recentReportsProvider(spot.id));
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F1),
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
                  IconButton(
                    icon: const Icon(Icons.ios_share_outlined, size: 22),
                    onPressed: () {},
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
                child: _SummaryBanner(spot: spot, dbColor: dbColor),
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
                child: _VibeTagsCard(spot: spot),
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

class _HeroBackground extends StatelessWidget {
  final SpotModel spot;
  final Color dbColor;
  const _HeroBackground({required this.spot, required this.dbColor});

  @override
  Widget build(BuildContext context) {
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
              child: Center(
                child: Text(
                  spot.name.isNotEmpty ? spot.name[0] : '?',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
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
  const _SummaryBanner({required this.spot, required this.dbColor});

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
            '평균 ${spot.averageDb.toStringAsFixed(1)}dB',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: dbColor,
            ),
          ),
          if (sticker != null) ...[
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
            '${spot.reportCount}회 측정',
            style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
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
        color: Colors.white,
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
          const Text(
            '시간대별 소음 수준',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A)),
          ),
          hourlyAsync.when(
            loading: () => const SizedBox(
              height: 120,
              child:
                  Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => const SizedBox(
              height: 80,
              child: Center(
                  child: Text('데이터를 불러올 수 없어요',
                      style: TextStyle(color: Color(0xFF999999)))),
            ),
            data: (data) {
              if (data.length < 2) {
                return const SizedBox(
                  height: 80,
                  child: Center(
                    child: Text(
                      '측정 데이터가 부족해요\n더 많은 측정이 쌓이면 표시됩니다',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF999999),
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
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF999999)),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F0F0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(rangeLabel,
                            style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF666666),
                                fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    child: CustomPaint(
                      size: const Size(double.infinity, 120),
                      painter:
                          _HourlyChartPainter(data: data, lineColor: dbColor),
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
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFF999999)),
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
  static const double _minDb = 20;
  static const double _maxDb = 90;

  const _HourlyChartPainter({required this.data, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final gridPaint = Paint()
      ..color = Colors.grey.shade200
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
      ..color = Colors.white
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
      old.data != data || old.lineColor != lineColor;
}

// ──────────────────────────────────────────────────────────────
// Vibe Tags Card
// ──────────────────────────────────────────────────────────────

class _VibeTagsCard extends StatelessWidget {
  final SpotModel spot;
  const _VibeTagsCard({required this.spot});

  @override
  Widget build(BuildContext context) {
    final tags = _deriveVibeTags(spot);
    if (tags.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
          const Text(
            '분위기 태그',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags
                .map((tag) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE8E8E8)),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF444444),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ))
                .toList(),
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
        color: Colors.white,
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
                return const SizedBox(
                  height: 60,
                  child: Center(
                    child: Text(
                      '아직 측정 기록이 없어요',
                      style:
                          TextStyle(fontSize: 13, color: Color(0xFF999999)),
                    ),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '최근 측정',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A1A)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${reports.length}회 측정됨',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF999999)),
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
  const _RecentReportTile(
      {required this.report, required this.dbColor});

  Color _avatarColor(String userId) {
    final colors = [
      const Color(0xFFBBDEFB),
      const Color(0xFFB2EBF2),
      const Color(0xFFDCEDC8),
      const Color(0xFFFFCCBC),
      const Color(0xFFE1BEE7),
      const Color(0xFFFFE0B2),
    ];
    final hash = userId.codeUnits
        .fold(0, (prev, e) => (prev + e) % colors.length);
    return colors[hash];
  }

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
    final userId = report['user_id'] as String? ?? '';
    final initial = nickname.isNotEmpty ? nickname[0] : '?';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _avatarColor(userId),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF444444),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      nickname,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF222222),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _timeAgo(createdAt),
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF999999)),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    if (sticker != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: dbColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          sticker.label,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: dbColor),
                        ),
                      ),
                    const SizedBox(width: 6),
                    Text(
                      '${measuredDb.toStringAsFixed(0)}dB',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: dbColor,
                      ),
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
        color: Colors.white,
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
            '/report?spotId=${spot.id}&spotName=${Uri.encodeComponent(spot.name)}',
          ),
          icon: const Icon(Icons.graphic_eq, size: 20),
          label: const Text(
            '소음 측정하기',
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
