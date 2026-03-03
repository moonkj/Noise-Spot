import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/nickname_screen.dart';
import '../../features/auth/presentation/email_auth_screen.dart';
import '../../features/map/presentation/map_screen.dart';
import '../../features/explore/presentation/explore_screen.dart';
import '../../features/ranking/presentation/ranking_screen.dart';
import '../../features/report/presentation/report_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/explore/presentation/spot_detail_screen.dart';
import '../../features/map/domain/spot_model.dart';
import '../services/supabase_service.dart';
import '../constants/app_colors.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ValueNotifier<bool>(false);
  ref.listen(authStateProvider, (_, _) => authNotifier.value = !authNotifier.value);
  ref.listen(supabaseInitProvider, (_, _) => authNotifier.value = !authNotifier.value);

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final initAsync = ref.read(supabaseInitProvider);
      if (!initAsync.hasValue) return null; // Supabase 초기화 대기

      final session = ref.read(supabaseClientProvider).auth.currentSession;
      final isLoggedIn = session != null;
      final loc = state.matchedLocation;
      final isSplash    = loc == '/splash';
      final isOnboarding = loc == '/onboarding';
      final isEmailAuth  = loc == '/email-auth';

      if (!isLoggedIn) {
        // 미로그인: 스플래시/일반 → 온보딩으로 즉시 이동
        if (isSplash || (!isOnboarding && !isEmailAuth)) return '/onboarding';
        return null;
      }

      // 로그인 상태
      // 온보딩/이메일 화면에서 로그인 완료 → 닉네임 설정 없이 바로 맵
      if (isOnboarding || isEmailAuth) return '/map';
      // 스플래시: 2초 후 SplashScreen 자체가 /map 으로 이동
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/nickname',
        name: 'nickname',
        builder: (context, state) => const NicknameScreen(),
      ),
      GoRoute(
        path: '/email-auth',
        name: 'email-auth',
        builder: (context, state) => const EmailAuthScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => _MainShell(child: child),
        routes: [
          GoRoute(
            path: '/map',
            name: 'map',
            builder: (context, state) => const MapScreen(),
          ),
          GoRoute(
            path: '/explore',
            name: 'explore',
            builder: (context, state) => const ExploreScreen(),
          ),
          GoRoute(
            path: '/ranking',
            name: 'ranking',
            builder: (context, state) => const RankingScreen(),
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          // Sub-routes (no bottom nav)
          GoRoute(
            path: '/report',
            name: 'report',
            builder: (context, state) {
              final spotId = state.uri.queryParameters['spotId'];
              final spotName = state.uri.queryParameters['spotName'] ?? '';
              final placeId = state.uri.queryParameters['placeId'];
              final lat = double.tryParse(state.uri.queryParameters['lat'] ?? '');
              final lng = double.tryParse(state.uri.queryParameters['lng'] ?? '');
              return ReportScreen(
                spotId: spotId,
                spotName: spotName,
                placeId: placeId,
                lat: lat,
                lng: lng,
              );
            },
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/spot/:id',
            name: 'spot',
            builder: (context, state) {
              final spot = state.extra;
              if (spot is! SpotModel) {
                // extra 없이 직접 진입 시 안전하게 처리
                return Scaffold(
                  appBar: AppBar(),
                  body: const Center(child: Text('카페 정보를 불러올 수 없습니다.')),
                );
              }
              return SpotDetailScreen(spot: spot);
            },
          ),
        ],
      ),
    ],
  );
});

// ──────────────────────────────────────────────────────────────
// Main Shell — 4탭 하단 네비게이션 바
// ──────────────────────────────────────────────────────────────
class _MainShell extends StatelessWidget {
  final Widget child;
  const _MainShell({required this.child});

  static const _tabs = [
    _TabItem(path: '/map',     icon: Icons.map_outlined,         activeIcon: Icons.map,         label: '지도'),
    _TabItem(path: '/explore', icon: Icons.grid_view_outlined,   activeIcon: Icons.grid_view,   label: '탐색'),
    _TabItem(path: '/ranking', icon: Icons.bar_chart_outlined,   activeIcon: Icons.bar_chart,   label: '랭킹'),
    _TabItem(path: '/profile', icon: Icons.person_outline,       activeIcon: Icons.person,      label: '프로필'),
  ];

  // 서브 라우트에서는 바텀 네비 숨김
  static bool _showNav(String location) {
    return ['/map', '/explore', '/ranking', '/profile'].any(
      (p) => location == p || location.startsWith('$p?'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (!_showNav(location)) return child;

    final currentIndex = _tabs.indexWhere(
      (t) => location == t.path || location.startsWith('${t.path}?'),
    );
    final activeIndex = currentIndex < 0 ? 0 : currentIndex;

    return Scaffold(
      body: child,
      bottomNavigationBar: _BottomNav(
        activeIndex: activeIndex,
        tabs: _tabs,
        onTap: (i) => context.go(_tabs[i].path),
      ),
    );
  }
}

class _TabItem {
  final String path;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _TabItem({
    required this.path,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _BottomNav extends StatelessWidget {
  final int activeIndex;
  final List<_TabItem> tabs;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.activeIndex, required this.tabs, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      padding: EdgeInsets.only(bottom: bottom),
      child: Row(
        children: List.generate(tabs.length, (i) => Expanded(
          child: _AnimatedTabButton(
            tab: tabs[i],
            isActive: i == activeIndex,
            onTap: () => onTap(i),
          ),
        )),
      ),
    );
  }
}

class _AnimatedTabButton extends StatefulWidget {
  final _TabItem tab;
  final bool isActive;
  final VoidCallback onTap;
  const _AnimatedTabButton({required this.tab, required this.isActive, required this.onTap});

  @override
  State<_AnimatedTabButton> createState() => _AnimatedTabButtonState();
}

class _AnimatedTabButtonState extends State<_AnimatedTabButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.82).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isActive;
    final activeColor = AppColors.mintGreen;
    final inactiveColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(scale: _scale.value, child: child),
        child: SizedBox(
          height: 60,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                child: Icon(
                  key: ValueKey(isActive),
                  isActive ? widget.tab.activeIcon : widget.tab.icon,
                  size: 24,
                  color: isActive ? activeColor : inactiveColor,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? activeColor : inactiveColor,
                ),
                child: Text(widget.tab.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
