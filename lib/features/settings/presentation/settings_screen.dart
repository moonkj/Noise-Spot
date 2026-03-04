import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/admin_config.dart';
import '../../../core/services/theme_mode_service.dart';
import '../../../core/services/admin_dummy_service.dart';
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
import '../../../core/services/suggestion_limit_service.dart';
import '../../explore/presentation/explore_screen.dart' show nearbySpotsProvider;
import '../../map/presentation/map_controller.dart' show mapControllerProvider;

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
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const _OpenSourceLicensePage(),
                    ),
                  ),
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
                    icon: Icons.people_outline_rounded,
                    title: '앱 접속 통계',
                    subtitle: '일간 · 주간 · 월간 · 누적 유저',
                    showArrow: true,
                    onTap: () => _showAdminUserStatsSheet(context),
                  ),
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
                    title: '전체 카페 관리',
                    subtitle: '모든 카페 검색·수정·삭제',
                    showArrow: true,
                    onTap: () => _showAdminSpotsSheet(context),
                  ),
                  _SettingsTile(
                    icon: Icons.add_business_outlined,
                    title: '카페 신규 등록',
                    subtitle: '이름·주소·좌표로 임의 위치 카페 등록',
                    showArrow: true,
                    onTap: () => _showAdminCafeRegisterSheet(context),
                  ),
                  _SettingsTile(
                    icon: Icons.add_photo_alternate_outlined,
                    title: '카페 사진 관리',
                    subtitle: '사진 자동 조회 · 직접 등록',
                    showArrow: true,
                    onTap: () => _showAdminPhotoSheet(context),
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
                  icon: Icons.delete_forever_rounded,
                  title: '계정 삭제',
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

  void _editNickname(BuildContext context, String? current) {
    final controller = TextEditingController(text: current ?? '');
    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          var isSaving = false;

          Future<void> doSave() async {
            final trimmed = controller.text.trim();
            if (trimmed.length < 2) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('2자 이상 입력해 주세요')),
              );
              return;
            }
            if (!RegExp(r'^[가-힣a-zA-Z0-9]+$').hasMatch(trimmed)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('한글, 영문, 숫자만 사용 가능해요')),
              );
              return;
            }
            setDialogState(() => isSaving = true);
            try {
              // 서버 먼저 저장 (실패 시 다이얼로그 유지)
              await ref.read(profileRepositoryProvider).upsertNickname(trimmed);
              // 성공 후 로컬 반영
              await ref.read(nicknameProvider.notifier).set(trimmed);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('닉네임이 저장되었습니다')),
                );
              }
            } catch (e) {
              setDialogState(() => isSaving = false);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('저장 실패. 네트워크를 확인해 주세요.')),
                );
              }
            }
          }

          return AlertDialog(
            title: const Text('닉네임 설정'),
            content: TextField(
              controller: controller,
              maxLength: 10,
              autofocus: true,
              enabled: !isSaving,
              decoration: const InputDecoration(
                hintText: '2~10자 (한글, 영문, 숫자)',
                counterText: '',
              ),
              onSubmitted: (_) => doSave(),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: isSaving ? null : doSave,
                child: isSaving
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.mintGreen),
                      )
                    : const Text('저장',
                        style: TextStyle(color: AppColors.mintGreen)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPrivacyNotice(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _LegalDocPage(type: _LegalDocType.privacy)),
    );
  }

  void _showTermsNotice(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _LegalDocPage(type: _LegalDocType.terms)),
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

  void _showAdminCafeRegisterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AdminCafeRegisterSheet(
        spotsRepo: ref.read(spotsRepositoryProvider),
        placesService: ref.read(placesServiceProvider),
      ),
    );
  }

  void _showAdminUserStatsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AdminUserStatsSheet(
        supabase: ref.read(supabaseClientProvider),
      ),
    );
  }

  void _showAdminPhotoSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AdminPhotoSheet(
        spotsRepo: ref.read(spotsRepositoryProvider),
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
        title: const Text('계정 삭제'),
        content: const Text(
          '계정을 삭제하면 모든 측정 기록, 뱃지, 닉네임이 삭제되고\n새로운 사용자로 다시 시작됩니다.\n\n이 작업은 되돌릴 수 없습니다.',
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
            child: const Text('삭제', style: TextStyle(color: AppColors.dbVeryLoud)),
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

// ── 관리자: 카페 사진 관리 바텀시트 ──────────────────────────────────
class _AdminPhotoSheet extends StatefulWidget {
  final SpotsRepository spotsRepo;
  const _AdminPhotoSheet({required this.spotsRepo});

  @override
  State<_AdminPhotoSheet> createState() => _AdminPhotoSheetState();
}

class _AdminPhotoSheetState extends State<_AdminPhotoSheet> {
  final _sheetCtrl = DraggableScrollableController();
  final _searchCtrl = TextEditingController();
  final _picker = ImagePicker();
  final Map<String, bool> _uploading = {};

  List<PhotoAdminSpot> _allSpots = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _sheetCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final spots = await widget.spotsRepo.fetchSpotsForPhotoAdmin();
      if (mounted) setState(() { _allSpots = spots; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<PhotoAdminSpot> get _filtered => _query.isEmpty
      ? _allSpots
      : _allSpots.where((s) => s.name.toLowerCase().contains(_query)).toList();

  Future<void> _uploadPhoto(BuildContext context, PhotoAdminSpot spot) async {
    final messenger = ScaffoldMessenger.of(context);
    final xfile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (xfile == null || !mounted) return;

    setState(() => _uploading[spot.id] = true);
    try {
      final bytes = await xfile.readAsBytes();
      await widget.spotsRepo.uploadSpotPhoto(spot.id, bytes, xfile.name);
      await _load();
      if (mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('사진이 등록되었습니다')));
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('업로드 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading.remove(spot.id));
    }
  }

  Future<void> _deletePhoto(BuildContext context, PhotoAdminSpot spot) async {
    // 삭제 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('사진 삭제'),
        content: Text('"${spot.name}"의 사진을 삭제하시겠습니까?'),
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
    if (confirmed != true || !context.mounted) return;

    try {
      await widget.spotsRepo.deleteSpotPhoto(spot.id, spot.photoUrl);
      await _load();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('사진이 삭제되었습니다')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      controller: _sheetCtrl,
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 14),
          const Text('카페 사진 관리',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'JPG · PNG · WebP  |  최대 5MB  |  1200px 이하 권장',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: '카페 이름으로 검색',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              onChanged: (v) =>
                  setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Text(
                          _query.isEmpty ? '스팟이 없습니다.' : '검색 결과가 없습니다.',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        itemCount: _filtered.length,
                        separatorBuilder: (ctx, i) =>
                            const SizedBox(height: 6),
                        itemBuilder: (_, i) {
                          final s = _filtered[i];
                          final busy = _uploading[s.id] == true;
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(s.name,
                                                style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight:
                                                        FontWeight.w700)),
                                            if (s.formattedAddress !=
                                                    null &&
                                                s.formattedAddress!
                                                    .isNotEmpty)
                                              Text(s.formattedAddress!,
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors
                                                          .grey.shade600)),
                                            const SizedBox(height: 2),
                                            Row(children: [
                                              Icon(
                                                s.photoUrl != null
                                                    ? Icons
                                                        .check_circle_rounded
                                                    : Icons.cancel_rounded,
                                                size: 13,
                                                color: s.photoUrl != null
                                                    ? Colors.green
                                                    : Colors.grey.shade400,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                s.photoUrl != null
                                                    ? '사진 있음'
                                                    : '사진 없음',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: s.photoUrl != null
                                                      ? Colors.green
                                                      : Colors
                                                          .grey.shade400,
                                                ),
                                              ),
                                            ]),
                                          ],
                                        ),
                                      ),
                                      if (s.photoUrl != null)
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          child: Image.network(
                                            s.photoUrl!,
                                            width: 56,
                                            height: 56,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stack) =>
                                                    const SizedBox(),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.end,
                                    children: [
                                      if (s.photoUrl != null)
                                        TextButton(
                                          onPressed: busy
                                              ? null
                                              : () => _deletePhoto(
                                                  context, s),
                                          child: const Text('삭제',
                                              style: TextStyle(
                                                  color: Colors.red,
                                                  fontSize: 12)),
                                        ),
                                      const SizedBox(width: 4),
                                      ElevatedButton.icon(
                                        onPressed: busy
                                            ? null
                                            : () =>
                                                _uploadPhoto(context, s),
                                        icon: busy
                                            ? const SizedBox(
                                                width: 13,
                                                height: 13,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color:
                                                            Colors.white))
                                            : const Icon(
                                                Icons.upload_rounded,
                                                size: 14),
                                        label: Text(
                                            busy ? '업로드 중…' : '사진 업로드',
                                            style: const TextStyle(
                                                fontSize: 12)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppColors.mintGreen,
                                          foregroundColor: Colors.white,
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 6),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize
                                              .shrinkWrap,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
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
class _AdminSpotsSheet extends ConsumerStatefulWidget {
  final SpotsRepository spotsRepo;
  final PlacesService placesService;
  const _AdminSpotsSheet({required this.spotsRepo, required this.placesService});

  @override
  ConsumerState<_AdminSpotsSheet> createState() => _AdminSpotsSheetState();
}

class _AdminSpotsSheetState extends ConsumerState<_AdminSpotsSheet> {
  late Future<List<AdminSpot>> _future;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = widget.spotsRepo.fetchAllSpots();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _refresh() => setState(
        () => _future = widget.spotsRepo.fetchAllSpots(
          query: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        ),
      );

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
                      // 2차 확인
                      final ok = await showDialog<bool>(
                        context: dialogCtx,
                        builder: (c2) => AlertDialog(
                          title: const Text('수정 확인'),
                          content: Text('"$name" 정보를 저장하시겠습니까?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c2, false),
                              child: const Text('취소'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(c2, true),
                              child: const Text('저장',
                                  style: TextStyle(color: AppColors.mintGreen)),
                            ),
                          ],
                        ),
                      );
                      if (ok != true) return;
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
    // 1차 확인
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
    // 2차 확인
    if (!context.mounted) return;
    final doubleConfirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('정말 삭제하시겠습니까?'),
        content: Text('${spot.reportCount}건의 측정 데이터가 영구 삭제됩니다.\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('영구 삭제',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (doubleConfirmed != true) return;
    try {
      await widget.spotsRepo.deleteSpot(spot.id);
      // 탐색 탭 + 지도 즉시 갱신
      ref.invalidate(nearbySpotsProvider);
      ref.read(mapControllerProvider.notifier).reloadSpots();
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
          const Text('전체 카페 관리',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: '카페 이름 검색',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              onChanged: (_) => _refresh(),
            ),
          ),
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
                    child: Text('검색 결과가 없습니다.',
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

// ── 관리자: 카페 신규 등록 바텀시트 ───────────────────────────────
class _AdminCafeRegisterSheet extends StatefulWidget {
  final SpotsRepository spotsRepo;
  final PlacesService placesService;
  const _AdminCafeRegisterSheet(
      {required this.spotsRepo, required this.placesService});

  @override
  State<_AdminCafeRegisterSheet> createState() =>
      _AdminCafeRegisterSheetState();
}

class _AdminCafeRegisterSheetState extends State<_AdminCafeRegisterSheet> {
  final _nameCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  bool _loading = false;
  bool _geocoding = false;
  bool _locating = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addrCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final pos = await LocationService.getCurrentPosition();
      _latCtrl.text = pos.latitude.toStringAsFixed(6);
      _lngCtrl.text = pos.longitude.toStringAsFixed(6);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('위치 오류: $e')));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _geocodeAddr() async {
    final addr = _addrCtrl.text.trim();
    if (addr.isEmpty) return;
    setState(() => _geocoding = true);
    final result = await widget.placesService.geocodeAddress(addr);
    setState(() => _geocoding = false);
    if (result != null) {
      _latCtrl.text = result.lat.toStringAsFixed(6);
      _lngCtrl.text = result.lng.toStringAsFixed(6);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('주소로 좌표를 찾을 수 없습니다')),
      );
    }
  }

  Future<void> _register() async {
    final name = _nameCtrl.text.trim();
    final lat = double.tryParse(_latCtrl.text.trim());
    final lng = double.tryParse(_lngCtrl.text.trim());
    if (name.isEmpty || lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이름, 위도, 경도는 필수입니다')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await widget.spotsRepo.createSpot(
        name: name,
        googlePlaceId: null,
        lat: lat,
        lng: lng,
        formattedAddress:
            _addrCtrl.text.trim().isEmpty ? null : _addrCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('카페가 등록되었습니다')),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('등록 실패: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
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
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text('카페 신규 등록',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: '카페 이름 *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addrCtrl,
                    decoration: const InputDecoration(
                      labelText: '주소',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _geocoding
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : TextButton(
                        onPressed: _geocodeAddr,
                        child: const Text('자동',
                            style: TextStyle(
                                color: AppColors.mintGreen, fontSize: 13)),
                      ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latCtrl,
                    decoration: const InputDecoration(
                      labelText: '위도 *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _lngCtrl,
                    decoration: const InputDecoration(
                      labelText: '경도 *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _locating ? null : _useCurrentLocation,
              icon: _locating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location, size: 18,
                      color: AppColors.mintGreen),
              label: const Text('현재 위치 사용',
                  style: TextStyle(color: AppColors.mintGreen)),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mintGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('등록',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
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
  final _ctrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    if (await SuggestionLimitService.isLimitReached()) {
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
      await SuggestionLimitService.increment();
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


// ── 관리자: 앱 접속 통계 바텀시트 ────────────────────────────────────
class _AdminUserStatsSheet extends StatefulWidget {
  final SupabaseClient supabase;
  const _AdminUserStatsSheet({required this.supabase});

  @override
  State<_AdminUserStatsSheet> createState() => _AdminUserStatsSheetState();
}

class _AdminUserStatsSheetState extends State<_AdminUserStatsSheet> {
  Map<String, int>? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await widget.supabase.rpc('get_admin_user_stats');
      final row = (res as List?)?.firstOrNull as Map<String, dynamic>?;
      if (row != null) {
        setState(() {
          _stats = {
            'dau': row['dau'] as int? ?? 0,
            'wau': row['wau'] as int? ?? 0,
            'mau': row['mau'] as int? ?? 0,
            'total': row['total'] as int? ?? 0,
          };
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
          _error = '데이터를 불러오지 못했습니다';
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final dateStr =
        '${today.year}.${today.month.toString().padLeft(2, '0')}.${today.day.toString().padLeft(2, '0')} 기준';

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.7,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // 핸들
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // 헤더
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
                child: Row(
                  children: [
                    const Icon(Icons.people_outline_rounded, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '앱 접속 통계',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      onPressed: _loading ? null : _load,
                      tooltip: '새로고침',
                    ),
                  ],
                ),
              ),
              Text(
                dateStr,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.45),
                ),
              ),
              const SizedBox(height: 16),
              // 내용
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Text(
                              _error!,
                              style: const TextStyle(fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            child: GridView.count(
                              controller: scrollCtrl,
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.4,
                              children: [
                                _StatCard(
                                  label: '오늘 접속',
                                  sublabel: '일간 DAU',
                                  value: _stats!['dau']!,
                                  color: AppColors.mintGreen,
                                ),
                                _StatCard(
                                  label: '이번 주',
                                  sublabel: '7일 WAU',
                                  value: _stats!['wau']!,
                                  color: AppColors.skyBlue,
                                ),
                                _StatCard(
                                  label: '이번 달',
                                  sublabel: '30일 MAU',
                                  value: _stats!['mau']!,
                                  color: const Color(0xFF9B8BF4),
                                ),
                                _StatCard(
                                  label: '누적 유저',
                                  sublabel: '전체 기간',
                                  value: _stats!['total']!,
                                  color: const Color(0xFFFF9966),
                                ),
                              ],
                            ),
                          ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String sublabel;
  final int value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.sublabel,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
              ),
              Text(
                sublabel,
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1,
                ),
              ),
              const SizedBox(width: 3),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '명',
                  style: TextStyle(
                    fontSize: 13,
                    color: color.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 법적 문서 인앱 페이지 (개인정보 처리방침 / 이용약관)
// ══════════════════════════════════════════════════════════════

enum _LegalDocType { privacy, terms }

class _LegalDocPage extends StatelessWidget {
  final _LegalDocType type;
  const _LegalDocPage({required this.type});

  @override
  Widget build(BuildContext context) {
    final isPrivacy = type == _LegalDocType.privacy;
    return Scaffold(
      appBar: AppBar(
        title: Text(isPrivacy ? '개인정보 처리방침' : '이용약관'),
        backgroundColor: AppColors.mintGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: isPrivacy ? _buildPrivacy(context) : _buildTerms(context),
      ),
    );
  }

  Widget _buildPrivacy(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _legalHeader('Cafe Vibe 개인정보처리방침', '카페의 dB 바이브를 공유하는 커뮤니티', '시행일: 2026년 3월 4일'),
        _section(context, '1. 개요', [
          '카페 바이브(이하 "앱")는 카페의 dB 수준과 분위기를 기록·공유하는 iOS 앱입니다.',
          '본 방침은 앱이 수집하는 정보, 사용 목적, 보관 기간 및 사용자 권리를 설명합니다.',
        ]),
        _section(context, '2. 수집하는 정보', null, bullets: [
          'dB 수치 — 마이크로 측정한 데시벨 숫자만 저장됩니다. 음성 파일은 절대 저장되지 않습니다.',
          '위치 정보 — 앱 사용 중(When In Use)에만 현재 위치를 수집합니다.',
          '소셜 로그인 계정 정보 — Apple 또는 Google 계정으로 로그인 시 이름과 이메일 주소가 수집됩니다. (Apple 로그인은 이메일 숨기기 옵션을 지원합니다.)',
          '닉네임 — 사용자가 직접 설정한 닉네임이 저장됩니다.',
          '스티커 선택값 — 딥포커스 / 소셜버즈 / 소프트바이브 중 선택한 항목이 저장됩니다.',
          '즐겨찾기(북마크) — 사용자가 저장한 카페 목록이 서버에 저장됩니다.',
          '뱃지·레벨 데이터 — 측정 횟수를 기반으로 자동 산출되는 활동 지표입니다.',
        ]),
        _highlight(context, '음성 녹음 파일은 절대 저장·전송되지 않습니다.\n마이크는 데시벨 수치 추출 즉시 데이터를 휘발 처리합니다.'),
        _section(context, '3. 수집하지 않는 정보', null, bullets: [
          '음성 녹음 파일 또는 오디오 스트림',
          '연락처, 기기 사진첩, 기타 민감 정보',
          '광고 식별자(IDFA) — 앱 추적 투명성(ATT) 허용 시에도 광고 목적으로 사용하지 않습니다.',
        ]),
        _section(context, '4. 앱 추적 투명성(ATT)', [
          'iOS 14.5 이상에서 앱 최초 실행 시 "앱 추적 투명성" 권한을 요청합니다.',
          '이 권한은 광고 목적이 아닌 서비스 품질 개선(충돌 분석 등)을 위해 요청됩니다.',
          '허용하지 않아도 앱의 모든 기능을 정상적으로 이용할 수 있습니다.',
        ]),
        _section(context, '5. 정보 이용 목적', null, bullets: [
          '주변 스팟의 dB 평균 데이터 산출 및 지도 표시',
          '사용자별 리포팅 기록 및 통계 제공',
          '신뢰도 등급(Trust Score) 계산',
          '닉네임·뱃지 기반 커뮤니티 활동 지원',
        ]),
        _section(context, '6. 제3자 제공', [
          '수집된 정보는 원칙적으로 제3자에게 제공되지 않습니다. 단, 서비스 운영에 필요한 아래 제3자 서비스를 이용합니다.',
        ], bullets: [
          'Supabase — 데이터베이스 및 인증 (AWS ap-northeast-2 서울 리전)',
          'Apple (Sign in with Apple) — 소셜 로그인 인증',
          'Google (Sign in with Google) — 소셜 로그인 인증',
          'Google Maps Platform — 지도 표시 및 장소 검색 (위치 정보 전송)',
        ]),
        _section(context, '7. 보관 기간', null, bullets: [
          'dB 리포트 데이터: 마지막 활동일로부터 30일 이후 지도에서 비표시',
          '계정 삭제 시: 모든 리포트·북마크·닉네임·뱃지 데이터 즉시 삭제',
          '위치 정보: 앱 세션 종료 시 미저장',
        ]),
        _section(context, '8. 사용자 권리', null, bullets: [
          '데이터 열람 — 앱 내 마이페이지에서 본인의 측정 기록 확인 가능',
          '데이터 삭제 — 앱 설정 → "계정 삭제"로 모든 데이터 즉시 삭제',
          '위치 권한 철회 — 기기 설정에서 위치 권한 언제든지 거부 가능',
          '마이크 권한 철회 — 기기 설정에서 마이크 권한 언제든지 거부 가능',
        ]),
        _section(context, '9. 어린이 개인정보 보호', [
          '본 앱은 만 14세 미만 아동을 대상으로 하지 않습니다.',
          '만 14세 미만은 보호자의 동의 없이 앱을 사용하지 않도록 안내합니다.',
        ]),
        _section(context, '10. 방침 변경', [
          '본 방침이 변경될 경우 앱 업데이트 또는 공지사항을 통해 사전 안내합니다.',
          '변경 방침은 공지일로부터 7일 후 적용됩니다.',
        ]),
        _contactBox(context),
      ],
    );
  }

  Widget _buildTerms(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _legalHeader('Cafe Vibe 이용약관', '카페의 dB 바이브를 공유하는 커뮤니티', '시행일: 2026년 3월 4일'),
        _section(context, '제1조 (목적 및 로그인)', [
          '본 약관은 Cafe Vibe(이하 "서비스")가 제공하는 카페 dB 측정 및 공유 서비스의 이용 조건과 절차, 이용자와 서비스 간의 권리·의무 및 책임사항을 규정함을 목적으로 합니다.',
          '서비스는 Apple 또는 Google 소셜 로그인을 통해 이용할 수 있습니다. 소셜 로그인 계정 정보(이름, 이메일)는 서비스 이용을 위한 식별 목적으로만 사용됩니다.',
        ]),
        _section(context, '제2조 (서비스의 내용)', null, bullets: [
          '카페 내 dB 측정 및 기록',
          '측정 데이터 기반 주변 카페 dB 지도 제공',
          '카페 분위기 스티커(딥포커스·소셜버즈·소프트바이브) 태그 공유',
          '즐겨찾기(북마크) 기능으로 카페 저장 및 관리',
          '닉네임 설정 및 사용자 프로필 관리',
          '사용자 레벨·뱃지 시스템을 통한 커뮤니티 참여',
        ]),
        _section(context, '제3조 (이용 자격 및 의무)', [
          '서비스는 만 14세 이상 이용 가능합니다. 만 14세 미만은 보호자의 동의 없이 서비스를 이용할 수 없습니다.',
        ], bullets: [
          '실제 방문한 카페에서만 dB를 측정해야 합니다.',
          '허위 데이터 등록, 어뷰징, 서비스 방해 행위는 금지됩니다.',
          '타인을 비방하거나 혐오·차별적 표현을 포함한 닉네임 사용은 금지됩니다.',
          '타인의 개인정보 또는 저작권을 침해하는 행위는 금지됩니다.',
          '관련 법령을 준수하며 서비스를 이용해야 합니다.',
        ]),
        _highlight(context, '허위 측정 데이터 등록 또는 부적절한 닉네임 사용 등 서비스 어뷰징 행위가 확인되면 사전 경고 없이 이용이 제한될 수 있습니다.'),
        _section(context, '제4조 (콘텐츠 및 데이터 권리)', [
          '사용자가 등록한 dB 측정 데이터(스티커 포함)는 서비스 개선 및 공익 목적(dB 지도 제공)을 위해 익명화된 형태로 활용될 수 있습니다.',
          '측정 데이터는 공개 통계에 포함될 수 있으나, 개인 식별 정보와 연결되지 않습니다.',
        ]),
        _section(context, '제5조 (서비스 변경 및 종료)', [
          '서비스는 사전 공지 후 내용을 변경하거나 종료할 수 있습니다.',
          '불가피한 사정이 있는 경우 사전 공지 없이 서비스가 변경 또는 종료될 수 있으며, 이로 인한 손해에 대해 서비스는 책임을 지지 않습니다.',
        ]),
        _section(context, '제6조 (면책사항)', null, bullets: [
          '서비스는 사용자가 제공한 측정 데이터의 정확성을 보증하지 않습니다.',
          '천재지변, 네트워크 장애 등 불가항력으로 인한 서비스 중단에 대해 책임지지 않습니다.',
          '서비스 이용으로 발생하는 손해에 대해 고의·중과실이 없는 한 책임지지 않습니다.',
        ]),
        _section(context, '제7조 (계정 삭제)', [
          '사용자는 앱 설정 → "계정 삭제"를 통해 언제든지 서비스 이용을 종료하고 모든 데이터를 삭제할 수 있습니다.',
          '계정 삭제 시 소셜 로그인 연결이 해제되며, 측정 기록·북마크·닉네임·뱃지 데이터가 즉시 삭제됩니다.',
          '삭제된 데이터는 복구되지 않습니다.',
        ]),
        _section(context, '제8조 (약관의 변경)', [
          '서비스는 필요한 경우 본 약관을 변경할 수 있습니다.',
          '약관이 변경되는 경우 앱 업데이트 또는 공지사항을 통해 사전 안내하며, 변경 약관은 공지일로부터 7일 후 적용됩니다.',
        ]),
        _contactBox(context),
      ],
    );
  }

  Widget _legalHeader(String title, String subtitle, String date) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.mintGreen, Color(0xFF78C5E8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(fontSize: 13, color: Colors.white70)),
          const SizedBox(height: 8),
          Text(date,
              style: const TextStyle(fontSize: 12, color: Colors.white60)),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<String>? paragraphs, {List<String>? bullets}) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final bodyStyle = TextStyle(fontSize: 14, color: onSurface.withValues(alpha: 0.8), height: 1.6);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: onSurface)),
          const SizedBox(height: 4),
          Container(height: 2, width: 40, color: AppColors.mintGreen),
          const SizedBox(height: 10),
          if (paragraphs != null)
            ...paragraphs.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(p, style: bodyStyle),
                )),
          if (bullets != null)
            ...bullets.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 6, left: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontSize: 14, color: AppColors.mintGreen, fontWeight: FontWeight.w700)),
                      Expanded(child: Text(b, style: bodyStyle)),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Widget _highlight(BuildContext context, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.mintGreen.withValues(alpha: 0.15)
            : const Color(0xFFE8F8F3),
        borderRadius: BorderRadius.circular(8),
        border: const Border(left: BorderSide(color: AppColors.mintGreen, width: 4)),
      ),
      child: Text(text,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.mintGreen : const Color(0xFF2A6048),
            fontWeight: FontWeight.w600,
            height: 1.6,
          )),
    );
  }

  Widget _contactBox(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final surfaceVariant = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('문의', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: onSurface)),
          const SizedBox(height: 8),
          Text('개발자: KJMoon', style: TextStyle(fontSize: 14, color: onSurface.withValues(alpha: 0.8))),
          const SizedBox(height: 2),
          Text('이메일: kjmoon@cafevibe.app', style: TextStyle(fontSize: 14, color: onSurface.withValues(alpha: 0.8))),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 오픈소스 라이선스 커스텀 페이지
// ══════════════════════════════════════════════════════════════

class _OpenSourceLicensePage extends StatelessWidget {
  const _OpenSourceLicensePage();

  static const _packages = [
    _PkgInfo('flutter_riverpod', '상태 관리', 'MIT'),
    _PkgInfo('go_router', '라우팅 / 네비게이션', 'BSD-3-Clause'),
    _PkgInfo('supabase_flutter', '백엔드 / 인증 / DB', 'MIT'),
    _PkgInfo('google_maps_flutter', '지도 표시', 'BSD-3-Clause'),
    _PkgInfo('geolocator', '위치 서비스', 'MIT'),
    _PkgInfo('noise_meter', '소음 측정 (dB)', 'MIT'),
    _PkgInfo('permission_handler', '권한 관리', 'MIT'),
    _PkgInfo('shared_preferences', '로컬 데이터 저장', 'BSD-3-Clause'),
    _PkgInfo('flutter_secure_storage', '보안 키체인 저장소', 'BSD-3-Clause'),
    _PkgInfo('sign_in_with_apple', 'Apple 로그인', 'MIT'),
    _PkgInfo('google_fonts', '폰트', 'Apache 2.0'),
    _PkgInfo('flutter_animate', 'UI 애니메이션', 'MIT'),
    _PkgInfo('share_plus', '공유 기능', 'BSD-3-Clause'),
    _PkgInfo('url_launcher', 'URL 열기', 'BSD-3-Clause'),
    _PkgInfo('image_picker', '이미지 선택', 'Apache 2.0'),
    _PkgInfo('in_app_review', '앱 리뷰 요청', 'MIT'),
    _PkgInfo('app_tracking_transparency', 'ATT 권한', 'MIT'),
    _PkgInfo('freezed', '데이터 클래스 생성', 'MIT'),
    _PkgInfo('http', 'HTTP 클라이언트', 'BSD-3-Clause'),
    _PkgInfo('crypto', '암호화 유틸리티', 'BSD-3-Clause'),
    _PkgInfo('rxdart', '리액티브 스트림', 'Apache 2.0'),
  ];

  static const _licenseColors = {
    'MIT': Color(0xFF2E7D32),
    'BSD-3-Clause': Color(0xFF1565C0),
    'Apache 2.0': Color(0xFFE65100),
  };

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final surfaceVariant = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Scaffold(
      appBar: AppBar(
        title: const Text('오픈소스 라이선스'),
        backgroundColor: AppColors.mintGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.mintGreen.withValues(alpha: 0.08),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Text(
              'Cafe Vibe는 아래 오픈소스 패키지를 사용하며,\n각 패키지의 라이선스를 준수합니다.',
              style: TextStyle(fontSize: 13, color: onSurface.withValues(alpha: 0.75), height: 1.5),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _packages.length,
              separatorBuilder: (context, index) => const Divider(height: 1, indent: 20, endIndent: 20),
              itemBuilder: (context, i) {
                final pkg = _packages[i];
                final badgeColor = _licenseColors[pkg.license] ?? const Color(0xFF555555);
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  title: Text(pkg.name,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: onSurface)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(pkg.description,
                        style: TextStyle(fontSize: 13, color: onSurface.withValues(alpha: 0.65))),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
                    ),
                    child: Text(pkg.license,
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600, color: badgeColor)),
                  ),
                );
              },
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            color: surfaceVariant,
            child: Text(
              '© 2026 Cafe Vibe. All rights reserved.',
              style: TextStyle(fontSize: 12, color: onSurface.withValues(alpha: 0.45)),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _PkgInfo {
  final String name;
  final String description;
  final String license;
  const _PkgInfo(this.name, this.description, this.license);
}
