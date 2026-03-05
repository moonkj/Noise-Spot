import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

// Google Maps API key — must be supplied via --dart-define=MAPS_API_KEY=... at build time.
// No fallback defaultValue: an empty key surfaces API errors immediately rather than
// shipping a hardcoded key in source control.
const _mapsApiKey = String.fromEnvironment('MAPS_API_KEY', defaultValue: '');

class PlacePrediction {
  final String placeId;
  final String mainText;
  final String secondaryText;

  const PlacePrediction({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
  });
}

class PlaceLatLng {
  final double lat;
  final double lng;
  const PlaceLatLng({required this.lat, required this.lng});
}

/// A discovered place with coordinates — used for cafe seeding.
class PlaceResult {
  final String placeId;
  final String name;
  final double lat;
  final double lng;
  final String? formattedAddress;

  const PlaceResult({
    required this.placeId,
    required this.name,
    required this.lat,
    required this.lng,
    this.formattedAddress,
  });
}

/// Brand name keywords (Korean + English) used to filter Nearby Search results.
const _brandKeywords = [
  '스타벅스', 'starbucks',
  '투썸플레이스', 'a twosome', 'twosome',
  '이디야', 'ediya',
  '메가커피', '메가mgc', 'mega coffee',
  '할리스', 'hollys',
  '컴포즈커피', 'compose coffee',
  '파스쿠찌', 'pascucci',
  '탐앤탐스', 'tom n toms', 'tomntoms',
  '커피빈', 'coffee bean',
  '엔제리너스', 'angelinus',
  '폴바셋', 'paul bassett',
  '블루보틀', 'blue bottle',
  '카페베네', 'caffe bene',
  '빽다방', 'paik',
  '드롭탑', 'droptop',
];

class PlacesService {
  final http.Client _client;
  PlacesService({http.Client? client}) : _client = client ?? http.Client();

  /// Returns autocomplete predictions for [input], biased toward [lat]/[lng].
  Future<List<PlacePrediction>> autocomplete(
    String input, {
    double? lat,
    double? lng,
  }) async {
    if (input.trim().isEmpty) return [];

    final params = <String, String>{
      'input': input,
      'key': _mapsApiKey,
      'language': 'ko',
      'components': 'country:kr',
    };
    if (lat != null && lng != null) {
      params['location'] = '$lat,$lng';
      params['radius'] = '50000';
    }

    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/autocomplete/json',
        params,
      );
      final response = await _client.get(uri).timeout(const Duration(seconds: 5));
      final body = response.body;
      debugPrint('[Places] HTTP ${response.statusCode} | ${body.length > 300 ? body.substring(0, 300) : body}');
      if (response.statusCode != 200) return [];

      final data = json.decode(body) as Map<String, dynamic>;
      debugPrint('[Places] status=${data['status']} error=${data['error_message']}');
      final predictions = data['predictions'] as List<dynamic>? ?? [];

