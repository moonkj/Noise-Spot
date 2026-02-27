import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/supabase_service.dart';
import '../data/auth_repository.dart';
import 'widgets/wave_to_spot_painter.dart';

/// Splash screen: shows brand animation for ≥ 2.6 s, then navigates to the
/// map immediately — auth never blocks navigation.
///
/// [signInAnonymously] is attempted in the background so the session is ready
/// by the time the user tries to submit a report. Retries silently on failure.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;
  bool _gone = false; // prevent double navigation

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    // After 2.6 s, go to map regardless of auth state.
    // Auth is attempted in the background.
    Future.delayed(const Duration(milliseconds: 2600), _goToMap);
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  void _goToMap() {
    if (!mounted || _gone) return;
    _gone = true;
    // Fire-and-forget: attempt anonymous sign-in after navigating.
    // The map is fully viewable without auth; only report submission needs it.
    unawaited(_trySignInBackground());
    context.go('/map');
  }

  /// Silently attempts anonymous sign-in. Retries every 10 s until it
  /// succeeds (e.g. once network is available or Supabase enables anon auth).
  Future<void> _trySignInBackground() async {
    while (true) {
      await Future.delayed(const Duration(milliseconds: 500));
      try {
        await ref
            .read(authRepositoryProvider)
            .signInAnonymously()
            .timeout(const Duration(seconds: 10));
        return; // success
      } catch (_) {
        await Future.delayed(const Duration(seconds: 10));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // If Supabase init completes AND the user already has a stored session,
    // the router will redirect to /map automatically — skip the 2.6 s wait.
    ref.listen(supabaseInitProvider, (_, next) {
      if (next.hasValue) {
        final session =
            ref.read(supabaseClientProvider).auth.currentSession;
        if (session != null) _goToMap();
      }
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
                // Subtle loading indicator
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
