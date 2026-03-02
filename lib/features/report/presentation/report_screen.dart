import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../map/domain/spot_model.dart';
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      appBar: AppBar(
        title: const Text('소음 측정'),
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
          onSelected: (sticker) async {
            final controller = ref.read(reportControllerProvider.notifier);
            if (_isNewSpot) controller.updateSpotName(_nameController.text);

            final isNear = await controller.verifyProximity();
            // Guard return OUTSIDE the mounted check so it always runs
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
            await controller.submitWithSticker(sticker);
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
              onTap: () =>
                  ref.read(reportControllerProvider.notifier).stopMeasurement(),
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
          '버튼을 눌러 측정을 시작하세요',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
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
          '주변 소리를 측정하고 있어요',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 32),
        DbMeterWidget(currentDb: currentDb, isMeasuring: true),
        const SizedBox(height: 24),
        // Timer badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
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
              ),
              const SizedBox(width: 8),
              Text(
                '측정 중 ${_formatElapsed(elapsedSeconds)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF444444),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Measurement tip card
// ─────────────────────────────────────────────
class _TipCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.mintGreen.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
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
            '스마트폰을 테이블 위에 놓아주세요',
            '30초 이상 측정할수록 정확해요',
            '이동 중에는 측정하지 마세요',
          ].map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                  Expanded(
                    child: Text(
                      tip,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
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
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.mintGreen,
          disabledBackgroundColor: AppColors.mintGreen.withValues(alpha: 0.6),
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  Text('측정 시작',
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
        label: const Text('측정 중지',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF8B3A2A),
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Sticker / Done / Error views
// ─────────────────────────────────────────────
class _StickerView extends StatelessWidget {
  final double measuredDb;
  final ValueChanged<StickerType> onSelected;
  const _StickerView({required this.measuredDb, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: StickerCardGrid(measuredDb: measuredDb, onSelected: onSelected),
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
