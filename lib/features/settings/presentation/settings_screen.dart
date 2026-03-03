import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/admin_config.dart';
import '../../../core/services/theme_mode_service.dart';
import '../../../core/services/admin_dummy_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;
import '../../../core/services/badge_service.dart';
import '../../../core/services/nickname_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/level_service.dart' show BadgeInfo;
import '../../auth/data/auth_repository.dart';
import '../../admin/data/cafe_requests_repository.dart';
import '../../../core/services/places_service.dart';
import '../../map/data/spots_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/widgets/badge_earned_popup.dart';
import '../../profile/presentation/profile_screen.dart' show adminBadgePreviewProvider;
import '../../../core/services/location_service.dart';
import '../../../core/services/rep_badge_service.dart';
import '../../../core/services/calibration_service.dart';
import '../../../core/services/review_service.dart';
import '../../../core/services/moderation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  bool _micGranted = false;
  bool _locationGranted = false;
  bool _permCheckInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-check permissions whenever the app returns to foreground.
  /// iOS propagates permission changes asynchronously after the user returns
  /// from Settings — we check at 1 s and again at 2.5 s to handle slow devices.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) _checkPermissions();
      });
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted) _checkPermissions();
      });
    }
  }

  // Native channel bypasses permission_handler iOS 26 beta bugs.
  static const _permChannel = MethodChannel('com.cafevibe/permissions');

  Future<bool> _checkMicNative() async {
    try {
      final result = await _permChannel.invokeMethod<String>('checkMicrophonePermission');
      return result == 'authorized';
    } catch (_) {
      // Fallback to permission_handler if channel fails
      final s = await Permission.microphone.status;
      return s.isGranted;
    }
  }

  Future<void> _checkPermissions() async {
    if (_permCheckInFlight) return;
    _permCheckInFlight = true;
    try {
    // Use AVCaptureDevice.authorizationStatus(for: .audio) via native channel —
    // most reliable across all iOS versions including iOS 26 beta.
    final micGranted = await _checkMicNative();

    // Location: use Geolocator — same package the app uses for actual location,
    // ensuring consistent status with how iOS actually granted it.
    LocationPermission geoLoc;
    try {
      geoLoc = await Geolocator.checkPermission();
    } catch (_) {
      geoLoc = LocationPermission.denied;
    }
    final locGranted =
        geoLoc == LocationPermission.always ||
        geoLoc == LocationPermission.whileInUse;

    if (mounted) {
      setState(() {
        _micGranted = micGranted;
        _locationGranted = locGranted;
      });
    }
    } finally {
      _permCheckInFlight = false;
    }
  }

  bool get _isAdmin {
    final uid = ref.read(authRepositoryProvider).currentUser?.id;
    return uid != null && AdminConfig.adminUserIds.contains(uid);
  }

  @override
  Widget build(BuildContext context) {
    final nickname = ref.watch(nicknameProvider);
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // ── Custom AppBar ──
          Container(
            color: Theme.of(context).colorScheme.surface,
            padding: EdgeInsets.only(top: top),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  onPressed: () => context.go('/profile'),
                ),
                Expanded(
                  child: Text(
                    '설정',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 48), // balance the back button
              ],
            ),
          ),

          // ── Body ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                // ── 화면 설정 ──────────────────────────────────────────
                _SectionHeader('화면 설정'),
                _ThemeModeTile(),

                // ── 계정 정보 ──────────────────────────────────────────
                _SectionHeader('계정 정보'),
                _SettingsTile(
                  icon: Icons.person_outline,
                  title: '닉네임',
                  trailing: Text(
                    nickname ?? '설정 안 됨',
                    style: TextStyle(
                      fontSize: 14,
                      color: nickname != null
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  onTap: () => _editNickname(context, nickname),
                ),
                // ── 알림 설정 ──────────────────────────────────────────
                _SectionHeader('알림 설정'),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.notifications_outlined, size: 20,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '알림 기능은 업데이트 예정이에요',
                          style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── 권한 관리 ──────────────────────────────────────────
                _SectionHeader('권한 관리'),
                _PermissionTile(
                  icon: Icons.mic_rounded,
                  title: '마이크',
                  subtitle: '데시벨 수치(dB) 측정에만 사용됩니다',
                  isGranted: _micGranted,
                  onManage: () => openAppSettings(),
                ),
                _PermissionTile(
                  icon: Icons.location_on_rounded,
                  title: '위치',
                  subtitle: '주변 카페 탐색 및 측정 위치 확인에 사용됩니다',
                  isGranted: _locationGranted,
                  onManage: () => openAppSettings(),
                ),

                // ── 정보 ──────────────────────────────────────────────
                _SectionHeader('정보'),
                _SettingsTile(
                  icon: Icons.info_outline,
                  title: '앱 버전',
                  trailing: Text(
                    '1.0.0',
                    style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                  ),
                ),
                _SettingsTile(
                  icon: Icons.shield_outlined,
                  title: '개인정보 처리방침',
                  showArrow: true,
                  onTap: () => _showPrivacyNotice(context),
                ),
                _SettingsTile(
                  icon: Icons.article_outlined,
                  title: '이용약관',
                  showArrow: true,
                  onTap: () => _showTermsNotice(context),
                ),
                _SettingsTile(
                  icon: Icons.code_outlined,
                  title: '오픈소스 라이선스',
                  showArrow: true,
                  onTap: () => showLicensePage(context: context, applicationName: 'Cafe Vibe'),
                ),

                // ── 요청사항 (일반 사용자) ───────────────────────────
                _SectionHeader('요청사항'),
                _SettingsTile(
                  icon: Icons.add_location_alt_outlined,
                  title: '카페 등록/삭제 요청',
                  subtitle: '새 카페 등록 또는 폐업 카페 삭제를 운영자에게 요청',
                  showArrow: true,
                  onTap: () => _showCafeRequestSheet(context),
                ),
                _SettingsTile(
                  icon: Icons.lightbulb_outline_rounded,
                  title: '제안사항',
                  subtitle: '서비스 개선 의견을 운영자에게 전달',
                  showArrow: true,
                  onTap: () => _showSuggestionSheet(context),
                ),

                // ── 관리자 ─────────────────────────────────────────────
                if (_isAdmin) ...[
                  _SectionHeader('관리자'),
                  _SettingsTile(
                    icon: Icons.admin_panel_settings_outlined,
                    title: '카페 등록/삭제 요청 목록',
                    showArrow: true,
                    onTap: () => _showAdminRequestsSheet(context),
                  ),
                  _SettingsTile(
                    icon: Icons.lightbulb_outline_rounded,
                    title: '제안사항 목록',
                    showArrow: true,
                    onTap: () => _showAdminSuggestionsSheet(context),
                  ),
                  _SettingsTile(
                    icon: Icons.store_outlined,
                    title: '등록된 카페 관리',
                    subtitle: '직접 등록한 카페 수정 / 삭제',
                    showArrow: true,
                    onTap: () => _showAdminSpotsSheet(context),
                  ),
                  _SettingsTile(
                    icon: Icons.add_location_alt_outlined,
                    title: '현재 위치 더미 카페 등록',
                    subtitle: '현재 위치에 임시 카페 등록',
                    showArrow: false,
                    onTap: () => _registerDummySpot(context),
                  ),
                  _SettingsTile(
                    icon: Icons.workspace_premium_outlined,
                    title: '뱃지 전체 미리보기',
                    subtitle: '프로필에서 모든 뱃지를 획득 상태로 표시',
                    trailing: Switch(
                      value: ref.watch(adminBadgePreviewProvider),
                      onChanged: (_) =>
                          ref.read(adminBadgePreviewProvider.notifier).toggle(),
                      activeThumbColor: AppColors.mintGreen,
                      activeTrackColor: AppColors.mintGreen.withValues(alpha: 0.4),
                    ),
                  ),
                  // ── 강남역 더미 데이터 모드 ─────────────────────────
                  _buildDummyModeTile(),
                ],

                // ── 데이터 관리 ────────────────────────────────────────
                _SectionHeader('데이터 관리'),
                _SettingsTile(
                  icon: Icons.logout_rounded,
                  title: '로그아웃',
                  onTap: () => _confirmLogout(context),
                ),
                _DangerTile(
                  icon: Icons.restore_rounded,
                  title: '앱 데이터 초기화',
                  onTap: () => _confirmDataReset(context),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveNickname(String newNick) async {
    final trimmed = newNick.trim();
    if (trimmed.length < 2) return;
    if (!RegExp(r'^[가-힣a-zA-Z0-9]+$').hasMatch(trimmed)) return;
    ref.read(nicknameProvider.notifier).set(trimmed);
    ref.read(profileRepositoryProvider).upsertNickname(trimmed).catchError((_) {});
  }

  void _editNickname(BuildContext context, String? current) {
    final controller = TextEditingController(text: current ?? '');
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('닉네임 설정'),
        content: TextField(
          controller: controller,
          maxLength: 10,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '2~10자 (한글, 영문, 숫자)',
            counterText: '',
          ),
          onSubmitted: (_) {
            final nick = controller.text.trim();
            Navigator.pop(dialogCtx);
            if (nick.isNotEmpty) _saveNickname(nick);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              final nick = controller.text.trim();
              Navigator.pop(dialogCtx);
              if (nick.isNotEmpty) _saveNickname(nick);
            },
            child: const Text('저장', style: TextStyle(color: AppColors.mintGreen)),
          ),
        ],
      ),
    );
  }

  Future<void> _showPrivacyNotice(BuildContext context) async {
    final uri = Uri.parse(
      'https://moonkj.github.io/Vibe-cafe/docs/privacy-policy.html',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showTermsNotice(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('이용약관'),
        content: const SingleChildScrollView(
          child: Text(
            '1. 본 앱은 카페의 소음 정보를 공유하는 커뮤니티 서비스입니다\n'
            '2. 측정 데이터는 공익 목적으로 공개될 수 있습니다\n'
            '3. 허위 데이터 등록 등 서비스 어뷰징 행위는 제재될 수 있습니다\n'
            '4. 서비스는 사전 예고 없이 변경 또는 종료될 수 있습니다',
            style: TextStyle(fontSize: 14, height: 1.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인', style: TextStyle(color: AppColors.mintGreen)),
          ),
        ],
      ),
    );
  }

  /// Builds the dummy mode switch tile with loading/error states.
  Widget _buildDummyModeTile() {
    final dummyAsync = ref.watch(adminDummyModeProvider);
    final isOn = dummyAsync.asData?.value ?? false;
    final isLoading = dummyAsync.isLoading;

    // Show error snackbar whenever the provider enters error state
    ref.listen<AsyncValue<bool>>(adminDummyModeProvider, (prev, next) {
      if (next.hasError && !next.isLoading) {
        final msg = next.error.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('더미 모드 오류: $msg'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    });

    return _SettingsTile(
      icon: Icons.fmd_good_outlined,
      title: '강남역 더미 데이터 모드',
      subtitle: isOn
          ? '📍 강남역으로 위치 오버라이드 중'
          : '강남역 주변 카페 30개 + 측정 데이터 삽입',
      trailing: isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.mintGreen,
              ),
            )
          : Switch(
              value: isOn,
              onChanged: (v) {
                if (v) {
                  ref.read(adminDummyModeProvider.notifier).enable();
                } else {
                  ref.read(adminDummyModeProvider.notifier).disable();
                }
              },
              activeThumbColor: AppColors.mintGreen,
              activeTrackColor: AppColors.mintGreen.withValues(alpha: 0.4),
            ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃하면 다시 로그인해야 합니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await ref.read(authRepositoryProvider).signOut();
              // router redirect navigates to /onboarding automatically
            },
            child: const Text(
              '로그아웃',
              style: TextStyle(color: AppColors.mintGreen),
            ),
          ),
        ],
      ),
    );
  }

  void _showCafeRequestSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CafeRequestSheet(
        repo: ref.read(cafeRequestsRepositoryProvider),
        supabaseClient: ref.read(supabaseClientProvider),
        onBadgeEarned: (badge) async {
          if (context.mounted) await showBadgeEarnedPopup(context, badge);
        },
      ),
    );
  }

  void _showSuggestionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SuggestionSheet(
        repo: ref.read(cafeRequestsRepositoryProvider),
        supabaseClient: ref.read(supabaseClientProvider),
        onBadgeEarned: (badge) async {
          if (context.mounted) await showBadgeEarnedPopup(context, badge);
        },
      ),
    );
  }

  void _showAdminSuggestionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AdminSuggestionsSheet(
        repo: ref.read(cafeRequestsRepositoryProvider),
      ),
    );
  }

  Future<void> _registerDummySpot(BuildContext context) async {
    final now = DateTime.now();
    final nameCtrl = TextEditingController(
      text: '임시 카페 ${now.hour}:${now.minute.toString().padLeft(2, '0')}',
    );
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('더미 카페 등록'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '현재 GPS 위치에 임시 카페를 등록합니다.\n"등록된 카페 관리"에서 삭제할 수 있습니다.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: '카페 이름'),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('등록', style: TextStyle(color: AppColors.mintGreen)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;

    try {
      final position = await LocationService.getCurrentPosition();
      final id = await ref.read(spotsRepositoryProvider).createSpot(
            name: name,
            googlePlaceId: null,
            lat: position.latitude,
            lng: position.longitude,
          );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '✓ 등록 완료\nID: ${id.substring(0, 8)}…  |  "등록된 카페 관리"에서 삭제하세요',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('등록 실패: $e')),
      );
    }
  }

  void _showAdminSpotsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AdminSpotsSheet(
        spotsRepo: ref.read(spotsRepositoryProvider),
        placesService: ref.read(placesServiceProvider),
      ),
    );
  }

  void _showAdminRequestsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AdminRequestsSheet(
        repo: ref.read(cafeRequestsRepositoryProvider),
        spotsRepo: ref.read(spotsRepositoryProvider),
        placesService: ref.read(placesServiceProvider),
      ),
    );
  }

  void _confirmDataReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('앱 데이터 초기화'),
        content: const Text(
          '모든 측정 기록, 뱃지, 닉네임이 삭제되고\n새로운 사용자로 다시 시작됩니다.\n\n이 작업은 되돌릴 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              // Clear all local SharedPreferences data
              await NicknameNotifier.resetAll();
              await RepBadgeNotifier.resetAll();
              await CalibrationService.resetAll();
              await ReviewService.resetAll();
              // Delete all server-side user data (reports, badges, profile, stats)
              await ref.read(authRepositoryProvider).deleteAccount();
              if (context.mounted) context.go('/onboarding');
            },
            child: const Text('초기화', style: TextStyle(color: AppColors.dbVeryLoud)),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Shared widgets
