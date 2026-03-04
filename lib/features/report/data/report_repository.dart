import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/level_service.dart';
import '../../map/domain/spot_model.dart';
import '../domain/report_model.dart';

class ReportRepository {
  final SupabaseClient _client;
  ReportRepository(this._client);

  /// Submit a noise report.
  /// - Saves report row (no audio — only dB number)
  /// - Calls update_spot_after_report RPC to apply EMA avg update
  /// - Awards XP: +10 (1일 1회 제한) + +5 bonus (처음 가본 카페)
  Future<void> submitReport({
    required String spotId,
    required double measuredDb,
    required StickerType? sticker,
    String? tagText,
    String? moodTag,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('로그인이 필요합니다.');

    // Validate dB range (120dB+ rejected)
    if (measuredDb >= 120 || measuredDb < 0 || !measuredDb.isFinite) {
      throw Exception('유효하지 않은 dB 값입니다.');
    }

    // Pre-checks: 3개 쿼리를 2개 병렬 쿼리로 합쳐 지연 최소화
    final todayStart = DateTime.now().toUtc().copyWith(
      hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0,
    ).toIso8601String();

    final results = await Future.wait([
      // A: 오늘 이 유저의 모든 리포트 (1일 1회 XP 체크용)
      _client.from('reports').select('id').eq('user_id', userId)
          .gte('created_at', todayStart).limit(1),
      // B: 이 카페의 이 유저 모든 리포트 (신규 카페 XP + 오늘 중복 체크용)
      _client.from('reports').select('id, created_at').eq('user_id', userId)
          .eq('spot_id', spotId).order('created_at', ascending: false).limit(1),
    ]);

    final hasReportedToday = (results[0] as List).isNotEmpty;
    final spotReports = results[1] as List;
    final isNewCafe = spotReports.isEmpty;
    if (spotReports.isNotEmpty) {
      final lastAt = DateTime.tryParse(
        (spotReports.first as Map<String, dynamic>)['created_at'] as String,
      )?.toUtc();
      if (lastAt != null && lastAt.isAfter(DateTime.parse(todayStart))) {
        throw Exception('오늘 이미 이 카페를 측정했어요.\n내일 다시 측정할 수 있어요.');
      }
    }

    // Insert report (DB: only the number, no audio)
    await _client.from('reports').insert({
      'user_id': userId,
      'spot_id': spotId,
      'measured_db': measuredDb,
      if (sticker != null) 'selected_sticker': sticker.key,
      if (tagText != null && tagText.isNotEmpty) 'tag_text': tagText,
      if (moodTag != null && moodTag.isNotEmpty) 'mood_tag': moodTag,
    }).timeout(const Duration(seconds: 10));

    // Update spot EMA average via RPC
    await _client.rpc('update_spot_after_report', params: {
      'p_spot_id': spotId,
      'p_new_db': measuredDb,
      'p_sticker': sticker?.key,
      'p_user_id': userId,
    }).timeout(const Duration(seconds: 10));

    // 통계/XP 업데이트는 UI 응답에 불필요 — fire-and-forget으로 지연 제거
    final xpEarned = (hasReportedToday ? 0 : 10) + (isNewCafe ? 5 : 0);
    _client.rpc('update_user_stats', params: {'p_user_id': userId}).catchError((_) => null);
    if (xpEarned > 0) {
      _client.rpc('award_xp', params: {
        'p_user_id': userId,
        'p_xp': xpEarned,
      }).catchError((_) => null);
    }
  }

  /// 오늘 이미 해당 카페를 측정했는지 사전 확인 (측정 시작 전 호출).
  Future<bool> hasAlreadyMeasuredToday(String spotId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    final todayStart = DateTime.now().toUtc().copyWith(
      hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0,
    ).toIso8601String();
    final resp = await _client
        .from('reports')
        .select('id')
        .eq('user_id', userId)
        .eq('spot_id', spotId)
        .gte('created_at', todayStart)
        .limit(1);
    return (resp as List).isNotEmpty;
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
  /// Returns: total, avg_db, total_cafes, has_quiet_cafe, total_xp
  Future<Map<String, dynamic>> getMyStats() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return {};

    final data = await _client
        .from('reports')
        .select('measured_db, spot_id, spots(average_db)')
        .eq('user_id', userId) as List;

    final xpRow = await _client
        .from('user_stats')
        .select('total_xp')
        .eq('user_id', userId)
        .maybeSingle();
    final totalXp = (xpRow?['total_xp'] as int?) ?? 0;

    if (data.isEmpty) {
      return {
        'total': 0,
        'avg_db': 0.0,
        'total_cafes': 0,
        'has_quiet_cafe': false,
        'total_xp': totalXp,
      };
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
      'total_xp': totalXp,
    };
  }

  /// Returns live report count and average dB for a spot directly from the
  /// reports table — bypasses the stale SpotModel passed at navigation time.
  Future<({int count, double avgDb})> getSpotStats(String spotId) async {
    final resp = await _client
        .from('reports')
        .select('measured_db')
        .eq('spot_id', spotId);
    final rows = (resp as List).cast<Map<String, dynamic>>();
    if (rows.isEmpty) return (count: 0, avgDb: 0.0);
    final avg = rows
            .map((r) => (r['measured_db'] as num).toDouble())
            .reduce((a, b) => a + b) /
        rows.length;
    return (count: rows.length, avgDb: avg);
  }

  /// Fetch recent reports for a spot with user nicknames.
  /// Uses 2 queries to avoid N+1: reports → user_profiles nickname merge.
  Future<List<Map<String, dynamic>>> getSpotRecentReports(
    String spotId, {
    int limit = 10,
  }) async {
    final reportsResp = await _client
        .from('reports')
        .select('measured_db, selected_sticker, created_at, user_id, mood_tag, tag_text')
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

  /// Returns the nickname of the first person who measured this spot.
  /// Returns null if no reports exist.
  Future<String?> getFirstReporterNickname(String spotId) async {
    final now = DateTime.now().toUtc();

    // 말일 23:59 이후면 다음 달 1일로 간주 → 아직 측정자 없음(null 반환)
    final nextMonthFirst = now.month < 12
        ? DateTime.utc(now.year, now.month + 1, 1)
        : DateTime.utc(now.year + 1, 1, 1);
    final lastDay = nextMonthFirst.subtract(const Duration(days: 1));
    final resetTime = DateTime.utc(lastDay.year, lastDay.month, lastDay.day, 23, 59);

    final effectiveMonthStart = now.isAfter(resetTime) ? nextMonthFirst : DateTime.utc(now.year, now.month);
    final monthStart = effectiveMonthStart.toIso8601String();
    final reportResp = await _client
        .from('reports')
        .select('user_id')
        .eq('spot_id', spotId)
        .gte('created_at', monthStart)
        .order('created_at', ascending: true)
        .limit(1)
        .maybeSingle();

    if (reportResp == null) return null;
    final userId = reportResp['user_id'] as String?;
    if (userId == null) return null;

    final profileResp = await _client
        .from('user_profiles')
        .select('nickname')
        .eq('user_id', userId)
        .maybeSingle();

    return profileResp?['nickname'] as String? ?? '익명';
  }

  // ──────────────────────────────────────────────────────────
  // My Map
  // ──────────────────────────────────────────────────────────

  /// Returns all unique spots the current user has measured.
  /// Uses get_spots_by_ids RPC to extract lat/lng from PostGIS location column.
  Future<List<SpotModel>> getMyReportedSpots() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final reportRes = await _client
        .from('reports')
        .select('spot_id')
        .eq('user_id', userId);
    final spotIds = (reportRes as List)
        .cast<Map<String, dynamic>>()
        .map((r) => r['spot_id'] as String)
        .toSet()
        .toList();
    if (spotIds.isEmpty) return [];

    // RPC extracts lat/lng via ST_Y/ST_X from PostGIS GEOGRAPHY(Point) column.
    // Direct table select cannot do this — PostgREST returns geography as hex WKB.
    final spotsRes = await _client.rpc(
      'get_spots_by_ids',
      params: {'p_ids': spotIds},
    );

    return (spotsRes as List).cast<Map<String, dynamic>>().map((s) {
      return SpotModel.fromJson({
        ...s,
        'trust_score': s['trust_score'] ?? 0.0,
        'recent_24h_count': s['recent_24h_count'] ?? 0,
      });
    }).toList();
  }

  // ──────────────────────────────────────────────────────────
  // Badge stats
  // ──────────────────────────────────────────────────────────

  /// Fetch all data needed to evaluate 30 badges.
  /// Returns (BadgeStats, earnedBadgeIds).
  Future<(BadgeStats, Set<String>)> getMyBadgeStats() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return (BadgeStats.empty(), <String>{});

    // Run all queries concurrently
    final results = await Future.wait([
      // 0: all reports (spot_id, measured_db, selected_sticker, tag_text, created_at)
      _client
          .from('reports')
          .select('spot_id, measured_db, selected_sticker, tag_text, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: true)
          .limit(2000),
      // 1: earned badge IDs
      _client
          .from('user_badges')
          .select('badge_id')
          .eq('user_id', userId),
    ]);

    final reports = (results[0] as List).cast<Map<String, dynamic>>();
    final earnedIds = (results[1] as List)
        .cast<Map<String, dynamic>>()
        .map((r) => r['badge_id'] as String)
        .toSet();

    if (reports.isEmpty) return (BadgeStats.empty(), earnedIds);

    // Fetch unique spots the user measured
    final spotIds = reports.map((r) => r['spot_id'] as String).toSet().toList();
    final spotsRes = await _client
        .from('spots')
        .select('id, name, formatted_address, average_db')
        .inFilter('id', spotIds);
    final spotsById = {
      for (final s in (spotsRes as List).cast<Map<String, dynamic>>())
        s['id'] as String: s,
    };

    // First reporter count via RPC
    int firstReporterCount = 0;
    try {
      final rpcResult = await _client.rpc(
        'get_first_reporter_count',
        params: {'p_user_id': userId},
      );
      firstReporterCount = (rpcResult as int?) ?? 0;
    } catch (_) {}

    return (_computeBadgeStats(
      reports: reports,
      spotsById: spotsById,
      firstReporterCount: firstReporterCount,
    ), earnedIds);
  }

  BadgeStats _computeBadgeStats({
    required List<Map<String, dynamic>> reports,
    required Map<String, Map<String, dynamic>> spotsById,
    required int firstReporterCount,
  }) {
    final uniqueSpotIds = reports.map((r) => r['spot_id'] as String).toSet();

    final hasFirstMemo = reports.any((r) {
      final t = r['tag_text'] as String?;
      return t != null && t.isNotEmpty;
    });
    final hasFirstSticker = reports.any((r) => r['selected_sticker'] != null);

    // Streak & date analysis
    final dates = reports
        .map((r) => DateTime.parse(r['created_at'] as String).toLocal())
        .toList();
    final maxStreakDays = _maxStreak(dates);
    final monthIn20Reports = _monthIn20(dates);

    // Location analysis per spot
    final Map<String, String?> spotDistrict = {};
    final Map<String, String?> spotCity = {};
    final Map<String, String?> spotChain = {};
    for (final id in uniqueSpotIds) {
      final spot = spotsById[id];
      final name = spot?['name'] as String? ?? '';
      final addr = spot?['formatted_address'] as String?;
      spotDistrict[id] = _extractDistrict(addr);
      spotCity[id] = _extractCity(addr);
      spotChain[id] = _detectChain(name);
    }

    // B12: max spots in same district
    final districtGroups = <String, int>{};
    for (final id in uniqueSpotIds) {
      final d = spotDistrict[id];
      if (d != null) districtGroups[d] = (districtGroups[d] ?? 0) + 1;
    }
    final maxNeighborhoodCafes =
        districtGroups.isEmpty ? 0 : districtGroups.values.reduce((a, b) => a > b ? a : b);
    final uniqueDistrictCount = districtGroups.length;

    // B13: max spots from same chain
    final chainGroups = <String, int>{};
    for (final id in uniqueSpotIds) {
      final c = spotChain[id];
      if (c != null) chainGroups[c] = (chainGroups[c] ?? 0) + 1;
    }
    final maxFranchiseCafes =
        chainGroups.isEmpty ? 0 : chainGroups.values.reduce((a, b) => a > b ? a : b);

    // B14: indie (non-franchise) spots
    final indieCafeCount = uniqueSpotIds.where((id) => spotChain[id] == null).length;

    // B16: unique cities
    final uniqueCityCount =
        uniqueSpotIds.map((id) => spotCity[id]).where((c) => c != null).toSet().length;

    // dB range analysis per spot
    int quietCafe50Count = 0;
    int goldenCafeCount = 0;
    int highCafeCount = 0;
    int veryQuietCafe40Count = 0;
    final dbRangeSpotCount = <String, int>{
      '<40': 0, '40-55': 0, '55-70': 0, '70-85': 0, '85+': 0
    };
    for (final id in uniqueSpotIds) {
      final avgDb = (spotsById[id]?['average_db'] as num?)?.toDouble();
      if (avgDb == null) continue;
      if (avgDb < 40) { veryQuietCafe40Count++; dbRangeSpotCount['<40'] = (dbRangeSpotCount['<40'] ?? 0) + 1; }
      else if (avgDb < 55) { dbRangeSpotCount['40-55'] = (dbRangeSpotCount['40-55'] ?? 0) + 1; }
      else if (avgDb < 70) { dbRangeSpotCount['55-70'] = (dbRangeSpotCount['55-70'] ?? 0) + 1; }
      else if (avgDb < 85) { highCafeCount++; dbRangeSpotCount['70-85'] = (dbRangeSpotCount['70-85'] ?? 0) + 1; }
      else { highCafeCount++; dbRangeSpotCount['85+'] = (dbRangeSpotCount['85+'] ?? 0) + 1; }
      if (avgDb < 50) quietCafe50Count++;
      if (avgDb >= 50 && avgDb <= 65) goldenCafeCount++;
    }

    // B20: distinct spots per measured-dB category
    final quietMeasuredSpots = <String>{};
    final midMeasuredSpots = <String>{};
    final loudMeasuredSpots = <String>{};
    for (final r in reports) {
      final db = (r['measured_db'] as num).toDouble();
      final sid = r['spot_id'] as String;
      if (db < 50) { quietMeasuredSpots.add(sid); }
      else if (db <= 70) { midMeasuredSpots.add(sid); }
      else { loudMeasuredSpots.add(sid); }
    }

    // Time-based counts
    int morningReportCount = 0;
    int nightReportCount = 0;
    int weekendReportCount = 0;
    final Map<String, Set<String>> spotsByDay = {};
    for (int i = 0; i < reports.length; i++) {
      final d = dates[i];
      if (d.hour < 9) morningReportCount++;
      if (d.hour >= 21) nightReportCount++;
      if (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) weekendReportCount++;
      final key = '${d.year}-${d.month}-${d.day}';
      spotsByDay.putIfAbsent(key, () => {}).add(reports[i]['spot_id'] as String);
    }

    // B26: max distinct cafes in one day
    final maxCafesOneDay = spotsByDay.isEmpty
        ? 0
        : spotsByDay.values.map((s) => s.length).reduce((a, b) => a > b ? a : b);

    final totalStickerCount = reports.where((r) => r['selected_sticker'] != null).length;
    final memoReportCount = reports.where((r) {
      final t = r['tag_text'] as String?;
      return t != null && t.isNotEmpty;
    }).length;

    return BadgeStats(
      totalReports: reports.length,
      totalCafes: uniqueSpotIds.length,
      hasFirstMemo: hasFirstMemo,
      hasFirstSticker: hasFirstSticker,
      maxStreakDays: maxStreakDays,
      monthIn20Reports: monthIn20Reports,
      maxNeighborhoodCafes: maxNeighborhoodCafes,
      maxFranchiseCafes: maxFranchiseCafes,
      indieCafeCount: indieCafeCount,
      firstReporterCount: firstReporterCount,
      uniqueCityCount: uniqueCityCount,
      quietCafe50Count: quietCafe50Count,
      goldenCafeCount: goldenCafeCount,
      highCafeCount: highCafeCount,
      quietSpotMeasuredCount: quietMeasuredSpots.length,
      midSpotMeasuredCount: midMeasuredSpots.length,
      loudSpotMeasuredCount: loudMeasuredSpots.length,
      veryQuietCafe40Count: veryQuietCafe40Count,
      dbRangeSpotCount: dbRangeSpotCount,
      morningReportCount: morningReportCount,
      nightReportCount: nightReportCount,
      weekendReportCount: weekendReportCount,
      maxCafesOneDay: maxCafesOneDay,
      totalStickerCount: totalStickerCount,
      memoReportCount: memoReportCount,
      uniqueDistrictCount: uniqueDistrictCount,
    );
  }

  // ── Private helpers ────────────────────────────────────────

  static int _maxStreak(List<DateTime> dates) {
    if (dates.isEmpty) return 0;
    final uniqueDays = dates
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet()
        .toList()
      ..sort();
    int maxStreak = 1;
    int current = 1;
    for (int i = 1; i < uniqueDays.length; i++) {
      if (uniqueDays[i].difference(uniqueDays[i - 1]).inDays == 1) {
        current++;
        if (current > maxStreak) maxStreak = current;
      } else {
        current = 1;
      }
    }
    return maxStreak;
  }

  static bool _monthIn20(List<DateTime> dates) {
    final Map<String, int> byMonth = {};
    for (final d in dates) {
      final key = '${d.year}-${d.month}';
      byMonth[key] = (byMonth[key] ?? 0) + 1;
    }
    return byMonth.values.any((c) => c >= 20);
  }

  static String? _extractCity(String? address) {
    if (address == null || address.trim().isEmpty) return null;
    return address.trim().split(' ').first;
  }

  static String? _extractDistrict(String? address) {
    if (address == null || address.trim().isEmpty) return null;
    final parts = address.trim().split(' ');
    if (parts.length < 2) return null;
    return '${parts[0]} ${parts[1]}';
  }

  static const List<String> _chains = [
    '스타벅스', '이디야', '투썸플레이스', '할리스', '커피빈', '파스쿠찌',
    '요거프레소', '메가커피', '컴포즈커피', '더벤티', '빽다방', '드롭탑',
    '카페베네', '엔제리너스', '달콤커피', '커피에반하다', '탐앤탐스', '폴바셋',
    '아티제', '카페모카',
  ];

  static String? _detectChain(String name) {
    for (final chain in _chains) {
      if (name.contains(chain)) return chain;
    }
    return null;
  }

  // ──────────────────────────────────────────────────────────

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
