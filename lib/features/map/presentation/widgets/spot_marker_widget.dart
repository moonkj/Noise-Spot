import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/db_classifier.dart';
import '../../../report/data/report_repository.dart';
import '../../domain/spot_model.dart';

/// Family key: (spotId, googlePlaceId).
/// Dummy spots encode fake reporter names in googlePlaceId as "DUMMY:index:name".
final _firstReporterProvider =
    FutureProvider.autoDispose.family<String?, (String, String?)>(
  (ref, args) {
    final (spotId, googlePlaceId) = args;
    // Dummy spots: extract fake reporter name without DB query
    if (googlePlaceId != null && googlePlaceId.startsWith('DUMMY:')) {
      final parts = googlePlaceId.split(':');
      if (parts.length >= 3) return Future.value(parts[2]);
    }
    return ref.read(reportRepositoryProvider).getFirstReporterNickname(spotId);
  },
);

/// Circular spot marker showing dB-based color and trust_score border thickness.
/// Used for custom Google Maps marker bitmaps via [RepaintBoundary].
class SpotMarkerWidget extends StatelessWidget {
  final SpotModel spot;
  final bool isReduced;

  const SpotMarkerWidget({
    super.key,
    required this.spot,
    this.isReduced = false,
  });

  /// Renders this marker programmatically as a [BitmapDescriptor] for Google Maps.
  /// Uses [ui.PictureRecorder] — no widget tree rendering required.
  /// Cache results by spot ID to avoid repeated rendering.
  static Future<BitmapDescriptor> toBitmapDescriptor(
    SpotModel spot,
    double pixelRatio, {
    bool isReduced = false,
  }) async {
    final logicalSize = isReduced ? 24.0 : 32.0;
    final ps = logicalSize * pixelRatio;
    final bw = (isReduced ? 1.5 : spot.markerBorderWidth) * pixelRatio;
    final innerRadius = ps / 2 - bw / 2;
    final color = spot.reportCount == 0
        ? const Color(0xFFBBBBBB)
        : DbClassifier.colorFromDb(spot.averageDb);

    // Name label above circle (individual mode only)
    TextPainter? labelPainter;
    double labelW = 0, labelH = 0;
    const double padH = 6.0, padV = 3.0, gap = 3.0;

    if (!isReduced) {
      final name = spot.name.length > 12
          ? '${spot.name.substring(0, 11)}…'
          : spot.name;
      labelPainter = TextPainter(
        text: TextSpan(
          text: name,
          style: TextStyle(
            color: Colors.white,
            fontSize: 9.5 * pixelRatio,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      labelPainter.layout();
      labelW = labelPainter.width + padH * 2 * pixelRatio;
      labelH = labelPainter.height + padV * 2 * pixelRatio;
    }

    final canvasW = math.max(ps, labelW);
    final canvasH = isReduced ? ps : labelH + gap * pixelRatio + ps;
    final circleTop = isReduced ? 0.0 : labelH + gap * pixelRatio;
    final circleCenter = Offset(canvasW / 2, circleTop + ps / 2);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Name label pill
    if (!isReduced && labelPainter != null) {
      final labelLeft = (canvasW - labelW) / 2;
      final pillRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(labelLeft, 0, labelW, labelH),
        Radius.circular(labelH / 2),
      );
      canvas.drawRRect(
        pillRect,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.12)
          ..maskFilter =
              ui.MaskFilter.blur(ui.BlurStyle.normal, 3 * pixelRatio),
      );
      canvas.drawRRect(pillRect, Paint()..color = AppColors.mintGreen);
      labelPainter.paint(
        canvas,
        Offset(labelLeft + padH * pixelRatio, padV * pixelRatio),
      );
    }

    // Drop shadow
    canvas.drawCircle(
      circleCenter + Offset(0, pixelRatio),
      innerRadius,
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 3 * pixelRatio),
    );

    // Filled circle
    canvas.drawCircle(circleCenter, innerRadius, Paint()..color = color);

    // White border
    canvas.drawCircle(
      circleCenter,
      innerRadius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = bw,
    );

    // dB number or "?" (individual mode only)
    if (!isReduced) {
      final tp = TextPainter(
        text: TextSpan(
          text: spot.reportCount == 0 ? '?' : spot.averageDb.toStringAsFixed(0),
          style: TextStyle(
            color: Colors.white,
            fontSize: 9 * pixelRatio,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, circleCenter - Offset(tp.width / 2, tp.height / 2));
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(canvasW.ceil(), canvasH.ceil());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw StateError('toBitmapDescriptor: toByteData returned null');
    return BitmapDescriptor.bytes(
      byteData.buffer.asUint8List(),
      imagePixelRatio: pixelRatio,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = isReduced ? 24.0 : 32.0;
    final color = spot.reportCount == 0
        ? const Color(0xFFBBBBBB)
        : DbClassifier.colorFromDb(spot.averageDb);
    final borderWidth = isReduced ? 1.5 : spot.markerBorderWidth;

    return Opacity(
      opacity: spot.markerOpacity,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: Colors.white, width: borderWidth),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isReduced
            ? null
            : Center(
                child: Text(
                  spot.reportCount == 0 ? '?' : spot.averageDb.toStringAsFixed(0),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
      ),
    );
  }
}

/// Bottom sheet card shown when a spot marker is tapped.
/// Glassmorphism style: BackdropFilter blur + semi-transparent surface.
class SpotInfoCard extends ConsumerWidget {
  final SpotModel spot;
  final VoidCallback onReport;
  final VoidCallback? onDetail;

  const SpotInfoCard({super.key, required this.spot, required this.onReport, this.onDetail});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstReporterAsync = ref.watch(
      _firstReporterProvider((spot.id, spot.googlePlaceId)),
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasData = spot.reportCount > 0;
    final dbColor = hasData ? DbClassifier.colorFromDb(spot.averageDb) : null;
    final noDataColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.white.withValues(alpha: 0.6),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Spot name + dB badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        spot.name,
                        style: Theme.of(context).textTheme.titleLarge,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: hasData
                                ? dbColor!.withValues(alpha: 0.15)
                                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            hasData ? '${spot.averageDb.toStringAsFixed(1)} dB' : '측정 없음',
                            style: TextStyle(
                              color: hasData ? dbColor! : noDataColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (hasData)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, right: 2),
                            child: firstReporterAsync.when(
                              data: (name) => name == null
                                  ? const SizedBox.shrink()
                                  : Text(
                                      '첫 바이브: $name',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.mintGreen,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                              loading: () => const SizedBox(
                                width: 14, height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: AppColors.mintGreen,
                                ),
                              ),
                              error: (e, _) => const SizedBox.shrink(),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Label + sticker
                Row(
                  children: [
                    Text(
                      DbClassifier.labelFromDb(spot.averageDb),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (spot.representativeSticker != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${spot.representativeSticker!.emoji} ${spot.representativeSticker!.label}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                // Social proof
                _SocialProofRow(spot: spot),
                const SizedBox(height: 16),
                // Report button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onReport,
                    child: const Text('바이브 체크하기'),
                  ),
                ),
                if (onDetail != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onDetail,
                      icon: const Icon(Icons.info_outline, size: 18),
                      label: const Text('자세히 보기'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.mintGreen,
                        side: const BorderSide(color: AppColors.mintGreen),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialProofRow extends StatelessWidget {
  final SpotModel spot;
  const _SocialProofRow({required this.spot});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Chip(
          label: '최근 24시간 ${spot.recent24hCount}건',
          icon: Icons.bar_chart_rounded,
        ),
        const SizedBox(width: 8),
        _Chip(
          label: '리포트 ${spot.reportCount}회',
          icon: Icons.check_circle_outline_rounded,
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _Chip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final subColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: subColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: subColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
