import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

    final idToken = credential.identityToken;
    if (idToken == null) throw Exception('Apple Sign In: identityToken이 없습니다.');

    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
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
    await _clearLocalPii();
    await _client.auth.signOut();
  }

  /// 로그아웃 시 SharedPreferences에 저장된 개인 식별 데이터 삭제.
  /// 닉네임·대표뱃지·닉네임 프롬프트 플래그 등 PII 항목 정리.
  static Future<void> _clearLocalPii() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_nickname');
    await prefs.remove('nickname_prompt_shown');
    await prefs.remove('rep_badge_id');
  }

  /// Deletes all user data and the auth.users row, then signs out locally.
  /// Uses delete_my_account_full() SECURITY DEFINER RPC — no Edge Function needed.
  /// Returns true if the server-side account was fully deleted (auth.users removed).
  /// Returns false if the RPC failed — account may still exist on the server.
  Future<bool> deleteAccount() async {
    if (_client.auth.currentUser == null) return false;

    bool serverDeleted = false;
    try {
      await _client.rpc('delete_my_account_full');
      serverDeleted = true;
    } catch (_) {
      // RPC failed — try legacy data-only cleanup (auth.users NOT deleted).
      try {
        await _client.rpc('delete_my_account_data');
      } catch (_) {}
    }

    await _clearLocalPii();
    await _client.auth.signOut();
    return serverDeleted;
  }

  User? get currentUser => _client.auth.currentUser;
  bool get isSignedIn => currentUser != null;
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);
