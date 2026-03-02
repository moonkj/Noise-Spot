import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Persists the Supabase session in the iCloud Keychain via flutter_secure_storage.
///
/// [synchronizable: true] stores the item in iCloud Keychain, which means:
///   - Survives app reinstalls (restored from iCloud on fresh install)
///   - Survives app restarts (same anonymous UUID every time)
///   - Syncs across the user's Apple devices (same account = same anonymous user)
///
/// Keychain item is removed on [removePersistedSession] (앱 데이터 초기화).
class SecureLocalStorage extends LocalStorage {
  static const _key = 'sb_session';
  static const _st = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
      synchronizable: true,
    ),
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  const SecureLocalStorage();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async {
    try {
      final val = await _st.read(key: _key);
      return val != null;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> accessToken() async {
    try {
      return await _st.read(key: _key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    try {
      await _st.write(key: _key, value: persistSessionString);
    } catch (_) {}
  }

  @override
  Future<void> removePersistedSession() async {
    try {
      await _st.delete(key: _key);
    } catch (_) {}
  }
}
