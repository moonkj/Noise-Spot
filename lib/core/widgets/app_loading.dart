import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// 앱 전체에서 재사용하는 로딩 인디케이터.
/// 브랜드 색상(mint)을 기본으로 사용하며,
/// 전체화면 오버레이 / 인라인 / 버튼 내 축소 버전을 지원합니다.
class AppLoading extends StatelessWidget {
  /// 로딩 스피너 크기.
  final double size;

  /// 선 두께.
  final double strokeWidth;

  /// 색상. null이면 AppColors.mintGreen 사용.
  final Color? color;

  const AppLoading({
    super.key,
    this.size = 28.0,
    this.strokeWidth = 2.5,
    this.color,
  });

  /// 버튼 내부에 넣는 작은 인디케이터 (흰색, 16px).
  const AppLoading.button({super.key})
      : size = 16.0,
        strokeWidth = 2.0,
        color = Colors.white;

  /// 전체 화면 중앙 배치용.
  static Widget fullScreen({Color? color}) {
    return Center(
      child: AppLoading(size: 36, color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: color ?? AppColors.mintGreen,
      ),
    );
  }
}
