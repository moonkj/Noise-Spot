import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/nickname_service.dart';
import '../data/auth_repository.dart';

enum _AuthMode { login, signup }

class EmailAuthScreen extends ConsumerStatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  ConsumerState<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends ConsumerState<EmailAuthScreen> {
  _AuthMode _mode = _AuthMode.login;
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _error;
  bool _confirmationSent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool get _hasMinLength => _passwordCtrl.text.length >= 8;
  bool get _hasUppercase => _passwordCtrl.text.contains(RegExp(r'[A-Z]'));
  bool get _hasNumber => _passwordCtrl.text.contains(RegExp(r'[0-9]'));
  bool get _hasSpecial =>
      _passwordCtrl.text.contains(RegExp(r'[!@#$%^&*()\-_=+\[\]{};:,.<>?/|\\`~]'));
  bool get _passwordValid =>
      _hasMinLength && _hasUppercase && _hasNumber && _hasSpecial;

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = '이메일과 비밀번호를 입력해주세요.');
      return;
    }

    if (_mode == _AuthMode.signup) {
      if (!_passwordValid) {
        setState(() => _error = '비밀번호 조건을 모두 충족해주세요.');
        return;
      }
      if (_confirmCtrl.text != password) {
        setState(() => _error = '비밀번호가 일치하지 않아요.');
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (_mode == _AuthMode.login) {
        await ref.read(nicknameProvider.notifier).resetAllLive();
        await ref.read(authRepositoryProvider).signInWithEmail(email, password);
        // Router redirect handles navigation to /nickname
      } else {
        final sessionCreated =
            await ref.read(authRepositoryProvider).signUpWithEmail(email, password);
        if (!sessionCreated) {
          if (mounted) setState(() { _isLoading = false; _confirmationSent = true; });
          return;
        }
        await ref.read(nicknameProvider.notifier).resetAllLive();
        // Router redirect handles navigation
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() { _isLoading = false; _error = _localize(e.message); });
      }
    } catch (_) {
      if (mounted) {
        setState(() { _isLoading = false; _error = '오류가 발생했어요. 다시 시도해주세요.'; });
      }
    }
  }

  String _localize(String msg) {
    if (msg.contains('Invalid login credentials')) {
      return '이메일 또는 비밀번호가 올바르지 않아요.';
    }
    if (msg.contains('already registered') || msg.contains('already been registered')) {
      return '이미 가입된 이메일이에요. 로그인을 시도해주세요.';
    }
    if (msg.contains('valid email')) return '올바른 이메일 형식을 입력해주세요.';
    if (msg.contains('Password should be')) return '비밀번호 조건을 확인해주세요.';
    return '오류가 발생했어요. 다시 시도해주세요.';
  }

  void _toggleMode() {
    setState(() {
      _mode = _mode == _AuthMode.login ? _AuthMode.signup : _AuthMode.login;
      _error = null;
      _confirmationSent = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLogin = _mode == _AuthMode.login;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: AppColors.textPrimary, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(height: 32),
                // Title
                Text(
                  isLogin ? '로그인' : '회원가입',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                ).animate().fadeIn(duration: 300.ms),
                const SizedBox(height: 8),
                Text(
                  isLogin ? '계정에 로그인하세요.' : '새 계정을 만드세요.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ).animate().fadeIn(delay: 50.ms, duration: 300.ms),
                const SizedBox(height: 40),

                if (_confirmationSent) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.mintGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.mintGreen.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('📧 이메일을 확인해주세요!',
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 16)),
                        const SizedBox(height: 8),
                        Text(
                          '${_emailCtrl.text}로\n확인 링크를 발송했어요. 링크를 클릭한 후 로그인해주세요.',
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              height: 1.6,
                              fontSize: 14),
                        ),
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: _toggleMode,
                          child: const Text('로그인하러 가기 →',
                              style: TextStyle(
                                  color: AppColors.mintGreen,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Email field
                  _Field(
                    controller: _emailCtrl,
                    label: '이메일',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() => _error = null),
                  ),
                  const SizedBox(height: 20),
                  // Password field
                  _Field(
                    controller: _passwordCtrl,
                    label: '비밀번호',
                    hint: '영문 대문자·숫자·특수문자 포함 8자 이상',
                    obscure: _obscurePass,
                    textInputAction:
                        isLogin ? TextInputAction.done : TextInputAction.next,
                    onChanged: (_) => setState(() => _error = null),
                    onSubmitted: isLogin ? (_) => _submit() : null,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePass
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePass = !_obscurePass),
                    ),
                  ),
                  // Signup extras
                  if (!isLogin) ...[
                    const SizedBox(height: 16),
                    _PasswordRequirements(
                      hasMinLength: _hasMinLength,
                      hasUppercase: _hasUppercase,
                      hasNumber: _hasNumber,
                      hasSpecial: _hasSpecial,
                    ),
                    const SizedBox(height: 20),
                    _Field(
                      controller: _confirmCtrl,
                      label: '비밀번호 확인',
                      obscure: _obscureConfirm,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() => _error = null),
                      onSubmitted: (_) => _submit(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                  ],
                  // Error
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: TextStyle(
                            fontSize: 13, color: Colors.red.shade700)),
                  ],
                  const SizedBox(height: 32),
                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.mintGreen,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        disabledForegroundColor: Colors.grey.shade500,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text(isLogin ? '로그인' : '회원가입',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Toggle mode
                  Center(
                    child: GestureDetector(
                      onTap: _toggleMode,
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                              fontSize: 14, color: AppColors.textSecondary),
                          children: [
                            TextSpan(
                                text: isLogin
                                    ? '계정이 없으신가요?  '
                                    : '이미 계정이 있으신가요?  '),
                            TextSpan(
                              text: isLogin ? '회원가입' : '로그인',
                              style: const TextStyle(
                                  color: AppColors.mintGreen,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Shared text field widget
// ─────────────────────────────────────────────
class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;

  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
        suffixIcon: suffixIcon,
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.shade400, width: 1.5),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.mintGreen, width: 2),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Password requirement checklist
// ─────────────────────────────────────────────
class _PasswordRequirements extends StatelessWidget {
  final bool hasMinLength, hasUppercase, hasNumber, hasSpecial;

  const _PasswordRequirements({
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasNumber,
    required this.hasSpecial,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Req('8자 이상', hasMinLength),
        const SizedBox(height: 4),
        _Req('대문자 포함', hasUppercase),
        const SizedBox(height: 4),
        _Req('숫자 포함', hasNumber),
        const SizedBox(height: 4),
        _Req('특수문자 포함 (!@#\$ 등)', hasSpecial),
      ],
    );
  }
}

class _Req extends StatelessWidget {
  final String label;
  final bool met;
  const _Req(this.label, this.met);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          met ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 14,
          color: met ? AppColors.mintGreen : Colors.grey.shade400,
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 13,
                color: met ? AppColors.mintGreen : Colors.grey.shade500)),
      ],
    );
  }
}
