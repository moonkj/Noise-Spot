import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';

class ProfileRepository {
  final SupabaseClient _client;
  ProfileRepository(this._client);

  /// Fetch the current user's nickname from user_profiles.
  /// Returns null if the user has no profile record yet.
  Future<String?> getMyNickname() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final response = await _client
        .from('user_profiles')
        .select('nickname')
        .eq('user_id', userId)
        .maybeSingle();

    return response?['nickname'] as String?;
  }

  /// Save (or update) the nickname on Supabase via upsert_user_profile RPC.
  Future<void> upsertNickname(String nickname) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('로그인이 필요합니다.');

    await _client.rpc('upsert_user_profile', params: {
      'p_user_id': userId,
      'p_nickname': nickname.trim(),
    });
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(supabaseClientProvider)),
);
