import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/nickname_service.dart';
import '../../profile/data/profile_repository.dart';

/// Shown after every login (via router redirect from /onboarding).
/// - App restart while logged in: hasShownPrompt=true → skip to /map.
/// - Fresh login (resetAllLive cleared the flag): always show form,
///   pre-filled with Supabase nickname if one already exists.
class NicknameScreen extends ConsumerStatefulWidget {
  const NicknameScreen({super.key});

  @override
  ConsumerState<NicknameScreen> createState() => _NicknameScreenState();
}

class _NicknameScreenState extends ConsumerState<NicknameScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isChecking = true; // checking for existing nickname
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkExisting();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _checkExisting() async {
    // App restart while still logged in → prompt was already shown, skip to map.
    final alreadyShown = await NicknameNotifier.hasShownPrompt();
    if (!mounted) return;
    if (alreadyShown) {
      try {
        final existing =
            await ref.read(profileRepositoryProvider).getMyNickname();
        if (existing != null && existing.isNotEmpty) {
          await ref.read(nicknameProvider.notifier).set(existing);
        }
      } catch (_) {}
      if (mounted) context.go('/map');
      return;
    }

    // Fresh login → show form, pre-fill with existing nickname if any.
    try {
      final existing =
          await ref.read(profileRepositoryProvider).getMyNickname();
      if (!mounted) return;
      if (existing != null && existing.isNotEmpty) {
        _controller.text = existing;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isChecking = false);
      Future.delayed(const Duration(milliseconds: 300),
          () => _focusNode.requestFocus());
    }
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.length < 2) {
      setState(() => _error = '2자 이상 입력해주세요.');
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await ref.read(profileRepositoryProvider).upsertNickname(name);
      await ref.read(nicknameProvider.notifier).set(name);
      await NicknameNotifier.markPromptShown();
      if (mounted) context.go('/map');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = '저장에 실패했어요. 다시 시도해주세요.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.mintGreen),
        ),
      );
    }

    final nameLength = _controller.text.trim().length;
    final isValid = nameLength >= 2;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 64),
                  Text(
                    '안녕하세요! 👋',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                  )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 8),
                  Text(
                    '앱에서 사용할 닉네임을 정해주세요.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  )
                      .animate()
                      .fadeIn(delay: 100.ms, duration: 400.ms)
                      .slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 48),
                  // Text field
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLength: 10,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => isValid ? _save() : null,
                    onChanged: (_) => setState(() => _error = null),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: '닉네임 (2~10자)',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                      ),
                      counterStyle: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.grey.shade400,
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: AppColors.mintGreen,
                          width: 2,
                        ),
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 200.ms, duration: 400.ms),
                  // Error
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                  const Spacer(),
                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isValid && !_isSaving ? _save : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.mintGreen,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        disabledForegroundColor: Colors.grey.shade500,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              '시작하기',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 300.ms, duration: 400.ms),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
