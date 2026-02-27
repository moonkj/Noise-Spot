import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/map/presentation/map_screen.dart';
import '../../features/report/presentation/report_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../services/supabase_service.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ValueNotifier<bool>(false);
  // Trigger router refresh on auth state change AND on Supabase init complete
  ref.listen(authStateProvider, (_, _) => authNotifier.value = !authNotifier.value);
  ref.listen(supabaseInitProvider, (_, _) => authNotifier.value = !authNotifier.value);

  return GoRouter(
    initialLocation: '/onboarding',
    debugLogDiagnostics: false,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      // Don't redirect until Supabase is fully initialised
      final initAsync = ref.read(supabaseInitProvider);
      if (!initAsync.hasValue) return null; // stay on /onboarding (splash)

      final session = ref.read(supabaseClientProvider).auth.currentSession;
      final isLoggedIn = session != null;
      final isOnboarding = state.matchedLocation == '/onboarding';

      if (isLoggedIn && isOnboarding) return '/map';
      // Do NOT force unauthenticated users back to onboarding —
      // anonymous sign-in may fail on a bad network, and we still
      // want to show the map (reports will be skipped without a session).
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
            path: '/profile',
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});

class _MainShell extends StatelessWidget {
  final Widget child;
  const _MainShell({required this.child});

  @override
  Widget build(BuildContext context) => child;
}
