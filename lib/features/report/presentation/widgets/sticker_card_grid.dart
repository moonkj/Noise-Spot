import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../map/domain/spot_model.dart';

/// Horizontal carousel of sticker cards — 4 per page (2×2), 5 pages total.
/// Users swipe left/right to see all 18 sticker types.
class StickerCardGrid extends StatefulWidget {
  final double measuredDb;
  final StickerType? selected;
  final ValueChanged<StickerType> onSelect;

  const StickerCardGrid({
    super.key,
    required this.measuredDb,
    required this.selected,
    required this.onSelect,
  });

  static const _pages = <List<StickerType>>[
    [StickerType.study, StickerType.work, StickerType.studyZone, StickerType.nomad],
    [StickerType.meeting, StickerType.vibe, StickerType.date, StickerType.gathering],
    [StickerType.family, StickerType.relax, StickerType.healing, StickerType.cozy],
    [StickerType.insta, StickerType.retro, StickerType.minimal, StickerType.green],
    [StickerType.peak, StickerType.music],
  ];

  static const _categoryLabels = [
    '포커스 & 생산성',
    '소셜',
    '가족 & 라이프',
    '감성 스타일',
    '기타 분위기',
  ];

  static Color colorFor(StickerType s) => switch (s) {
        StickerType.study      => AppColors.stickerStudy,
        StickerType.meeting    => AppColors.stickerMeeting,
        StickerType.relax      => AppColors.stickerRelax,
        StickerType.vibe       => AppColors.stickerVibe,
        StickerType.healing    => AppColors.stickerHealing,
        StickerType.work       => AppColors.stickerWork,
        StickerType.studyZone  => AppColors.stickerStudyZone,
        StickerType.nomad      => AppColors.stickerNomad,
        StickerType.date       => AppColors.stickerDate,
        StickerType.gathering  => AppColors.stickerGathering,
        StickerType.family     => AppColors.stickerFamily,
        StickerType.cozy       => AppColors.stickerCozy,
        StickerType.insta      => AppColors.stickerInsta,
        StickerType.retro      => AppColors.stickerRetro,
        StickerType.minimal    => AppColors.stickerMinimal,
        StickerType.green      => AppColors.stickerGreen,
        StickerType.peak       => AppColors.stickerPeak,
        StickerType.music      => AppColors.stickerMusic,
      };

  @override
  State<StickerCardGrid> createState() => _StickerCardGridState();
}

class _StickerCardGridState extends State<StickerCardGrid> {
  final _ctrl = PageController();
  int _page = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = StickerCardGrid._pages;
    final labels = StickerCardGrid._categoryLabels;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '측정 완료: ${widget.measuredDb.toStringAsFixed(1)} dB',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.mintGreen,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '이 공간의 분위기를 선택해 주세요',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.mintGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  labels[_page],
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mintGreen,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '← 스와이프 →',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 206,
          child: PageView.builder(
            controller: _ctrl,
            itemCount: pages.length,
            onPageChanged: (p) => setState(() => _page = p),
            itemBuilder: (ctx, pageIdx) {
              final stickers = pages[pageIdx];
              final row1 = stickers.take(2).toList();
              final row2 = stickers.skip(2).toList();
              return Column(
                children: [
                  _StickerRow(stickers: row1, selected: widget.selected, onSelect: widget.onSelect),
                  if (row2.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _StickerRow(stickers: row2, selected: widget.selected, onSelect: widget.onSelect),
                  ],
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(pages.length, (i) {
            final active = i == _page;
            return GestureDetector(
              onTap: () => _ctrl.animateToPage(i,
                  duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.mintGreen
                      : AppColors.mintGreen.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _StickerRow extends StatelessWidget {
  final List<StickerType> stickers;
  final StickerType? selected;
  final ValueChanged<StickerType> onSelect;
  const _StickerRow({required this.stickers, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < stickers.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _StickerCard(
              sticker: stickers[i],
              color: StickerCardGrid.colorFor(stickers[i]),
              isSelected: selected == stickers[i],
              onTap: () => onSelect(stickers[i]),
            ),
          ),
        ],
        for (var i = stickers.length; i < 2; i++) ...[
          const SizedBox(width: 8),
          const Expanded(child: SizedBox()),
        ],
      ],
    );
  }
}

class _StickerCard extends StatelessWidget {
  final StickerType sticker;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  const _StickerCard({required this.sticker, required this.color, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.18) : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.3),
            width: isSelected ? 2.5 : 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Text(sticker.emoji, style: const TextStyle(fontSize: 26)),
                if (isSelected)
                  Positioned(
                    top: -4, right: -4,
                    child: Container(
                      width: 16, height: 16,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      child: const Icon(Icons.check, size: 10, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              sticker.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? color : AppColors.textSecondary,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