// ──────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
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

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool showArrow;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.showArrow = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
        title: Text(
          title,
          style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurface),
        ),
        subtitle: subtitle != null
            ? Text(subtitle!,
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)))
            : null,
        trailing: trailing ??
            (showArrow
                ? Icon(Icons.chevron_right,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))
                : null),
        onTap: onTap,
      ),
    );
  }
}


class _ThemeModeTile extends ConsumerWidget {
  const _ThemeModeTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeModeProvider);

    final options = [
      (mode: ThemeMode.light, label: '라이트', icon: Icons.light_mode_outlined),
      (mode: ThemeMode.system, label: '자동', icon: Icons.brightness_auto_outlined),
      (mode: ThemeMode.dark, label: '다크', icon: Icons.dark_mode_outlined),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.contrast_outlined,
            size: 20,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '화면 테마',
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          Container(
            height: 34,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: options.map((opt) {
                final isSelected = current == opt.mode;
                return GestureDetector(
                  onTap: () => ref.read(themeModeProvider.notifier).setMode(opt.mode),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.mintGreen : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          opt.icon,
                          size: 14,
                          color: isSelected
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          opt.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isGranted;
  final VoidCallback onManage;

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isGranted,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
        title: Text(title, style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurface)),
        subtitle: Text(subtitle,
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isGranted
                    ? AppColors.mintGreen.withValues(alpha: 0.1)
                    : AppColors.dbVeryLoud.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
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
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(40, 32),
              ),
              child: Text(
                isGranted ? '설정에서 변경' : '설정에서 허용',
                style: const TextStyle(color: AppColors.mintGreen),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 관리자: 요청 목록 바텀시트 ──────────────────────────────────
class _AdminRequestsSheet extends StatefulWidget {
  final CafeRequestsRepository repo;
  final SpotsRepository spotsRepo;
  final PlacesService placesService;
  const _AdminRequestsSheet({
    required this.repo,
    required this.spotsRepo,
    required this.placesService,
  });

  @override
  State<_AdminRequestsSheet> createState() => _AdminRequestsSheetState();
}

class _AdminRequestsSheetState extends State<_AdminRequestsSheet> {
  late Future<List<CafeRequest>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repo.fetchPending();
  }

  void _refresh() => setState(() => _future = widget.repo.fetchPending());

  Future<void> _updateStatus(BuildContext context, String id, String status) async {
    try {
      await widget.repo.updateStatus(id, status);
      _refresh();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e')),
        );
      }
    }
  }

  Future<void> _approveRequest(BuildContext context, CafeRequest r) async {
    final nameCtrl = TextEditingController(text: r.cafeName);
    final addrCtrl = TextEditingController(text: r.address ?? '');
    final latCtrl = TextEditingController();
    final lngCtrl = TextEditingController();
    bool loading = false;
    bool geocoding = false;

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('카페 등록'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: '카페 이름 *'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: addrCtrl,
                        decoration: const InputDecoration(labelText: '주소'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    geocoding
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : TextButton(
                            onPressed: () async {
                              final addr = addrCtrl.text.trim();
                              if (addr.isEmpty) return;
                              setSt(() => geocoding = true);
                              final result = await widget.placesService
                                  .geocodeAddress(addr);
                              setSt(() => geocoding = false);
                              if (result != null) {
                                latCtrl.text = result.lat.toStringAsFixed(6);
                                lngCtrl.text = result.lng.toStringAsFixed(6);
                              } else if (dialogCtx.mounted) {
                                ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                  const SnackBar(
                                      content: Text('주소로 좌표를 찾을 수 없습니다')),
                                );
                              }
                            },
                            style: TextButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: const Size(0, 36),
                            ),
                            child: const Text('자동',
                                style: TextStyle(
                                    color: AppColors.mintGreen, fontSize: 13)),
                          ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: latCtrl,
                        decoration: const InputDecoration(
                          labelText: '위도 *',
                          hintText: '36.6423',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: lngCtrl,
                        decoration: const InputDecoration(
                          labelText: '경도 *',
                          hintText: '127.4282',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: loading
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      final lat = double.tryParse(latCtrl.text.trim());
                      final lng = double.tryParse(lngCtrl.text.trim());
                      if (name.isEmpty || lat == null || lng == null) return;
                      setSt(() => loading = true);
                      try {
                        await widget.spotsRepo.createSpot(
                          name: name,
                          googlePlaceId: null,
                          lat: lat,
                          lng: lng,
                          formattedAddress: addrCtrl.text.trim().isEmpty
                              ? null
                              : addrCtrl.text.trim(),
                        );
                        await widget.repo.updateStatus(r.id, 'approved');
                        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                        _refresh();
                      } catch (e) {
                        setSt(() => loading = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('오류: $e')),
                          );
                        }
                      }
                    },
              child: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      '등록 & 승인',
                      style: TextStyle(color: AppColors.mintGreen),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('카페 등록/삭제 요청 목록', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<CafeRequest>>(
              future: _future,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                // 제안사항([제안]) 제외, 카페 등록/삭제 요청만 표시
                final list = (snap.data ?? []).where((r) => r.cafeName != '[제안]').toList();
                if (list.isEmpty) {
                  return const Center(child: Text('대기 중인 요청이 없습니다.', style: TextStyle(color: Colors.grey)));
                }
                return ListView.separated(
                  controller: ctrl,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: list.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final r = list[i];
                    final isDeletion = r.note?.startsWith('[삭제 요청]') ?? false;
                    final displayNote = isDeletion
                        ? r.note!.replaceFirst('[삭제 요청]', '').trim()
                        : r.note;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isDeletion
                                        ? Colors.red.withValues(alpha: 0.12)
                                        : AppColors.mintGreen.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isDeletion ? '삭제 요청' : '등록 요청',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDeletion ? Colors.red.shade700 : AppColors.mintGreen,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(r.cafeName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                            if (r.address != null && r.address!.isNotEmpty)
                              Text(r.address!, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                            if (displayNote != null && displayNote.isNotEmpty)
                              Text('메모: $displayNote', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                            Text(r.createdAt.toLocal().toString().substring(0, 16), style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => _updateStatus(context, r.id, 'rejected'),
                                  child: const Text('거절', style: TextStyle(color: Colors.red)),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: isDeletion
                                      ? () => _updateStatus(context, r.id, 'completed')
                                      : () => _approveRequest(context, r),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDeletion ? Colors.red.shade600 : AppColors.mintGreen,
                                  ),
                                  child: Text(
                                    isDeletion ? '삭제 확인' : '승인 & 등록',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── 관리자: 등록된 카페 관리 바텀시트 ─────────────────────────────
class _AdminSpotsSheet extends StatefulWidget {
  final SpotsRepository spotsRepo;
  final PlacesService placesService;
  const _AdminSpotsSheet({required this.spotsRepo, required this.placesService});

  @override
  State<_AdminSpotsSheet> createState() => _AdminSpotsSheetState();
}

class _AdminSpotsSheetState extends State<_AdminSpotsSheet> {
  late Future<List<AdminSpot>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.spotsRepo.fetchManualSpots();
  }

  void _refresh() => setState(() => _future = widget.spotsRepo.fetchManualSpots());

  Future<void> _editSpot(BuildContext context, AdminSpot spot) async {
    final nameCtrl = TextEditingController(text: spot.name);
    final addrCtrl = TextEditingController(text: spot.formattedAddress ?? '');
    final latCtrl = TextEditingController(text: spot.lat.toStringAsFixed(6));
    final lngCtrl = TextEditingController(text: spot.lng.toStringAsFixed(6));
    bool loading = false;
    bool geocoding = false;

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('카페 수정'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: '카페 이름 *'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: addrCtrl,
                        decoration: const InputDecoration(labelText: '주소'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    geocoding
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : TextButton(
                            onPressed: () async {
                              final addr = addrCtrl.text.trim();
                              if (addr.isEmpty) return;
                              setSt(() => geocoding = true);
                              final result = await widget.placesService.geocodeAddress(addr);
                              setSt(() => geocoding = false);
                              if (result != null) {
                                latCtrl.text = result.lat.toStringAsFixed(6);
                                lngCtrl.text = result.lng.toStringAsFixed(6);
                              } else if (dialogCtx.mounted) {
                                ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                  const SnackBar(content: Text('주소로 좌표를 찾을 수 없습니다')),
                                );
                              }
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: const Size(0, 36),
                            ),
                            child: const Text('자동',
                                style: TextStyle(color: AppColors.mintGreen, fontSize: 13)),
                          ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: latCtrl,
                        decoration: const InputDecoration(labelText: '위도 *'),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: lngCtrl,
                        decoration: const InputDecoration(labelText: '경도 *'),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: loading
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      final lat = double.tryParse(latCtrl.text.trim());
                      final lng = double.tryParse(lngCtrl.text.trim());
                      if (name.isEmpty || lat == null || lng == null) return;
                      setSt(() => loading = true);
                      try {
                        await widget.spotsRepo.updateSpot(
                          spot.id,
                          name: name,
                          formattedAddress: addrCtrl.text.trim(),
                          lat: lat,
                          lng: lng,
                        );
                        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                        _refresh();
                      } catch (e) {
                        setSt(() => loading = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('오류: $e')),
                          );
                        }
                      }
                    },
              child: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('저장', style: TextStyle(color: AppColors.mintGreen)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSpot(BuildContext context, AdminSpot spot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('카페 삭제'),
        content: Text(
            '"${spot.name}"을(를) 삭제하시겠습니까?\n연결된 측정 데이터도 함께 삭제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.spotsRepo.deleteSpot(spot.id);
      _refresh();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('오류: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          const Text('등록된 카페 관리',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<AdminSpot>>(
              future: _future,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snap.data ?? [];
                if (list.isEmpty) {
                  return const Center(
                    child: Text('직접 등록한 카페가 없습니다.',
                        style: TextStyle(color: Colors.grey)),
                  );
                }
                return ListView.separated(
                  controller: ctrl,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: list.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final s = list[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.name,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                            if (s.formattedAddress != null &&
                                s.formattedAddress!.isNotEmpty)
                              Text(s.formattedAddress!,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600)),
                            Text(
                              '${s.lat.toStringAsFixed(5)}, ${s.lng.toStringAsFixed(5)}',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade500),
                            ),
                            Text(
                              '측정 ${s.reportCount}건 · ${s.createdAt.toLocal().toString().substring(0, 10)}',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade400),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => _deleteSpot(context, s),
                                  child: const Text('삭제',
                                      style: TextStyle(color: Colors.red)),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () => _editSpot(context, s),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.mintGreen),
                                  child: const Text('수정',
                                      style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── 카페 등록/삭제 요청 바텀시트 ─────────────────────────────────
class _CafeRequestSheet extends StatefulWidget {
  final CafeRequestsRepository repo;
  final SupabaseClient supabaseClient;
  final Future<void> Function(BadgeInfo badge) onBadgeEarned;
  const _CafeRequestSheet({
    required this.repo,
    required this.supabaseClient,
    required this.onBadgeEarned,
  });

  @override
  State<_CafeRequestSheet> createState() => _CafeRequestSheetState();
}

class _CafeRequestSheetState extends State<_CafeRequestSheet> {
  String _type = '등록';
  final _nameCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addrCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final rawNote = _noteCtrl.text.trim();
      final note = _type == '삭제'
          ? '[삭제 요청] $rawNote'.trim()
          : rawNote.isEmpty ? null : rawNote;
      final addr = _addrCtrl.text.trim();
      await widget.repo.submitRequest(
        cafeName: name,
        address: addr.isEmpty ? null : addr,
        note: note,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('요청이 접수되었습니다. 검토 후 처리될 예정입니다.')),
      );
      final badge = await BadgeService.awardInstantBadge(
        client: widget.supabaseClient,
        badgeId: 'B29',
      );
      if (badge != null && mounted) await widget.onBadgeEarned(badge);
    } catch (_) {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottom),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('카페 등록/삭제 요청', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          // 유형 선택
          Row(
            children: [
              _TypeChip(label: '등록 요청', selected: _type == '등록', onTap: () => setState(() => _type = '등록')),
              const SizedBox(width: 8),
              _TypeChip(label: '삭제 요청', selected: _type == '삭제', onTap: () => setState(() => _type = '삭제')),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: '카페 이름 *',
              hintText: _type == '등록' ? '예) 조용한카페 청주점' : '예) 폐업한 카페 이름',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _addrCtrl,
            decoration: InputDecoration(
              labelText: '주소 (선택)',
              hintText: _type == '등록' ? '예) 충북 청주시 흥덕구 ...' : '예) 폐업 카페 주소',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: _type == '등록' ? '추가 메모 (선택)' : '삭제 사유 (선택)',
              hintText: _type == '등록' ? '운영 시간, 특이사항 등' : '예) 폐업함, 이전함 등',
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mintGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('요청하기', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TypeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.mintGreen : AppColors.mintGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.mintGreen,
          ),
        ),
      ),
    );
  }
}

// ── 제안사항 바텀시트 ──────────────────────────────────────────────
class _SuggestionSheet extends StatefulWidget {
  final CafeRequestsRepository repo;
  final SupabaseClient supabaseClient;
  final Future<void> Function(BadgeInfo badge) onBadgeEarned;
  const _SuggestionSheet({
    required this.repo,
    required this.supabaseClient,
    required this.onBadgeEarned,
  });

  @override
  State<_SuggestionSheet> createState() => _SuggestionSheetState();
}

class _SuggestionSheetState extends State<_SuggestionSheet> {
  static const _kDateKey = 'suggestion_daily_date';
  static const _kCountKey = 'suggestion_daily_count';
  static const _kDailyLimit = 3;

  final _ctrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<bool> _isDailyLimitReached() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toLocal();
    final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final savedDate = prefs.getString(_kDateKey);
    if (savedDate != dateStr) {
      await prefs.setString(_kDateKey, dateStr);
      await prefs.setInt(_kCountKey, 0);
      return false;
    }
    return (prefs.getInt(_kCountKey) ?? 0) >= _kDailyLimit;
  }

  Future<void> _incrementDailyCount() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_kCountKey) ?? 0;
    await prefs.setInt(_kCountKey, count + 1);
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    if (await _isDailyLimitReached()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('오늘 제안사항 한도(3개)에 도달했습니다. 내일 다시 시도해주세요.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final moderationError = await ModerationService.validate(text);
    if (moderationError != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(moderationError), duration: const Duration(seconds: 3)),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await widget.repo.submitRequest(cafeName: '[제안]', note: text);
      await _incrementDailyCount();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제안사항이 전달되었습니다. 감사합니다!')),
      );
      final badge = await BadgeService.awardInstantBadge(
        client: widget.supabaseClient,
        badgeId: 'B29',
      );
      if (badge != null && mounted) await widget.onBadgeEarned(badge);
    } catch (_) {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottom),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('제안사항', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            '서비스 개선을 위한 의견을 자유롭게 적어주세요. (일일 3회 제한)',
            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            maxLines: 4,
            maxLength: 500,
            decoration: const InputDecoration(
              hintText: '예) 특정 기능 추가, 불편한 점, 개선 아이디어 등',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mintGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('전달하기', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 관리자: 제안사항 목록 바텀시트 ──────────────────────────────────
class _AdminSuggestionsSheet extends StatefulWidget {
  final CafeRequestsRepository repo;
  const _AdminSuggestionsSheet({required this.repo});

  @override
  State<_AdminSuggestionsSheet> createState() => _AdminSuggestionsSheetState();
}

class _AdminSuggestionsSheetState extends State<_AdminSuggestionsSheet> {
  late Future<List<CafeRequest>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repo.fetchPending();
  }

  void _refresh() => setState(() => _future = widget.repo.fetchPending());

  /// 제안사항 삭제: status를 'rejected'로 변경 (RLS DELETE 불가 → UPDATE 우회)
  Future<void> _deleteRequest(BuildContext context, String id) async {
    try {
      await widget.repo.updateStatus(id, 'rejected');
      _refresh();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, ctrl) => Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('제안사항 목록', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<CafeRequest>>(
              future: _future,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = (snap.data ?? []).where((r) => r.cafeName == '[제안]').toList();
                if (list.isEmpty) {
                  return const Center(child: Text('제안사항이 없습니다.', style: TextStyle(color: Colors.grey)));
                }
                return ListView.separated(
                  controller: ctrl,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: list.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final r = list[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.note ?? '', style: const TextStyle(fontSize: 14, height: 1.5)),
                            const SizedBox(height: 4),
                            Text(r.createdAt.toLocal().toString().substring(0, 16),
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => _deleteRequest(context, r.id),
                                  child: const Text('삭제', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
class _DangerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _DangerTile({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, size: 20, color: AppColors.dbVeryLoud),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.dbVeryLoud,
            fontWeight: FontWeight.w500,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

