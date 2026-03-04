import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/badge_service.dart';
import '../../../core/services/moderation_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/content_filter.dart';
import '../../map/domain/spot_model.dart';
import '../../map/presentation/map_controller.dart' show mapControllerProvider;
import '../../profile/presentation/profile_screen.dart'
    show profileStatsProvider, profileReportsProvider, profileBadgeDataProvider;
import '../../explore/presentation/spot_detail_screen.dart'
    show spotLiveStatsProvider, spotRecentReportsProvider;
import '../../ranking/data/ranking_repository.dart'
    show quietCafeRankingProvider, userRankingProvider, weeklyCafeRankingProvider;
import '../../profile/presentation/widgets/badge_earned_popup.dart';
import '../data/report_repository.dart';
import 'report_controller.dart';
import 'widgets/db_meter_widget.dart';
import 'widgets/privacy_notice_bar.dart';
import 'widgets/sticker_card_grid.dart';

class ReportScreen extends ConsumerStatefulWidget {
  final String? spotId;
  final String spotName;
  final String? placeId;
  final double? lat;
  final double? lng;

  const ReportScreen({
    super.key,
    this.spotId,
    required this.spotName,
    this.placeId,
    this.lat,
    this.lng,
  });

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  late final TextEditingController _nameController;
  bool _isCheckingLocation = false;
  bool _badgeCheckDone = false; // prevent duplicate checks

