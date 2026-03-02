import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';

// ──────────────────────────────────────────────────────────────
// Models
// ──────────────────────────────────────────────────────────────

class QuietCafeRankItem {
  final String id;
  final String name;
  final String? formattedAddress;
  final double averageDb;
  final String? representativeSticker;
  final int reportCount;

  const QuietCafeRankItem({
    required this.id,
    required this.name,
    this.formattedAddress,
    required this.averageDb,
    this.representativeSticker,
    required this.reportCount,
  });
}

class UserRankItem {
  final String userId;
  final String nickname;
  final int totalReports;
  final int totalCafes;

  const UserRankItem({
    required this.userId,
    required this.nickname,
    required this.totalReports,
    required this.totalCafes,
  });
}

class WeeklyCafeRankItem {
  final String id;
  final String name;
  final String? formattedAddress;
  final String? representativeSticker;
  final int weeklyCount;
  final int totalCount;

  const WeeklyCafeRankItem({
    required this.id,
    required this.name,
    this.formattedAddress,
    this.representativeSticker,
    required this.weeklyCount,
    required this.totalCount,
  });
}

// ──────────────────────────────────────────────────────────────
// Repository
// ──────────────────────────────────────────────────────────────

class RankingRepository {
  final SupabaseClient _client;
  RankingRepository(this._client);

  // ── Tab 1: 잔잔한 카페 TOP ─────────────────────────────────
  // spots 테이블 직접 쿼리 — RPC / migration 불필요
  Future<List<QuietCafeRankItem>> getQuietCafeRanking() async {
    final res = await _client
        .from('spots')
        .select()
        .gte('report_count', 1)
        .gt('average_db', 0)
        .order('average_db', ascending: true)
        .limit(20)
        .timeout(const Duration(seconds: 10));

    return (res as List).map((e) {
      final m = e as Map<String, dynamic>;
      return QuietCafeRankItem(
        id: m['id'] as String,
        name: m['name'] as String,
        formattedAddress: m['formatted_address'] as String?,
        averageDb: (m['average_db'] as num).toDouble(),
        representativeSticker: m['representative_sticker'] as String?,
        reportCount: (m['report_count'] as num).toInt(),
      );
    }).toList();
  }

  // ── Tab 2: 바이브 탐험가 TOP ───────────────────────────────
  // user_stats 테이블 직접 쿼리 (migration 002 필요)
  // migration 미적용 시 빈 목록 반환 — 앱 crash 없음
  Future<List<UserRankItem>> getUserRanking() async {
    try {
      final statsRes = await _client
          .from('user_stats')
          .select('user_id, total_reports, total_cafes')
          .gt('total_reports', 0)
          .order('total_reports', ascending: false)
          .limit(20)
          .timeout(const Duration(seconds: 5));

      final stats = statsRes as List;
      if (stats.isEmpty) return [];

      // 닉네임 별도 조회 (user_profiles 테이블)
      final userIds = stats.map((e) => (e as Map)['user_id'] as String).toList();
      final Map<String, String> nicknames = {};
      try {
        final profilesRes = await _client
            .from('user_profiles')
            .select('user_id, nickname')
            .inFilter('user_id', userIds)
            .timeout(const Duration(seconds: 5));
        for (final p in profilesRes as List) {
          final pm = p as Map<String, dynamic>;
          final nick = pm['nickname'] as String?;
          if (nick != null && nick.isNotEmpty) {
            nicknames[pm['user_id'] as String] = nick;
          }
        }
      } catch (_) {
        // user_profiles 없어도 닉네임 없이 표시 가능
      }

      return stats.map((e) {
        final m = e as Map<String, dynamic>;
        final uid = m['user_id'] as String;
        return UserRankItem(
          userId: uid,
          nickname: nicknames[uid] ?? '카페바이브 유저',
          totalReports: (m['total_reports'] as num).toInt(),
          totalCafes: (m['total_cafes'] as num).toInt(),
        );
      }).toList();
    } catch (_) {
      // user_stats 테이블 없음 (migration 002 미적용) → 빈 목록
      return [];
    }
  }

  // ── Tab 3: 이번 주 인기 바이브 카페 ────────────────────────
  // reports 테이블에서 7일간 데이터 직접 집계 — RPC / migration 불필요
  Future<List<WeeklyCafeRankItem>> getWeeklyCafeRanking() async {
    final cutoff = DateTime.now()
        .subtract(const Duration(days: 7))
        .toUtc()
        .toIso8601String();

    final res = await _client
        .from('reports')
        .select('spot_id, spots(id, name, formatted_address, representative_sticker)')
        .gte('created_at', cutoff)
        .limit(500)
        .timeout(const Duration(seconds: 10));

    // Dart-side 집계: spot별 주간 리포트 수 (report_count는 실제 행 수로 집계)
    final Map<String, Map<String, dynamic>> bySpot = {};
    for (final r in res as List) {
      final rm = r as Map<String, dynamic>;
      final spotId = rm['spot_id'] as String?;
      if (spotId == null) continue;
      final spot = rm['spots'] as Map<String, dynamic>?;
      if (spot == null) continue;

      if (!bySpot.containsKey(spotId)) {
        bySpot[spotId] = {
          'id': spot['id'] as String? ?? spotId,
          'name': spot['name'] as String? ?? '',
          'formatted_address': spot['formatted_address'] as String?,
          'representative_sticker': spot['representative_sticker'],
          'weekly_count': 0,
        };
      }
      bySpot[spotId]!['weekly_count'] =
          (bySpot[spotId]!['weekly_count'] as int) + 1;
    }

    final items = bySpot.values
        .where((e) => (e['name'] as String).isNotEmpty)
        .map((e) {
          final wc = e['weekly_count'] as int;
          return WeeklyCafeRankItem(
            id: e['id'] as String,
            name: e['name'] as String,
            formattedAddress: e['formatted_address'] as String?,
            representativeSticker: e['representative_sticker'] as String?,
            weeklyCount: wc,
            totalCount: wc, // weekly 집계 내에서 실제 측정 수
          );
        })
        .toList()
      ..sort((a, b) => b.weeklyCount.compareTo(a.weeklyCount));

    return items.take(20).toList();
  }
}

// ──────────────────────────────────────────────────────────────
// Providers
// ──────────────────────────────────────────────────────────────

final rankingRepositoryProvider = Provider<RankingRepository>(
  (ref) => RankingRepository(ref.watch(supabaseClientProvider)),
);

// autoDispose 제거 — 탭 전환 시 provider가 dispose되지 않음 (영구 loading 루프 방지)
// ref.invalidate()로 수동 새로고침 가능 (retry 버튼)
final quietCafeRankingProvider = FutureProvider<List<QuietCafeRankItem>>((ref) {
  return ref.read(rankingRepositoryProvider).getQuietCafeRanking();
});

final userRankingProvider = FutureProvider<List<UserRankItem>>((ref) {
  return ref.read(rankingRepositoryProvider).getUserRanking();
});

final weeklyCafeRankingProvider = FutureProvider<List<WeeklyCafeRankItem>>((ref) {
  return ref.read(rankingRepositoryProvider).getWeeklyCafeRanking();
});
