import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/admin_config.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/nickname_service.dart';
import '../../auth/data/auth_repository.dart';
import '../../admin/data/cafe_requests_repository.dart';
import '../../../core/services/places_service.dart';
import '../../map/data/spots_repository.dart';
import '../../profile/data/profile_repository.dart';

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
    if (mounted) {
      setState(() {
        _micStatus = mic;
        _locationStatus = loc;
      });
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
      backgroundColor: const Color(0xFFF8F6F1),
      body: Column(
        children: [
          // ── Custom AppBar ──
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(top: top),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  onPressed: () => context.go('/profile'),
                ),
                const Expanded(
                  child: Text(
                    '설정',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
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
                // ── 계정 정보 ──────────────────────────────────────────
                _SectionHeader('계정 정보'),
                _SettingsTile(
                  icon: Icons.person_outline,
                  title: '닉네임',
                  trailing: Text(
                    nickname ?? '설정 안 됨',
                    style: TextStyle(
                      fontSize: 14,
                      color: nickname != null ? const Color(0xFF1A1A1A) : Colors.grey.shade400,
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.notifications_outlined, size: 20, color: Colors.grey.shade400),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '알림 기능은 업데이트 예정이에요',
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
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
                  subtitle: '소음 수치(dB) 측정에만 사용됩니다',
                  status: _micStatus,
                  buttonLabel: _permissionButtonLabel(_micStatus),
                  onManage: () async {
                    await openAppSettings();
                    await _checkPermissions();
                  },
                ),
                _PermissionTile(
                  icon: Icons.location_on_rounded,
                  title: '위치',
                  subtitle: '주변 카페 탐색 및 측정 위치 확인에 사용됩니다',
                  status: _locationStatus,
                  buttonLabel: _permissionButtonLabel(_locationStatus),
                  onManage: () async {
                    await openAppSettings();
                    await _checkPermissions();
                  },
                ),

                // ── 정보 ──────────────────────────────────────────────
                _SectionHeader('정보'),
                _SettingsTile(
                  icon: Icons.info_outline,
                  title: '앱 버전',
                  trailing: Text(
                    '1.0.0',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
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

                // ── 카페 추가 요청 (일반 사용자) ────────────────────────
                _SectionHeader('카페 추가 요청'),
                _SettingsTile(
                  icon: Icons.add_location_alt_outlined,
                  title: '카페 등록 요청',
                  subtitle: '앱에 없는 카페를 운영자에게 요청',
                  showArrow: true,
                  onTap: () => _showCafeRequestDialog(context),
                ),

                // ── 관리자 ─────────────────────────────────────────────
                if (_isAdmin) ...[
                  _SectionHeader('관리자'),
                  _SettingsTile(
                    icon: Icons.admin_panel_settings_outlined,
                    title: '카페 추가 요청 목록',
                    showArrow: true,
                    onTap: () => _showAdminRequestsSheet(context),
                  ),
                  _SettingsTile(
                    icon: Icons.store_outlined,
                    title: '등록된 카페 관리',
                    subtitle: '직접 등록한 카페 수정 / 삭제',
                    showArrow: true,
                    onTap: () => _showAdminSpotsSheet(context),
                  ),
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
      'https://moonkj.github.io/Noise-Spot/docs/privacy-policy.html',
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

  String _permissionButtonLabel(PermissionStatus status) {
    if (status.isGranted) return '설정에서 변경';
    return '설정에서 허용';
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

  void _showCafeRequestDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    bool submitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('카페 등록 요청'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '카페 이름 *',
                    hintText: '예) 조용한카페 청주점',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: addrCtrl,
                  decoration: const InputDecoration(
                    labelText: '주소 (선택)',
                    hintText: '예) 충북 청주시 흥덕구 ...',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: noteCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '추가 메모 (선택)',
                    hintText: '운영 시간, 특이사항 등',
                  ),
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
              onPressed: submitting
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      setSt(() => submitting = true);
                      try {
                        await ref.read(cafeRequestsRepositoryProvider).submitRequest(
                              cafeName: name,
                              address: addrCtrl.text.trim(),
                              note: noteCtrl.text.trim(),
                            );
                        if (dialogCtx.mounted) {
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('요청이 접수되었습니다. 검토 후 추가될 예정입니다.')),
                          );
                        }
                      } catch (_) {
                        setSt(() => submitting = false);
                      }
                    },
              child: const Text('요청하기', style: TextStyle(color: AppColors.mintGreen)),
            ),
          ],
        ),
      ),
    );
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
          '모든 측정 기록과 닉네임이 삭제되고\n새로운 사용자로 다시 시작됩니다.\n\n이 작업은 되돌릴 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await NicknameNotifier.resetAll();
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, size: 20, color: AppColors.textSecondary),
        title: Text(
          title,
          style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)),
        ),
        subtitle: subtitle != null
            ? Text(subtitle!, style: TextStyle(fontSize: 12, color: Colors.grey.shade500))
            : null,
        trailing: trailing ??
            (showArrow
                ? Icon(Icons.chevron_right, size: 20, color: Colors.grey.shade400)
                : null),
        onTap: onTap,
      ),
    );
  }
}


class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final PermissionStatus status;
  final String buttonLabel;
  final VoidCallback onManage;

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.buttonLabel,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final isGranted = status == PermissionStatus.granted;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, size: 20, color: AppColors.textSecondary),
        title: Text(title, style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A))),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
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
              child: Text(buttonLabel, style: const TextStyle(color: AppColors.mintGreen)),
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
          const Text('카페 추가 요청 목록', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<CafeRequest>>(
              future: _future,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snap.data ?? [];
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
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.cafeName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                            if (r.address != null && r.address!.isNotEmpty)
                              Text(r.address!, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                            if (r.note != null && r.note!.isNotEmpty)
                              Text('메모: ${r.note}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
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
                                  onPressed: () => _approveRequest(context, r),
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.mintGreen),
                                  child: const Text('승인 & 등록', style: TextStyle(color: Colors.white)),
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

