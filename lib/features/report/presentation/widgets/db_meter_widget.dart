import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/utils/db_classifier.dart';

/// Circular arc gauge with:
///  - Pulse animation while measuring (outer scale breathe)
///  - Smooth arc fill interpolation when dB value changes
class DbMeterWidget extends StatefulWidget {
  final double currentDb;
  final bool isMeasuring;

  const DbMeterWidget({
    super.key,
    required this.currentDb,
    this.isMeasuring = false,
  });

  @override
  State<DbMeterWidget> createState() => _DbMeterWidgetState();
}

class _DbMeterWidgetState extends State<DbMeterWidget>
    with TickerProviderStateMixin {
  // Pulse: scale 1.0 ↔ 1.045 while measuring
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  // Arc fill: smoothly lerps from old dB to new dB
  late AnimationController _arcController;
  late Animation<double> _arcAnim;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.045).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _arcController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    // Start at initial db; will be re-targeted in didUpdateWidget
    _arcAnim = Tween<double>(
      begin: widget.currentDb,
      end: widget.currentDb,
    ).animate(CurvedAnimation(parent: _arcController, curve: Curves.easeOut));

    if (widget.isMeasuring) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(DbMeterWidget old) {
    super.didUpdateWidget(old);

    // ── Pulse start / stop ──────────────────────────────
    if (widget.isMeasuring && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isMeasuring && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    // ── Arc smooth interpolation ─────────────────────────
    if (old.currentDb != widget.currentDb) {
      // Capture the current mid-animation value so there's no jump
      final fromDb = _arcAnim.value;
      _arcAnim = Tween<double>(begin: fromDb, end: widget.currentDb).animate(
        CurvedAnimation(parent: _arcController, curve: Curves.easeOut),
      );
      _arcController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _arcController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnim, _arcAnim]),
      builder: (context, _) {
        final animDb = _arcAnim.value;
        final color = DbClassifier.colorFromDb(animDb);
        final label = DbClassifier.labelFromDb(animDb);

        return Transform.scale(
          scale: _pulseAnim.value,
          child: SizedBox(
            width: 250,
            height: 250,
            child: CustomPaint(
              painter: _GaugePainter(
                db: animDb,
                color: color,
                isMeasuring: widget.isMeasuring,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      animDb.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 60,
                        fontWeight: FontWeight.w300,
                        color: widget.isMeasuring
                            ? color
                            : const Color(0xFFBDBDBD),
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'dB',
                      style: TextStyle(
                        fontSize: 15,
                        color: widget.isMeasuring
                            ? color.withValues(alpha: 0.7)
                            : Colors.grey.shade400,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color:
                            (widget.isMeasuring ? color : Colors.grey.shade400)
                                .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: widget.isMeasuring
                              ? color
                              : Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Gauge CustomPainter
// Arc: 135° → 135°+270° (7:30 → 4:30 o'clock, clockwise)
// ─────────────────────────────────────────────
class _GaugePainter extends CustomPainter {
  final double db;
  final Color color;
  final bool isMeasuring;

  static const double _startDeg = 135.0;
  static const double _sweepDeg = 270.0;

  const _GaugePainter({
    required this.db,
    required this.color,
    required this.isMeasuring,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 22;

    final startRad = _startDeg * math.pi / 180;
    final sweepRad = _sweepDeg * math.pi / 180;

    // Background track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startRad,
      sweepRad,
      false,
      Paint()
        ..color = const Color(0xFFE0E0E0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round,
    );

    // Active fill arc (only while measuring)
    if (isMeasuring && db > 0) {
      final normalised = ((db - 30) / 90).clamp(0.02, 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startRad,
        normalised * sweepRad,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round,
      );
    }

    // Tick marks (24 ticks, every 11.25°)
    final tickPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    const tickCount = 24;
    for (int i = 0; i <= tickCount; i++) {
      final angle = startRad + (sweepRad / tickCount) * i;
      final isMajor = i % 6 == 0;
      final tickLen = isMajor ? 11.0 : 6.0;
      final outerR = radius - 13;
      final innerR = outerR - tickLen;
      canvas.drawLine(
        Offset(center.dx + outerR * math.cos(angle),
            center.dy + outerR * math.sin(angle)),
        Offset(center.dx + innerR * math.cos(angle),
            center.dy + innerR * math.sin(angle)),
        tickPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.db != db || old.color != color || old.isMeasuring != isMeasuring;
}
