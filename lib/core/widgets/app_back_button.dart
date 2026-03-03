import 'package:flutter/material.dart';
import '../constants/app_dimens.dart';

/// 앱 전체에서 재사용하는 뒤로가기 버튼.
/// Material 3 가이드라인(44pt)을 준수하며 InkWell 리플 효과를 포함합니다.
class AppBackButton extends StatelessWidget {
  /// 뒤로가기 동작. null이면 Navigator.pop() 실행.
  final VoidCallback? onTap;

  /// 반투명 표면 배경 여부 (지도 위에 띄울 때 true).
  final bool elevated;

  const AppBackButton({super.key, this.onTap, this.elevated = false});

  @override
  Widget build(BuildContext context) {
    final surfaceColor = elevated
        ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.92)
        : Colors.transparent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.iconButtonSize / 2),
        onTap: onTap ?? () => Navigator.of(context).maybePop(),
        child: Container(
          width: AppDimens.iconButtonSize,
          height: AppDimens.iconButtonSize,
          decoration: elevated
              ? BoxDecoration(
                  color: surfaceColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: AppDimens.shadowBlurMd,
                    ),
                  ],
                )
              : null,
          alignment: Alignment.center,
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: AppDimens.iconMd,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
