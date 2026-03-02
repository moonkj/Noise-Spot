import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
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
    initialLocation: '/onboarding',
    debugLogDiagnostics: false,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final initAsync = ref.read(supabaseInitProvider);
      if (!initAsync.hasValue) return null;

      final session = ref.read(supabaseClientProvider).auth.currentSession;
      final isLoggedIn = session != null;
      final isOnboarding = state.matchedLocation == '/onboarding';

      if (isLoggedIn && isOnboarding) return '/map';
      if (!isLoggedIn && !isOnboarding) return '/onboarding';
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
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
              final spot = state.extra as SpotModel;
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
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: EdgeInsets.only(bottom: bottom),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final tab = tabs[i];
          final isActive = i == activeIndex;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: SizedBox(
                height: 60,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isActive ? tab.activeIcon : tab.icon,
                      size: 24,
                      color: isActive ? AppColors.mintGreen : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tab.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                        color: isActive ? AppColors.mintGreen : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
