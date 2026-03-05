import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

// Google Maps API key — must be supplied via --dart-define=MAPS_API_KEY=... at build time.
const _mapsApiKey = String.fromEnvironment('MAPS_API_KEY', defaultValue: '');

// 한국 로컬 비카페 블랙리스트 (Places New API 이후 2차 안전망)
const _nonCafeKeywords = [
  'pc방', 'pc 방', 'pcroom', '피시방',
  '편의점', '마트', '슈퍼마켓',
  '의류', '옷가게', '옷짱', '패션',
  '침구', '가구', '인테리어',
  '마사지', '안마원', '찜질방',
  '헬스장', '피트니스',
  '세탁소', '미용실', '네일샵',
  '약국', '동물병원',
];

bool _isNonCafe(String name) {
  final lower = name.toLowerCase();
  return _nonCafeKeywords.any((kw) => lower.contains(kw));
}

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

class PlacesService {
  final http.Client _client;
  PlacesService({http.Client? client}) : _client = client ?? http.Client();

  /// Returns autocomplete predictions for [input] using Places (New) Autocomplete API.
  ///
  /// `includedPrimaryTypes: ["cafe","coffee_shop"]` — 카페/커피숍 primary type만
  /// 허용하므로 마사지샵·미용실 등이 검색 결과에 나타나지 않음.
  Future<List<PlacePrediction>> autocomplete(
    String input, {
    double? lat,
    double? lng,
  }) async {
    if (input.trim().isEmpty) return [];
    if (_mapsApiKey.isEmpty) return [];

    final bodyMap = <String, dynamic>{
      'input': input,
      'languageCode': 'ko',
      'regionCode': 'KR',
      'includedPrimaryTypes': ['cafe', 'coffee_shop'],
    };
    if (lat != null && lng != null) {
      bodyMap['locationBias'] = {
        'circle': {
          'center': {'latitude': lat, 'longitude': lng},
          'radius': 50000.0,
        },
      };
    }

    try {
      final uri = Uri.https(
        'places.googleapis.com',
        '/v1/places:autocomplete',
      );
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': _mapsApiKey,
              'X-Goog-FieldMask':
                  'suggestions.placePrediction.placeId,'
                  'suggestions.placePrediction.structuredFormat',
            },
            body: json.encode(bodyMap),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return [];

      final data = json.decode(response.body) as Map<String, dynamic>;
      final suggestions = data['suggestions'] as List<dynamic>? ?? [];

      return suggestions
          .map((s) {
            final pp = s['placePrediction'] as Map<String, dynamic>?;
            if (pp == null) return null;
            final sf = pp['structuredFormat'] as Map<String, dynamic>? ?? {};
            final main = (sf['mainText'] as Map<String, dynamic>?)?['text']
                as String? ?? '';
            final secondary =
                (sf['secondaryText'] as Map<String, dynamic>?)?['text']
                    as String? ?? '';
            final placeId = pp['placeId'] as String?;
            if (placeId == null || main.isEmpty) return null;
            return PlacePrediction(
              placeId: placeId,
              mainText: main,
              secondaryText: secondary,
            );
          })
          .whereType<PlacePrediction>()
          .toList();
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
      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      final result = data['result'] as Map<String, dynamic>?;
      final location = (result?['geometry'] as Map<String, dynamic>?)?['location']
          as Map<String, dynamic>?;
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

  /// Returns cafes near [lat]/[lng] using Places (New) Nearby Search API.
  ///
  /// Uses `includedPrimaryTypes: ["cafe", "coffee_shop"]` — primary type이
  /// 카페/커피숍인 장소만 반환하므로 PC방·마사지샵 등이 섞이지 않음.
  /// 추가로 한국 로컬 비카페 키워드 블랙리스트로 2차 필터링.
  Future<List<PlaceResult>> nearbyCafes({
    required double lat,
    required double lng,
    int radiusMeters = 3000,
  }) async {
    if (_mapsApiKey.isEmpty) return [];
    try {
      final uri = Uri.https(
        'places.googleapis.com',
        '/v1/places:searchNearby',
      );

      final body = json.encode({
        'includedPrimaryTypes': ['cafe', 'coffee_shop'],
        'locationRestriction': {
          'circle': {
            'center': {'latitude': lat, 'longitude': lng},
            'radius': radiusMeters.toDouble(),
          },
        },
        'maxResultCount': 20,
        'languageCode': 'ko',
      });

      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': _mapsApiKey,
              'X-Goog-FieldMask':
                  'places.id,places.displayName,places.location,places.formattedAddress',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('[Places] nearbyCafes (New) HTTP ${response.statusCode}');
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body) as Map<String, dynamic>;
      final places = data['places'] as List<dynamic>? ?? [];

      final results = <PlaceResult>[];
      for (final p in places) {
        final name =
            (p['displayName'] as Map<String, dynamic>?)?['text'] as String? ?? '';
        if (name.isEmpty || _isNonCafe(name)) continue;

        final location = p['location'] as Map<String, dynamic>?;
        if (location == null) continue;

        results.add(PlaceResult(
          placeId: p['id'] as String,
          name: name,
          lat: (location['latitude'] as num).toDouble(),
          lng: (location['longitude'] as num).toDouble(),
          formattedAddress: p['formattedAddress'] as String?,
        ));
      }

      debugPrint('[Places] nearbyCafes (New): ${results.length} cafes');
      return results;
    } catch (e) {
      debugPrint('[Places] nearbyCafes error: $e');
      return [];
    }
  }

  /// Finds the best-matching Place ID for [name] near [lat]/[lng] using
  /// Places (New) Text Search, then returns its photo URL.
  /// Used for dummy spots that lack a real Google Place ID.
  Future<String?> getPhotoUrlByTextSearch(
    String name,
    double lat,
    double lng, {
    int maxWidth = 600,
  }) async {
    if (_mapsApiKey.isEmpty || name.isEmpty) return null;
    try {
      final uri = Uri.https('places.googleapis.com', '/v1/places:searchText');
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': _mapsApiKey,
              'X-Goog-FieldMask': 'places.id',
            },
            body: json.encode({
              'textQuery': name,
              'locationBias': {
                'circle': {
                  'center': {'latitude': lat, 'longitude': lng},
                  'radius': 300.0,
                },
              },
              'maxResultCount': 1,
              'languageCode': 'ko',
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final data = json.decode(response.body) as Map<String, dynamic>;
      final places = data['places'] as List<dynamic>?;
      if (places == null || places.isEmpty) return null;
      final realPlaceId =
          (places[0] as Map<String, dynamic>)['id'] as String?;
      if (realPlaceId == null) return null;
      return getPhotoUrl(realPlaceId, maxWidth: maxWidth);
    } catch (e) {
      debugPrint('[Places] getPhotoUrlByTextSearch error: $e');
      return null;
    }
  }

  /// Returns a cacheable CDN photo URL for [placeId] using Google Places (New) API.
  Future<String?> getPhotoUrl(String placeId, {int maxWidth = 600}) async {
    if (_mapsApiKey.isEmpty) return null;
    try {
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
