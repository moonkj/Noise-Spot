import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import 'widgets/flowing_wave_painter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) context.go('/map');
    });
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final background = isDark
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D1F1A), Color(0xFF0D1A2E)],
          )
        : AppColors.bgGradient;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: background),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // Wave animation
              SizedBox(
                height: 170,
                child: AnimatedBuilder(
                  animation: _waveController,
                  builder: (context, _) => CustomPaint(
                    painter: FlowingWavePainter(
                      animation: _waveController.value,
                      isDark: isDark,
                    ),
                    size: const Size(double.infinity, 170),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // App name
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AppColors.mintGreen, AppColors.skyBlue],
                ).createShader(bounds),
                child: Text(
                  AppStrings.appName,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                ),
              ),

              const SizedBox(height: 10),

              Text(
                AppStrings.appSlogan,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.55),
                      height: 1.5,
                    ),
              ),

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
