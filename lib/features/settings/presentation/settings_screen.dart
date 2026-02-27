import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/nickname_service.dart';
import '../../auth/data/auth_repository.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  PermissionStatus _micStatus = PermissionStatus.denied;
  PermissionStatus _locationStatus = PermissionStatus.denied;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final mic = await Permission.microphone.status;
    final loc = await Permission.locationWhenInUse.status;
    setState(() {
      _micStatus = mic;
      _locationStatus = loc;
    });
  }

  @override
  Widget build(BuildContext context) {
    final nickname = ref.watch(nicknameProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.go('/map'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── 내 프로필 ──────────────────────────────────────────
          _SectionHeader(title: '내 프로필'),
          ListTile(
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.mintGreen.withValues(alpha: 0.15),
              child: const Icon(
                Icons.person_rounded,
                color: AppColors.mintGreen,
                size: 22,
              ),
            ),
            title: Text(
              nickname ?? '이름 없음',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: nickname == null
                        ? AppColors.textHint
                        : AppColors.textPrimary,
                  ),
            ),
            subtitle: Text(
              nickname == null ? '탭해서 닉네임을 설정해보세요' : '닉네임',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            trailing: const Icon(
              Icons.edit_rounded,
              size: 18,
              color: AppColors.textHint,
            ),
            onTap: () => _editNickname(context, nickname),
          ),
          const SizedBox(height: 8),

          // ── 권한 관리 ──────────────────────────────────────────
          _SectionHeader(title: '권한 관리'),
          _PermissionTile(
            icon: Icons.mic_rounded,
            title: AppStrings.micPermission,
            subtitle: '소음 수치(dB) 측정에만 사용됩니다',
            status: _micStatus,
            onManage: () async {
              if (_micStatus.isPermanentlyDenied) {
                await openAppSettings();
              } else {
                await Permission.microphone.request();
              }
              await _checkPermissions();
            },
          ),
          _PermissionTile(
            icon: Icons.location_on_rounded,
            title: AppStrings.locationPermission,
            subtitle: '주변 스팟 탐색 및 리포팅 위치 검증에 사용됩니다',
            status: _locationStatus,
            onManage: () async {
              if (_locationStatus.isPermanentlyDenied) {
                await openAppSettings();
              } else {
                await Permission.locationWhenInUse.request();
              }
              await _checkPermissions();
            },
          ),
          const SizedBox(height: 8),

          // ── 개인정보 ───────────────────────────────────────────
          _SectionHeader(title: '개인정보'),
          _PrivacySection(),
          const SizedBox(height: 8),

          // ── 계정 ──────────────────────────────────────────────
          _SectionHeader(title: '계정'),
          _ActionTile(
            icon: Icons.delete_outline_rounded,
            title: AppStrings.deleteAccount,
            textColor: AppColors.dbVeryLoud,
            onTap: () => _confirmDeleteAccount(context),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _editNickname(BuildContext context, String? current) {
    final controller = TextEditingController(text: current ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('닉네임 설정'),
        content: TextField(
          controller: controller,
          maxLength: 20,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '사용할 이름을 입력하세요',
            counterText: '',
          ),
          onSubmitted: (_) => _saveNickname(context, controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => _saveNickname(context, controller.text),
            child: Text(
              '저장',
              style: TextStyle(color: AppColors.mintGreen),
            ),
          ),
        ],
      ),
    );
  }

  void _saveNickname(BuildContext context, String value) {
    if (value.trim().isNotEmpty) {
      ref.read(nicknameProvider.notifier).set(value);
    }
    Navigator.pop(context);
  }

  void _confirmDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('데이터 초기화'),
        content: const Text(
          '모든 측정 기록이 삭제되고 새로운 사용자로 시작됩니다.\n이 작업은 되돌릴 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(nicknameProvider.notifier).clear();
              await ref.read(authRepositoryProvider).deleteAccount();
              if (context.mounted) context.go('/onboarding');
            },
            child: const Text(
              '초기화',
              style: TextStyle(color: AppColors.dbVeryLoud),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacySection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.mintGreen.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.mintGreen.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_rounded, size: 16, color: AppColors.mintGreen),
              const SizedBox(width: 8),
              Text(
                AppStrings.privacyPolicy,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.mintGreen,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '• 마이크로 측정한 음성 데이터는 기기 내 메모리에서만 처리\n'
            '• dB 수치만 서버에 저장되며 음성 파일은 전송하지 않음\n'
            '• 위치는 주변 스팟 탐색 목적으로만 사용',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textHint,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final PermissionStatus status;
  final VoidCallback onManage;

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final isGranted = status == PermissionStatus.granted;
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary, size: 22),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isGranted
                  ? AppColors.mintGreen.withValues(alpha: 0.1)
                  : AppColors.dbVeryLoud.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isGranted ? '허용됨' : '거부됨',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isGranted ? AppColors.mintGreen : AppColors.dbVeryLoud,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onManage,
            child: const Text('관리'),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color textColor;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: textColor, size: 22),
      title: Text(
        title,
        style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
      ),
      onTap: onTap,
    );
  }
}
