import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/moderation_service.dart';
import '../../../core/services/nickname_service.dart';
import '../data/profile_repository.dart';

class NicknameSetupSheet extends ConsumerStatefulWidget {
  const NicknameSetupSheet({super.key});

  @override
  ConsumerState<NicknameSetupSheet> createState() => _NicknameSetupSheetState();
}

class _NicknameSetupSheetState extends ConsumerState<NicknameSetupSheet> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    try {
      final name = _controller.text.trim();
      // 0. 콘텐츠 모더레이션 (로컬 필터 + Google NL API)
      final moderationError = await ModerationService.validate(name);
      if (moderationError != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(moderationError)),
          );
        }
        return;
      }
      // 1. 로컬 먼저 저장 (즉각 UI 반영)
      await ref.read(nicknameProvider.notifier).set(name);
      // 2. 시트 닫기
      if (mounted) Navigator.of(context).pop();
      // 3. 서버 동기화 (백그라운드, 실패해도 로컬은 보존)
      ref.read(profileRepositoryProvider).upsertNickname(name).catchError((_) {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 40,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '카페바이브에 오신걸 환영해요! 👋',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '닉네임을 설정하면 랭킹에 이름이 표시돼요',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 28),
            TextFormField(
              controller: _controller,
              maxLength: 10,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
              decoration: InputDecoration(
                labelText: '닉네임',
                hintText: '2~10자 입력',
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.mintGreen, width: 2),
                ),
              ),
              validator: (v) {
                final trimmed = v?.trim() ?? '';
                if (trimmed.length < 2) return '2자 이상 입력해 주세요';
                if (trimmed.length > 10) return '10자 이하로 입력해 주세요';
                if (!RegExp(r'^[가-힣a-zA-Z0-9]+$').hasMatch(trimmed)) {
                  return '한글, 영문, 숫자만 사용 가능해요';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mintGreen,
                  disabledBackgroundColor: AppColors.mintGreen.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
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
                        '저장',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () async {
                  final nav = Navigator.of(context);
                  await NicknameNotifier.markPromptShown();
                  nav.pop();
                },
                child: Text(
                  '나중에 설정',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