  bool get _isNewSpot => widget.spotId == null || widget.spotId!.isEmpty;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.spotName.isNotEmpty ? widget.spotName : '내 스팟',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(reportControllerProvider.notifier).initialize(
            spotId: widget.spotId ?? '',
            spotName: _isNewSpot ? _nameController.text : widget.spotName,
            lat: widget.lat,
            lng: widget.lng,
            googlePlaceId: widget.placeId,
          );
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    // Stop mic + GPS streams when leaving the screen (provider is not autoDispose)
    final phase = ref.read(reportControllerProvider).phase;
    if (phase == ReportPhase.measuring || phase == ReportPhase.stabilizing) {
      ref.read(reportControllerProvider.notifier).stopMeasurement();
    }
    super.dispose();
  }

  /// Check and award badges after a successful report submission.
  /// Shows popup for each newly earned badge sequentially.
  Future<void> _checkBadgesAfterSubmit() async {
    try {
      final repo = ref.read(reportRepositoryProvider);
      final client = ref.read(supabaseClientProvider);
      final (badgeStats, earnedIds) = await repo.getMyBadgeStats();
      final newBadges = await BadgeService.checkAndAward(
        client: client,
        stats: badgeStats,
        earnedIds: earnedIds,
      );
      if (!mounted) return;
      for (final badge in newBadges) {
        await showBadgeEarnedPopup(context, badge);
        if (!mounted) return;
      }
    } catch (_) {
      // Badge check failure must never affect the report flow
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportControllerProvider);

    // Trigger badge check + profile refresh once when report is submitted
    ref.listen<ReportState>(reportControllerProvider, (prev, next) {
      if (prev?.phase != ReportPhase.done &&
          next.phase == ReportPhase.done &&
          !_badgeCheckDone) {
        _badgeCheckDone = true;
        // Invalidate profile providers so the profile tab shows fresh data
        ref.invalidate(profileStatsProvider);
        ref.invalidate(profileReportsProvider);
        ref.invalidate(profileBadgeDataProvider);
        // Refresh ranking so new report appears immediately
        ref.invalidate(quietCafeRankingProvider);
        ref.invalidate(userRankingProvider);
        ref.invalidate(weeklyCafeRankingProvider);
        // Reload map spots so markers reflect updated average_db / report_count
        ref.read(mapControllerProvider.notifier).reloadSpots();
        // SpotDetailScreen의 live stats + recent reports 갱신 (stale 방지)
        if (widget.spotId != null) {
          ref.invalidate(spotLiveStatsProvider(widget.spotId!));
          ref.invalidate(spotRecentReportsProvider(widget.spotId!));
        }
        _checkBadgesAfterSubmit();
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('바이브 체크'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          const PrivacyNoticeBar(),
          if (_isNewSpot &&
              (state.phase == ReportPhase.idle ||
                  state.phase == ReportPhase.measuring ||
                  state.phase == ReportPhase.stabilizing ||
                  state.phase == ReportPhase.stickerSelection))
            _SpotNameInput(
              controller: _nameController,
              onChanged: (name) =>
                  ref.read(reportControllerProvider.notifier).updateSpotName(name),
            ),
          Expanded(child: _buildBody(state)),
          _buildBottomButton(state),
        ],
      ),
    );
  }

  Widget _buildBody(ReportState state) {
    return switch (state.phase) {
      ReportPhase.idle => _IdleView(currentDb: state.currentDb),
      ReportPhase.measuring || ReportPhase.stabilizing => _MeasuringView(
          currentDb: state.currentDb,
          elapsedSeconds: state.elapsedSeconds,
        ),
      ReportPhase.stickerSelection => _StickerView(
          measuredDb: state.stableDb,
          onSubmit: (sticker, tagText, moodTag) async {
            final controller = ref.read(reportControllerProvider.notifier);
            if (_isNewSpot) controller.updateSpotName(_nameController.text);

            final isNear = await controller.verifyProximity();
            if (!isNear) {
              if (mounted) {
                await showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text(AppStrings.proximityDialogTitle),
                    content: const Text(AppStrings.proximityDialogSubmit),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('확인'),
                      ),
                    ],
                  ),
                );
              }
              return;
            }
            await controller.submitWithSticker(
              sticker,
              tagText: tagText,
              moodTag: moodTag,
            );
          },
        ),

      ReportPhase.submitting => const Center(
          child: CircularProgressIndicator(color: AppColors.mintGreen),
        ),
      ReportPhase.done => _DoneView(onBack: () => context.pop()),
      ReportPhase.error => _ErrorView(
          message: state.errorMessage ?? '알 수 없는 오류가 발생했습니다.',
          onRetry: () =>
              ref.read(reportControllerProvider.notifier).startMeasurement(),
        ),
    };
  }

  Widget _buildBottomButton(ReportState state) {
    return switch (state.phase) {
      ReportPhase.idle => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: _StartButton(
              isLoading: _isCheckingLocation,
              onTap: () async {
                final controller = ref.read(reportControllerProvider.notifier);
                // Existing spots: check proximity before even starting measurement
                if (!_isNewSpot) {
                  setState(() => _isCheckingLocation = true);
                  try {
                    // 오늘 이미 측정했는지 사전 확인
                    final alreadyMeasured = await ref
                        .read(reportRepositoryProvider)
                        .hasAlreadyMeasuredToday(widget.spotId!);
                    if (alreadyMeasured) {
                      if (!mounted) return;
                      await showDialog<void>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('오늘은 이미 측정했어요'),
                          content: const Text(
                            '같은 카페는 하루에 한 번만 측정할 수 있어요.\n내일 다시 방문해서 바이브를 기록해보세요! 🎧',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('확인',
                                  style: TextStyle(color: AppColors.mintGreen)),
                            ),
                          ],
                        ),
                      );
                      return;
                    }

                    final isNear = await controller.verifyProximity();
                    if (!isNear) {
                      if (!mounted) return;
                      await showDialog<void>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text(AppStrings.proximityDialogTitle),
                          content: const Text(AppStrings.proximityDialogMeasure),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('확인'),
                            ),
                          ],
                        ),
                      );
                      return;
                    }
                  } finally {
                    if (mounted) setState(() => _isCheckingLocation = false);
                  }
                }
                HapticFeedback.mediumImpact();
                controller.startMeasurement();
              },
            ),
          ),
        ),
      ReportPhase.measuring || ReportPhase.stabilizing => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: _StopButton(
              onTap: () {
                HapticFeedback.heavyImpact();
                ref.read(reportControllerProvider.notifier).stopMeasurement();
              },
            ),
          ),
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

