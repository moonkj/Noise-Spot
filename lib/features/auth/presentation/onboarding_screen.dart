import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/nickname_service.dart';
import '../data/auth_repository.dart';
import 'widgets/wave_to_spot_painter.dart';

/// Login screen: shows brand animation for 1.5 s, then fades in
/// Apple Sign In (iOS only) and Google Sign In buttons.
/// On successful auth, the router redirect handles navigation to /map.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;
  bool _showButtons = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    // Fade-in buttons after 1.5 s
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showButtons = true);
    });
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _onApple() async {
    await NicknameNotifier.resetAll(); // clear stale local nickname from previous session
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authRepositoryProvider).signInWithApple();
      // Router redirect handles navigation
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Apple 로그인에 실패했어요. 다시 시도해 주세요.';
        });
      }
    }
  }

  Future<void> _onGoogle() async {
    await NicknameNotifier.resetAll(); // clear stale local nickname from previous session
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      // Google OAuth opens browser — router redirect handles callback
      // Reset loading if browser closes without completing auth
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Google 로그인에 실패했어요. 다시 시도해 주세요.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                // Login buttons area
                AnimatedOpacity(
                  opacity: _showButtons ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 600),
                  child: _isLoading
                      ? const SizedBox(
                          height: 52,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.mintGreen,
                              strokeWidth: 2.5,
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            if (_errorMessage != null) ...[
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.red.shade400,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            // Apple Sign In (iOS only)
                            if (Platform.isIOS) ...[
                              SignInWithAppleButton(
                                onPressed: _onApple,
                                style: SignInWithAppleButtonStyle.black,
                                height: 50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              const SizedBox(height: 12),
                            ],
                            // Google Sign In
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: OutlinedButton.icon(
                                onPressed: _onGoogle,
                                icon: const Icon(
                                  Icons.g_mobiledata_rounded,
                                  size: 22,
                                ),
                                label: const Text('Google로 계속하기'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF444444),
                                  side: BorderSide(
                                      color: Colors.grey.shade300),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  backgroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
