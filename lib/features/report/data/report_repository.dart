import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../map/domain/spot_model.dart';
import '../domain/report_model.dart';

class ReportRepository {
  final SupabaseClient _client;
  ReportRepository(this._client);

  /// Submit a noise report.
  /// - Saves report row (no audio — only dB number)
  /// - Calls update_spot_after_report RPC to apply EMA avg update
  Future<void> submitReport({
    required String spotId,
    required double measuredDb,
    required StickerType sticker,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('로그인이 필요합니다.');

    // Validate dB range (120dB+ rejected)
    if (measuredDb >= 120 || measuredDb < 0 || !measuredDb.isFinite) {
      throw Exception('유효하지 않은 dB 값입니다.');
    }

    // Insert report (DB: only the number, no audio)
    await _client.from('reports').insert({
      'user_id': userId,
      'spot_id': spotId,
      'measured_db': measuredDb,
      'selected_sticker': sticker.key,
    });

    // Update spot EMA average via RPC
    await _client.rpc('update_spot_after_report', params: {
      'p_spot_id': spotId,
      'p_new_db': measuredDb,
      'p_sticker': sticker.key,
      'p_user_id': userId,
    });

    // Update aggregated user stats (total_reports, total_cafes)
    // migration 002 미적용 시 RPC 없음 → 무시 (리포트 제출은 이미 완료된 상태)
    try {
      await _client.rpc('update_user_stats', params: {'p_user_id': userId});
    } catch (_) {}
  }

  /// Fetch user's own reports, newest first.
  Future<List<ReportModel>> getMyReports({int limit = 50}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('reports')
        .select('*, spots(name, formatted_address)')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((e) => ReportModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get stats for the current user.
  /// Returns: total, avg_db, total_cafes, has_quiet_cafe
  Future<Map<String, dynamic>> getMyStats() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return {};

    final response = await _client
        .from('reports')
        .select('measured_db, spot_id, spots(average_db)')
        .eq('user_id', userId);

    final data = response as List;
    if (data.isEmpty) {
      return {'total': 0, 'avg_db': 0.0, 'total_cafes': 0, 'has_quiet_cafe': false};
    }

    final total = data.length;
    final avgDb = data
            .map((e) => (e['measured_db'] as num).toDouble())
            .reduce((a, b) => a + b) /
        total;

    final spotIds = data.map((e) => e['spot_id'] as String).toSet();
    final totalCafes = spotIds.length;

    final hasQuietCafe = data.any((e) {
      final spotData = e['spots'] as Map<String, dynamic>?;
      if (spotData == null) return false;
      final avgSpotDb = (spotData['average_db'] as num?)?.toDouble() ?? 100.0;
      return avgSpotDb < 50;
    });

    return {
      'total': total,
      'avg_db': avgDb,
      'total_cafes': totalCafes,
      'has_quiet_cafe': hasQuietCafe,
    };
  }

  /// Fetch recent reports for a spot with user nicknames.
  /// Uses 2 queries to avoid N+1: reports → user_profiles nickname merge.
  Future<List<Map<String, dynamic>>> getSpotRecentReports(
    String spotId, {
    int limit = 10,
  }) async {
    final reportsResp = await _client
        .from('reports')
        .select('measured_db, selected_sticker, created_at, user_id')
        .eq('spot_id', spotId)
        .order('created_at', ascending: false)
        .limit(limit);

    final reports = (reportsResp as List).cast<Map<String, dynamic>>();
    if (reports.isEmpty) return [];

    final userIds =
        reports.map((r) => r['user_id'] as String).toSet().toList();
    final profilesResp = await _client
        .from('user_profiles')
        .select('user_id, nickname')
        .inFilter('user_id', userIds);

    final nickMap = {
      for (final p in (profilesResp as List).cast<Map<String, dynamic>>())
        p['user_id'] as String: p['nickname'] as String?,
    };

    return reports
        .map((r) => {
              ...r,
              'nickname': nickMap[r['user_id'] as String] ?? '익명',
            })
        .toList();
  }

  /// Fetch hourly average dB for a spot over the past 30 days.
  /// Aggregated client-side by hour-of-day.
  Future<List<(int hour, double avgDb)>> getSpotHourlyNoise(
      String spotId) async {
    final since = DateTime.now()
        .subtract(const Duration(days: 30))
        .toIso8601String();
    final response = await _client
        .from('reports')
        .select('measured_db, created_at')
        .eq('spot_id', spotId)
        .gte('created_at', since);

    final data = (response as List).cast<Map<String, dynamic>>();
    final Map<int, List<double>> byHour = {};
    for (final row in data) {
      final hour =
          DateTime.parse(row['created_at'] as String).toLocal().hour;
      byHour
          .putIfAbsent(hour, () => [])
          .add((row['measured_db'] as num).toDouble());
    }
    return byHour.entries
        .map((e) =>
            (e.key, e.value.reduce((a, b) => a + b) / e.value.length))
        .toList()
      ..sort((a, b) => a.$1.compareTo(b.$1));
  }
}

final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => ReportRepository(ref.watch(supabaseClientProvider)),
);