// ─────────────────────────────────────────────
// Spot name input (new spots only)
// ─────────────────────────────────────────────
class _SpotNameInput extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SpotNameInput({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.mintGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.mintGreen.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.place_rounded, size: 18, color: AppColors.mintGreen),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              decoration: const InputDecoration(
                hintText: '장소 이름 입력 (예: 스타벅스 홍대점)',
                hintStyle: TextStyle(color: AppColors.textHint, fontSize: 14),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Idle view — gauge (greyed) + tip card
// ─────────────────────────────────────────────
class _IdleView extends StatelessWidget {
  final double currentDb;
  const _IdleView({required this.currentDb});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Text(
          '버튼을 눌러 바이브를 체크하세요',
          style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
        ),
        const SizedBox(height: 32),
        DbMeterWidget(currentDb: currentDb, isMeasuring: false),
        const Spacer(),
        _TipCard(),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Measuring view — pulsing gauge + timer badge
// ─────────────────────────────────────────────
class _MeasuringView extends StatelessWidget {
  final double currentDb;
  final int elapsedSeconds;
  const _MeasuringView({required this.currentDb, required this.elapsedSeconds});

  String _formatElapsed(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Text(
          '분위기를 감지하고 있어요',
          style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
        ),
        const SizedBox(height: 32),
        DbMeterWidget(currentDb: currentDb, isMeasuring: true),
        const SizedBox(height: 24),
        // Timer badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFD32F2F),
                  shape: BoxShape.circle,
                ),
              )
                  .animate(onPlay: (c) => c.repeat())
                  .fadeOut(duration: 800.ms)
                  .then()
                  .fadeIn(duration: 800.ms),
              const SizedBox(width: 8),
              Text(
                '감지 중 ${_formatElapsed(elapsedSeconds)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        _NoiseTipCard(currentDb: currentDb),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Idle tip card (static measurement tips)
// ─────────────────────────────────────────────
class _TipCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : AppColors.mintGreen.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.mintGreen.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded,
                  size: 16, color: AppColors.mintGreen),
              const SizedBox(width: 6),
              const Text(
                '측정 팁',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mintGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...[
            '스마트폰을 테이블 위에 고정해주세요',
            '약 10초 내 자동으로 완료돼요',
            '이동 중에는 측정하지 마세요',
          ].map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ',
                      style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                  Expanded(
                    child: Text(
                      tip,
                      style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Measuring tip card (dB-level tips, glassmorphism)
// ─────────────────────────────────────────────
class _NoiseTipCard extends StatelessWidget {
  final double currentDb;
  const _NoiseTipCard({required this.currentDb});

  static const _tips = [
    (icon: Icons.spa_outlined,        text: '정말 조용해요! 집중하기 완벽한 환경이에요',   threshold: 40.0),
    (icon: Icons.book_outlined,       text: '적당히 조용해요. 공부나 독서에 딱이에요',     threshold: 55.0),
    (icon: Icons.coffee_outlined,     text: '활발한 대화 수준이에요. 캐주얼 작업에 적합해요', threshold: 70.0),
    (icon: Icons.headphones_outlined, text: '좀 시끄러운 편이에요. 이어폰을 추천해요',     threshold: 85.0),
    (icon: Icons.warning_amber_rounded, text: '매우 시끄러워요! 장시간 있으면 귀에 무리가 갈 수 있어요', threshold: double.infinity),
  ];

  @override
  Widget build(BuildContext context) {
    final tip = _tips.firstWhere((t) => currentDb < t.threshold, orElse: () => _tips.last);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.60),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(tip.icon, size: 20, color: AppColors.mintGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tip.text,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Start / Stop buttons
// ─────────────────────────────────────────────
class _StartButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isLoading;
  const _StartButton({required this.onTap, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.mintGreen,
          disabledBackgroundColor: AppColors.mintGreen.withValues(alpha: 0.6),
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.graphic_eq_rounded, size: 20),
                  SizedBox(width: 8),
                  Text('체크 시작',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    );
  }
}

class _StopButton extends StatelessWidget {
  final VoidCallback onTap;
  const _StopButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.stop_rounded, size: 20),
        label: const Text('중지',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF8B3A2A),
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
          elevation: 0,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Sticker / Done / Error views
// ─────────────────────────────────────────────
class _StickerView extends StatefulWidget {
  final double measuredDb;
  final Future<void> Function(
      StickerType? sticker, String? tagText, String? moodTag) onSubmit;
  const _StickerView({required this.measuredDb, required this.onSubmit});

  @override
  State<_StickerView> createState() => _StickerViewState();
}

class _StickerViewState extends State<_StickerView> {
  StickerType? _selected;
  final _memoCtrl = TextEditingController();
  bool _submitting = false;
  String? _apiMemoError; // error returned from Google NL API

  // Layer 1: real-time local filter
  String? get _memoError => ContentFilter.validate(_memoCtrl.text) ?? _apiMemoError;
  bool get _canSubmit =>
      !_submitting && _selected != null && _memoError == null;

  @override
  void initState() {
    super.initState();
    _memoCtrl.addListener(() => setState(() {
      // Clear API error when user edits the text
      if (_apiMemoError != null) _apiMemoError = null;
    }));
  }

  @override
  void dispose() {
    _memoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Scrollable sticker grid + memo ────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StickerCardGrid(
                  measuredDb: widget.measuredDb,
                  selected: _selected,
                  onSelect: (s) => setState(() => _selected = s),
                ),
                const SizedBox(height: 20),
                _MemoInput(
                  controller: _memoCtrl,
                  errorText: _memoError,
                ),
              ],
            ),
          ),
        ),
        // ── Submit button ─────────────────────────────────────
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _canSubmit
                    ? () async {
                        setState(() => _submitting = true);
                        final memo = _memoCtrl.text.trim();

                        // Layer 2: Google NL moderation (runs on submit)
                        if (memo.isNotEmpty) {
                          final err = await ModerationService.validate(memo);
                          if (err != null) {
                            if (mounted) {
                              setState(() {
                                _submitting = false;
                                _apiMemoError = err;
                              });
                            }
                            return;
                          }
                        }

                        await widget.onSubmit(
                          _selected!,
                          '#${_selected!.label}',
                          memo.isEmpty ? null : memo,
                        );
                        if (mounted) setState(() => _submitting = false);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mintGreen,
                  disabledBackgroundColor:
                      AppColors.mintGreen.withValues(alpha: 0.35),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                  elevation: 0,
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text(
                        '제출하기',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Memo input — optional, max 30 chars with content filter error display
class _MemoInput extends StatelessWidget {
  final TextEditingController controller;
  final String? errorText;
  const _MemoInput({required this.controller, this.errorText});

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final count = value.text.length;
        return TextField(
          controller: controller,
          maxLength: 30,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: '이 카페를 한마디로.. (선택)',
            hintText: '예) 창가 자리 분위기 최고',
            hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
            errorText: errorText,
            errorStyle: const TextStyle(fontSize: 12),
            counterText: '',
            suffixText: hasError ? null : '$count/30',
            suffixStyle: TextStyle(
              fontSize: 12,
              color: count >= 30 ? Colors.red : const Color(0xFF999999),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError ? Colors.red.shade300 : Theme.of(context).dividerColor,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError ? Colors.red : AppColors.mintGreen,
                width: 1.5,
              ),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        );
      },
    );
  }
}

class _DoneView extends StatelessWidget {
  final VoidCallback onBack;
  const _DoneView({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, size: 72, color: AppColors.mintGreen)
              .animate()
              .scale(begin: const Offset(0.5, 0.5), duration: 400.ms)
              .fadeIn(duration: 400.ms),
          const SizedBox(height: 20),
          Text(AppStrings.reportSuccess, style: Theme.of(context).textTheme.titleLarge)
              .animate()
              .fadeIn(delay: 300.ms),
          const SizedBox(height: 32),
          ElevatedButton(onPressed: onBack, child: const Text('지도로 돌아가기'))
              .animate()
              .fadeIn(delay: 500.ms),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.dbVeryLoud),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }
}
