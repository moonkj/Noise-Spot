import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Supabase credentials (same values as main.dart dart-define defaults)
const _kSupabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://rqlfyumzmpmhupjtroid.supabase.co',
);
const _kSupabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue:
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJxbGZ5dW16bXBtaHVwanRyb2lkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIxMzY4MjIsImV4cCI6MjA4NzcxMjgyMn0.PiivIIa-mjgOTLOH_suaAyllGQZRb8p-cYLi5gHpPXk',
);

class SupabaseService {
  SupabaseService._();
  static SupabaseClient get client => Supabase.instance.client;
}

/// Initialises Supabase asynchronously.
/// Uses a 10-second timeout so a hung token-refresh never blocks the app.
/// If init fails/times out, the app still launches (user will be signed out).
final supabaseInitProvider = FutureProvider<void>((ref) async {
  try {
    await Supabase.initialize(
      url: _kSupabaseUrl,
      anonKey: _kSupabaseAnonKey,
      // Disable persisted session so an expired OAuth token can't cause a
      // blocking network call during startup on iOS 26 beta.
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        localStorage: EmptyLocalStorage(),
      ),
    ).timeout(const Duration(seconds: 10));
  } catch (_) {
    // Initialise without any stored session as a fallback
    try {
      await Supabase.initialize(
        url: _kSupabaseUrl,
        anonKey: _kSupabaseAnonKey,
      ).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }
});

/// Riverpod provider for the Supabase client.
/// Only safe to read after [supabaseInitProvider] has completed.
final supabaseClientProvider = Provider<SupabaseClient>(
  (_) => SupabaseService.client,
);

/// Current auth user stream provider.
/// Waits for Supabase to finish initialising before accessing the client,
/// so accessing this before [supabaseInitProvider] completes is safe.
final authStateProvider = StreamProvider<AuthState>((ref) async* {
  // Block until Supabase.initialize() completes — avoids "not initialized" crash
  await ref.watch(supabaseInitProvider.future);
  yield* SupabaseService.client.auth.onAuthStateChange;
});

/// Convenience: current user (null if logged out)
final currentUserProvider = Provider<User?>((ref) {
  final auth = ref.watch(authStateProvider);
  return auth.whenOrNull(data: (state) => state.session?.user);
});
