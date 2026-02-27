import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';

class AuthRepository {
  final SupabaseClient _client;
  AuthRepository(this._client);

  /// Sign in with Google via Supabase OAuth (browser redirect flow).
  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'com.noisespot.noisespot://login-callback',
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  /// Sign in with Kakao via Supabase OAuth (browser redirect flow).
  Future<void> signInWithKakao() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.kakao,
      redirectTo: 'com.noisespot.noisespot://login-callback',
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  /// Sign in anonymously — no OAuth required.
  /// Safe to call repeatedly: skips if already signed in.
  Future<void> signInAnonymously() async {
    if (isSignedIn) return;
    await _client.auth.signInAnonymously();
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Deletes the current user's reports then signs out.
  Future<void> deleteAccount() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    await _client.from('reports').delete().eq('user_id', uid);
    await _client.auth.signOut();
  }

  User? get currentUser => _client.auth.currentUser;
  bool get isSignedIn => currentUser != null;
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);
