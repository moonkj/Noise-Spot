import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Seeds the Supabase `spots` table from `assets/seed/brand_cafes.json`.
/// Runs only once per app install (tracked via SharedPreferences).
/// Safe to call on every cold start — skips if already seeded.
class SeedService {
  static const _prefKey = 'brand_cafes_seed_v1';

  /// Call after Supabase is initialized and user is logged in.
  static Future<void> seedIfNeeded(SupabaseClient client) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_prefKey) == true) return; // already seeded

      final raw = await rootBundle.loadString('assets/seed/brand_cafes.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final spots = json['spots'] as List<dynamic>? ?? [];

      if (spots.isEmpty) {
        debugPrint('[SeedService] seed file is empty — skipping');
        return;
      }

      final rows = spots
          .cast<Map<String, dynamic>>()
          .map((s) => {
                'name': s['name'] as String,
                'google_place_id': s['naver_place_id'] ?? s['google_place_id'],
                'location':
                    'POINT(${s['lng'] as num} ${s['lat'] as num})',
                'average_db': 0,
                'report_count': 0,
                'trust_score': 0,
              })
          .toList();

      await client
          .from('spots')
          .upsert(rows, onConflict: 'google_place_id', ignoreDuplicates: true);

      await prefs.setBool(_prefKey, true);
      debugPrint('[SeedService] seeded ${rows.length} brand cafe spots');
    } catch (e) {
      // Non-fatal — user can still use the app
      debugPrint('[SeedService] seed error: $e');
    }
  }
}
