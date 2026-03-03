import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';

class AuthRepository {
  final SupabaseClient _client;
  AuthRepository(this._client);

  /// Apple Sign In (iOS/macOS only — nonce-based PKCE for Supabase)
  Future<void> signInWithApple() async {
    final rawNonce = _generateNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: credential.identityToken!,
      nonce: rawNonce,
    );
  }

  String _generateNonce([int length = 32]) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._';
    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)])
        .join();
  }

  /// Sign in with Google via Supabase OAuth (browser redirect flow).
  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'com.cafevibe.cafevibe://login-callback',
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  /// Sign in with Kakao via Supabase OAuth (browser redirect flow).
  Future<void> signInWithKakao() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.kakao,
      redirectTo: 'com.cafevibe.cafevibe://login-callback',
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  /// Email + password sign in.
  Future<void> signInWithEmail(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Email + password sign up.
  /// Returns true if session was immediately created (email confirmation disabled).
  /// Returns false if email confirmation is required first.
  Future<bool> signUpWithEmail(String email, String password) async {
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: 'com.cafevibe.cafevibe://login-callback',
    );
    return res.session != null;
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

  /// Deletes all user data then signs out.
  /// Uses delete_my_account_data() RPC (SECURITY DEFINER, bypasses RLS).
  /// Falls back to individual deletes if RPC is not available.
  Future<void> deleteAccount() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      await _client.rpc('delete_my_account_data');
    } catch (_) {
      // RPC not yet applied — individual deletes (may be blocked by RLS)
      await _client.from('reports').delete().eq('user_id', uid);
      await _client.from('user_badges').delete().eq('user_id', uid);
      await _client.from('user_bookmarks').delete().eq('user_id', uid);
      await _client.from('user_profiles').delete().eq('user_id', uid);
      await _client.from('user_stats').delete().eq('user_id', uid);
    }
    await _client.auth.signOut();
  }

  User? get currentUser => _client.auth.currentUser;
  bool get isSignedIn => currentUser != null;
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);
