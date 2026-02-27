import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/supabase_service.dart';
import '../data/auth_repository.dart';
import 'widgets/wave_to_spot_painter.dart';

/// Splash screen: waits for Supabase to initialise, then auto-signs-in
/// anonymously and navigates to the map. Animation plays while waiting.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;
  bool _navigating = false;
  // Minimum display time so the animation is always seen
  bool _minTimeElapsed = false;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    // Ensure splash shows for at least one animation cycle
    Future.delayed(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _minTimeElapsed = true);
      _trySignIn();
    });
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  /// Called when both min time has elapsed AND Supabase has initialised.
  Future<void> _trySignIn() async {
    if (!mounted || _navigating) return;
    // Wait for supabaseInitProvider to complete (non-blocking — it was
    // already kicked off by the provider system, this just awaits it)
    final initAsync = ref.read(supabaseInitProvider);
    if (!initAsync.hasValue) return; // still loading — listener will retry
    _navigating = true;
    try {
      await ref
          .read(authRepositoryProvider)
          .signInAnonymously()
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // Non-fatal — navigate to map even if anon auth fails
    }
    if (mounted) context.go('/map');
  }

  @override
  Widget build(BuildContext context) {
    // When Supabase finishes initialising AND min time has elapsed → sign in
    ref.listen(supabaseInitProvider, (_, next) {
      if (next.hasValue && _minTimeElapsed) _trySignIn();
    });

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(flex: 2),
                // Wave → Spot animation
                SizedBox(
                  height: 108,
                  child: AnimatedBuilder(
                    animation: _waveController,
                    builder: (context, _) => CustomPaint(
                      painter: WaveToSpotPainter(
                        progress: _waveController.value,
                      ),
                      size: const Size(double.infinity, 108),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // App name
                Text(
                  AppStrings.appName,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    foreground: Paint()
                      ..shader = const LinearGradient(
                        colors: [AppColors.mintGreen, AppColors.skyBlue],
                      ).createShader(const Rect.fromLTWH(0, 0, 200, 50)),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 400.ms, duration: 600.ms)
                    .slideY(begin: 0.2, end: 0),
                const SizedBox(height: 12),
                // Slogan
                Text(
                  AppStrings.appSlogan,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                )
                    .animate()
                    .fadeIn(delay: 700.ms, duration: 600.ms)
                    .slideY(begin: 0.2, end: 0),
                const Spacer(flex: 3),
                // Subtle loading indicator (appears after slogan fades in)
                const SizedBox(
                  height: 52,
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: AppColors.mintGreen,
                        strokeWidth: 2.5,
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 1800.ms, duration: 400.ms),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
