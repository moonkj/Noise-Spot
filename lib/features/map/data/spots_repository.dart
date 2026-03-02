import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/constants/map_constants.dart';
import '../../../core/services/places_service.dart';
import '../domain/spot_model.dart';

/// Manually registered spot — used for admin management UI.
class AdminSpot {
  final String id;
  final String name;
  final String? formattedAddress;
  final double lat;
  final double lng;
  final int reportCount;
  final DateTime createdAt;

  const AdminSpot({
    required this.id,
    required this.name,
    this.formattedAddress,
    required this.lat,
    required this.lng,
    required this.reportCount,
    required this.createdAt,
  });

  factory AdminSpot.fromJson(Map<String, dynamic> j) => AdminSpot(
        id: j['id'] as String,
        name: j['name'] as String,
        formattedAddress: j['formatted_address'] as String?,
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        reportCount: j['report_count'] as int,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class SpotsRepository {
  final SupabaseClient _client;
  SpotsRepository(this._client);

  /// Fetch spots within [radiusMeters] of [lat]/[lng] using PostGIS RPC.
  /// Optionally filter by [sticker] type.
  /// Results exclude spots inactive for 30+ days.
  Future<List<SpotModel>> getSpotsNear({
    required double lat,
    required double lng,
    double radiusMeters = MapConstants.defaultRadiusMeters,
    StickerType? sticker,
  }) async {
    final clampedRadius = radiusMeters.clamp(0, MapConstants.maxRadiusMeters);

    final response = await _client.rpc(
      'get_spots_near',
      params: {
        'user_lat': lat,
        'user_lng': lng,
        'radius_meters': clampedRadius,
        if (sticker != null) 'filter_sticker': sticker.key,
      },
    );

    final data = response as List<dynamic>;
    return data
        .map((e) => SpotModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Look up a spot by google_place_id. Returns null if not found.
  /// Note: lat/lng not available from direct table query — use get_spots_near RPC.
  Future<bool> spotExistsByPlaceId(String placeId) async {
    final response = await _client
        .from('spots')
        .select('id')
        .eq('google_place_id', placeId)
        .maybeSingle();
    return response != null;
  }

  /// Upsert brand cafe spots discovered via Places Nearby Search.
  /// Skips spots that already exist (google_place_id UNIQUE constraint).
  /// Returns the number of newly inserted spots.
  Future<int> upsertBrandSpots(List<PlaceResult> places) async {
    if (places.isEmpty) return 0;

    final rows = places
        .map((p) => {
              'name': p.name,
              'google_place_id': p.placeId,
              'location': 'POINT(${p.lng} ${p.lat})',
              'average_db': 0,
              'report_count': 0,
              'trust_score': 0,
              if (p.formattedAddress != null)
                'formatted_address': p.formattedAddress,
            })
        .toList();

    final response = await _client
        .from('spots')
        .upsert(rows, onConflict: 'google_place_id', ignoreDuplicates: true)
        .select('id');

    return (response as List).length;
  }

  /// Returns the spot ID for a given [placeId], or null if not in DB yet.
  Future<String?> getSpotIdByPlaceId(String placeId) async {
    final response = await _client
        .from('spots')
        .select('id')
        .eq('google_place_id', placeId)
        .maybeSingle();
    return response?['id'] as String?;
  }

  /// Create a new spot (called once per new location during first report).
  Future<String> createSpot({
    required String name,
    required String? googlePlaceId,
    required double lat,
    required double lng,
    String? formattedAddress,
  }) async {
    final response = await _client
        .from('spots')
        .insert({
          'name': name,
          // ignore: use_null_aware_elements
          if (googlePlaceId != null) 'google_place_id': googlePlaceId,
          'location': 'POINT($lng $lat)',
          'average_db': 0,
          'report_count': 0,
          'trust_score': 0,
          if (formattedAddress != null && formattedAddress.isNotEmpty)
            'formatted_address': formattedAddress,
        })
        .select('id')
        .single();

    return response['id'] as String;
  }

  /// Fetch all manually added spots (no google_place_id) for admin management.
  Future<List<AdminSpot>> fetchManualSpots() async {
    final data = await _client.rpc('get_admin_spots');
    return (data as List)
        .map((e) => AdminSpot.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Update a spot's name, address, and/or location.
  Future<void> updateSpot(
    String id, {
    required String name,
    String? formattedAddress,
    required double lat,
    required double lng,
  }) async {
    await _client.from('spots').update({
      'name': name,
      'formatted_address':
          (formattedAddress == null || formattedAddress.isEmpty) ? null : formattedAddress,
      'location': 'POINT($lng $lat)',
    }).eq('id', id);
  }

  /// Delete a spot (and cascade-deletes its reports via FK).
  Future<void> deleteSpot(String id) async {
    await _client.from('spots').delete().eq('id', id);
  }
}

final spotsRepositoryProvider = Provider<SpotsRepository>(
  (ref) => SpotsRepository(ref.watch(supabaseClientProvider)),
);