      return predictions.map((p) {
        final structured =
            p['structured_formatting'] as Map<String, dynamic>? ?? {};
        return PlacePrediction(
          placeId: p['place_id'] as String,
          mainText: structured['main_text'] as String? ??
              p['description'] as String,
          secondaryText: structured['secondary_text'] as String? ?? '',
        );
      }).toList();
    } catch (e) {
      debugPrint('[Places] autocomplete error: $e');
      return [];
    }
  }

  /// Returns lat/lng for a given [placeId].
  Future<PlaceLatLng?> getDetails(String placeId) async {
    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/details/json',
        {
          'place_id': placeId,
          'fields': 'geometry',
          'key': _mapsApiKey,
        },
      );
      final response = await _client.get(uri).timeout(const Duration(seconds: 5));
      final body = response.body;
      debugPrint('[Places] details HTTP ${response.statusCode} | ${body.length > 300 ? body.substring(0, 300) : body}');
      if (response.statusCode != 200) return null;

      final data = json.decode(body) as Map<String, dynamic>;
      debugPrint('[Places] details status=${data['status']} error=${data['error_message']}');
      final result = data['result'] as Map<String, dynamic>?;
      final location = (result?['geometry'] as Map<String, dynamic>?)?['location']
          as Map<String, dynamic>?;
      debugPrint('[Places] details location=$location');
      if (location == null) return null;

      return PlaceLatLng(
        lat: (location['lat'] as num).toDouble(),
        lng: (location['lng'] as num).toDouble(),
      );
    } catch (e) {
      debugPrint('[Places] getDetails error: $e');
      return null;
    }
  }

  /// Returns lat/lng for a given [address] string using Google Geocoding API.
  Future<PlaceLatLng?> geocodeAddress(String address) async {
    if (address.trim().isEmpty) return null;
    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/geocode/json',
        {
          'address': address,
          'key': _mapsApiKey,
          'language': 'ko',
          'region': 'kr',
        },
      );
      final response = await _client.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return null;

      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;

      final loc = ((results[0] as Map)['geometry'] as Map)['location'] as Map;
      return PlaceLatLng(
        lat: (loc['lat'] as num).toDouble(),
        lng: (loc['lng'] as num).toDouble(),
      );
    } catch (e) {
      debugPrint('[Places] geocodeAddress error: $e');
      return null;
    }
  }

  /// Returns brand cafes near [lat]/[lng] using Google Places Nearby Search.
  /// Filters results to known brand names only.
  /// [radiusMeters] defaults to 3 km.
  Future<List<PlaceResult>> nearbyBrandCafes({
    required double lat,
    required double lng,
    int radiusMeters = 3000,
  }) async {
    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/nearbysearch/json',
        {
          'location': '$lat,$lng',
          'radius': '$radiusMeters',
          'type': 'cafe',
          'key': _mapsApiKey,
          'language': 'ko',
        },
      );

      final response = await _client.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body) as Map<String, dynamic>;
      final status = data['status'] as String?;
      if (status != 'OK' && status != 'ZERO_RESULTS') return [];

      final results = data['results'] as List<dynamic>? ?? [];
      final brandCafes = <PlaceResult>[];

      for (final r in results) {
        final name = r['name'] as String? ?? '';
        final lower = name.toLowerCase();

        // Only include recognized brand cafes
        if (!_brandKeywords.any((kw) => lower.contains(kw.toLowerCase()))) continue;

        final geo = (r['geometry'] as Map<String, dynamic>?)?['location']
            as Map<String, dynamic>?;
        if (geo == null) continue;

        brandCafes.add(PlaceResult(
          placeId: r['place_id'] as String,
          name: name,
          lat: (geo['lat'] as num).toDouble(),
          lng: (geo['lng'] as num).toDouble(),
        ));
      }

      return brandCafes;
    } catch (e) {
      debugPrint('[Places] nearbyBrandCafes error: $e');
      return [];
    }
  }

  /// Returns ALL cafes near [lat]/[lng] (no brand filter), up to 3 pages (60 results).
  /// Includes `formattedAddress` via Place Details when available from the Nearby response.
  /// [radiusMeters] defaults to 3 km.
  Future<List<PlaceResult>> nearbyCafes({
    required double lat,
    required double lng,
    int radiusMeters = 3000,
  }) async {
    try {
      final all = <PlaceResult>[];
      String? pageToken;
      int page = 0;

      do {
        final params = <String, String>{
          'location': '$lat,$lng',
          'radius': '$radiusMeters',
          'type': 'cafe',
          'key': _mapsApiKey,
          'language': 'ko',
          'pagetoken': ?pageToken,
        };

        final uri = Uri.https(
          'maps.googleapis.com',
          '/maps/api/place/nearbysearch/json',
          params,
        );

        final response =
            await _client.get(uri).timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) break;

        final data = json.decode(response.body) as Map<String, dynamic>;
        final status = data['status'] as String?;
        if (status != 'OK' && status != 'ZERO_RESULTS') break;

        final results = data['results'] as List<dynamic>? ?? [];
        for (final r in results) {
          final name = r['name'] as String? ?? '';
          final geo = (r['geometry'] as Map<String, dynamic>?)?['location']
              as Map<String, dynamic>?;
          if (geo == null) continue;

          // types 필터: 실제 음식/음료 업종만 포함 (세탁소·미용실 등 오분류 제외)
          final types = (r['types'] as List<dynamic>? ?? []).cast<String>();
          const foodTypes = {'cafe', 'food', 'bakery', 'bar', 'restaurant'};
          if (!types.any(foodTypes.contains)) continue;

          final vicinity = r['vicinity'] as String?;
          all.add(PlaceResult(
            placeId: r['place_id'] as String,
            name: name,
            lat: (geo['lat'] as num).toDouble(),
            lng: (geo['lng'] as num).toDouble(),
            formattedAddress: vicinity,
          ));
        }

        pageToken = data['next_page_token'] as String?;
        page++;

        // Google requires a short delay before next page token is valid
        if (pageToken != null && page < 3) {
          await Future.delayed(const Duration(seconds: 2));
        }
      } while (pageToken != null && page < 3);

      debugPrint('[Places] nearbyCafes: ${all.length} results ($page pages)');
      return all;
    } catch (e) {
      debugPrint('[Places] nearbyCafes error: $e');
      return [];
    }
  }

  /// Returns a cacheable CDN photo URL for [placeId] using Google Places (New) API.
  /// The returned URL is a direct lh3.googleusercontent.com CDN link (no API key embedded).
  Future<String?> getPhotoUrl(String placeId, {int maxWidth = 600}) async {
    if (_mapsApiKey.isEmpty) return null;
    try {
      // Step 1: Get photo name via Place Details (New) API.
      final detailsUri = Uri.https(
        'places.googleapis.com',
        '/v1/places/$placeId',
        {'key': _mapsApiKey},
      );
      final detailsResp = await _client
          .get(detailsUri, headers: {'X-Goog-FieldMask': 'photos'})
          .timeout(const Duration(seconds: 8));
      if (detailsResp.statusCode != 200) return null;

      final detailsData =
          json.decode(detailsResp.body) as Map<String, dynamic>;
      final photos = detailsData['photos'] as List<dynamic>?;
      if (photos == null || photos.isEmpty) return null;
      final photoName =
          (photos[0] as Map<String, dynamic>)['name'] as String?;
      if (photoName == null) return null;

      // Step 2: Resolve the CDN URL (skipHttpRedirect → JSON { "photoUri": "..." }).
      final mediaUri = Uri.https(
        'places.googleapis.com',
        '/v1/$photoName/media',
        {
          'maxWidthPx': '$maxWidth',
          'key': _mapsApiKey,
          'skipHttpRedirect': 'true',
        },
      );
      final mediaResp =
          await _client.get(mediaUri).timeout(const Duration(seconds: 8));
      if (mediaResp.statusCode != 200) return null;
      final mediaData =
          json.decode(mediaResp.body) as Map<String, dynamic>;
      return mediaData['photoUri'] as String?;
    } catch (e) {
      debugPrint('[Places] getPhotoUrl error: $e');
      return null;
    }
  }
}

final placesServiceProvider = Provider<PlacesService>((_) => PlacesService());
