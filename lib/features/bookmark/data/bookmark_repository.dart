import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../map/domain/spot_model.dart';

// ──────────────────────────────────────────────────────────────
// Repository
// ──────────────────────────────────────────────────────────────

class BookmarkRepository {
  const BookmarkRepository(this._client);
  final SupabaseClient _client;

  String get _userId => _client.auth.currentUser!.id;

  /// 해당 spot이 북마크됐는지 확인
  Future<bool> isBookmarked(String spotId) async {
    final res = await _client
        .from('user_bookmarks')
        .select('id')
        .eq('user_id', _userId)
        .eq('spot_id', spotId)
        .maybeSingle();
    return res != null;
  }

  /// 북마크 토글 — 추가하면 true, 삭제하면 false 반환
  Future<bool> toggleBookmark(String spotId) async {
    final already = await isBookmarked(spotId);
    if (already) {
      await _client
          .from('user_bookmarks')
          .delete()
          .eq('user_id', _userId)
          .eq('spot_id', spotId);
      return false;
    } else {
      await _client.from('user_bookmarks').insert({
        'user_id': _userId,
        'spot_id': spotId,
      });
      return true;
    }
  }

  /// 내가 찜한 카페 목록 (최신 순)
  Future<List<SpotModel>> getMyBookmarks() async {
    final res = await _client
        .from('user_bookmarks')
        .select('spots(*)')
        .eq('user_id', _userId)
        .order('created_at', ascending: false)
        .timeout(const Duration(seconds: 10));

    final rows = res as List<dynamic>;
    return rows
        .map((e) {
          final spotMap = e['spots'] as Map<String, dynamic>?;
          if (spotMap == null) return null;
          // spots 테이블은 lat/lng를 직접 저장하지 않고 location(geography)으로 저장하므로
          // fromJson이 lat/lng 키를 요구 — 누락 시 0.0 fallback
          final enriched = {
            ...spotMap,
            'lat': spotMap['lat'] ?? 0.0,
            'lng': spotMap['lng'] ?? 0.0,
            'trust_score': spotMap['trust_score'] ?? 0.0,
            'recent_24h_count': spotMap['recent_24h_count'] ?? 0,
          };
          return SpotModel.fromJson(enriched);
        })
        .whereType<SpotModel>()
        .toList();
  }
}

final bookmarkRepositoryProvider = Provider<BookmarkRepository>((ref) {
  return BookmarkRepository(ref.read(supabaseClientProvider));
});

// ──────────────────────────────────────────────────────────────
// Providers
// ──────────────────────────────────────────────────────────────

/// 단일 spot 북마크 초기값 (SpotDetailScreen — 실제 토글은 위젯에서 처리)
final isBookmarkedProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, spotId) {
  return ref.read(bookmarkRepositoryProvider).isBookmarked(spotId);
});

/// 내가 찜한 카페 목록 (ProfileScreen용)
final bookmarkedSpotsProvider =
    FutureProvider.autoDispose<List<SpotModel>>((ref) {
  return ref.read(bookmarkRepositoryProvider).getMyBookmarks();
});
