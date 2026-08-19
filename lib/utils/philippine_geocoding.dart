import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../mobile_ui/widgets/leaflet_map.dart';

/// Comprehensive Philippine Geocoding and Plus Code (Open Location Code) Decoder.
///
/// Converts Plus Codes (e.g. `2C26+P6G, Santa Barbara, Pangasinan`), city names
/// (e.g. `Santa Barbara`, `Dagupan`, `San Carlos`), addresses, and tracker
/// coordinates into accurate [MobilisMapPoint] locations.
class PhilippineGeocoding {
  // Default reference location (PSDC Garage in Urdaneta, Pangasinan)
  static const double defaultLat = 15.9758;
  static const double defaultLng = 120.5719;

  // Open Location Code characters (Base 20)
  static const String _olcChars = '23456789CFGHJMPQRVWX';

  // In-memory geocoding cache
  static final Map<String, MobilisMapPoint?> _cache = {};

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. BUILT-IN PHILIPPINE CITY & MUNICIPALITY COORDINATE REGISTRY
  // ═══════════════════════════════════════════════════════════════════════════
  static const Map<String, (double, double)> _knownLocations = {
    // Pangasinan
    'santa barbara': (15.9987, 120.4021),
    'sta barbara': (15.9987, 120.4021),
    'sta. barbara': (15.9987, 120.4021),
    'dagupan': (16.0433, 120.3333),
    'dagupan city': (16.0433, 120.3333),
    'san carlos': (15.9281, 120.3488),
    'san carlos city': (15.9281, 120.3488),
    'urdaneta': (15.9758, 120.5719),
    'urdaneta city': (15.9758, 120.5719),
    'psdc': (15.9758, 120.5719),
    'psdc garage': (15.9758, 120.5719),
    'lingayen': (16.0218, 120.2319),
    'calasiao': (16.0125, 120.3589),
    'malasiqui': (15.9197, 120.4144),
    'bayambang': (15.8127, 120.4557),
    'rosales': (15.8922, 120.5975),
    'manaoag': (16.0439, 120.4867),
    'mangaldan': (16.0708, 120.4028),
    'alaminos': (16.1558, 119.9806),
    'alaminos city': (16.1558, 119.9806),
    'binalonan': (16.0483, 120.5936),
    'pozorrubio': (16.1139, 120.5469),
    'villasis': (15.9017, 120.5878),
    'asingan': (16.0028, 120.6694),
    'tayug': (16.0289, 120.7456),
    'san manuel': (16.0664, 120.6675),
    'san fabian': (16.1219, 120.4039),
    'binmaley': (16.0306, 120.2678),
    'bugallon': (15.9525, 120.2197),
    'aguilar': (15.8931, 120.2392),
    'mangatarem': (15.7892, 120.2975),
    'urbiztondo': (15.8239, 120.3308),
    'san jacinto': (16.0736, 120.4422),
    'mapandan': (16.0267, 120.4542),
    'laoac': (16.0522, 120.5489),
    'sison': (16.1733, 120.5083),
    'bolinao': (16.3883, 119.8949),
    'anda': (16.2917, 119.9972),
    'bani': (16.1856, 119.8631),
    'agno': (16.1189, 119.7997),
    'burgos': (16.0594, 119.8661),
    'dasol': (15.9897, 119.8806),
    'infanta': (15.8267, 119.9078),
    'mabini': (16.0683, 119.9406),
    'sual': (16.0644, 120.0931),
    'labrador': (16.0289, 120.1444),
    'basista': (15.8547, 120.4017),
    'bautista': (15.8089, 120.4797),
    'alcala': (15.8458, 120.5186),
    'santo tomas': (15.8828, 120.5739),
    'san nicolas': (16.0719, 120.7678),
    'natividad': (16.0442, 120.7972),
    'san quintin': (15.9861, 120.8164),
    'umingan': (15.9264, 120.8406),
    'balungao': (15.8986, 120.6978),
    'santa maria': (15.9806, 120.7014),

    // Benguet / Baguio
    'baguio': (16.4023, 120.5960),
    'baguio city': (16.4023, 120.5960),
    'la trinidad': (16.4556, 120.5878),
    'itogon': (16.3667, 120.6667),
    'tuba': (16.3500, 120.5500),

    // La Union
    'san fernando la union': (16.6159, 120.3209),
    'agoo': (16.3217, 120.3667),
    'bauang': (16.5333, 120.3333),
    'naguilian': (16.5283, 120.3958),
    'rosario la union': (16.2289, 120.4858),
    'bacnotan': (16.7194, 120.3547),
    'san juan la union': (16.6833, 120.3333),

    // Ilocos Sur & Norte
    'vigan': (17.5747, 120.3869),
    'vigan city': (17.5747, 120.3869),
    'candon': (17.1917, 120.4489),
    'laoag': (18.1960, 120.5927),
    'laoag city': (18.1960, 120.5927),
    'batac': (18.0556, 120.5653),

    // Tarlac
    'tarlac': (15.4802, 120.5979),
    'tarlac city': (15.4802, 120.5979),
    'capas': (15.3333, 120.5833),
    'concepcion': (15.3247, 120.6558),
    'paniqui': (15.6667, 120.5833),
    'gerona': (15.6067, 120.5997),
    'bamban': (15.2750, 120.5694),

    // Pampanga
    'angeles': (15.1450, 120.5887),
    'angeles city': (15.1450, 120.5887),
    'san fernando pampanga': (15.0342, 120.6850),
    'mabalacat': (15.2167, 120.5833),
    'clark': (15.1850, 120.5430),
    'guagua': (14.9667, 120.6333),

    // Nueva Ecija
    'cabanatuan': (15.4864, 120.9733),
    'cabanatuan city': (15.4864, 120.9733),
    'gapan': (15.3083, 120.9472),
    'san jose nueva ecija': (15.7917, 120.9889),
    'talavera': (15.5833, 120.9167),
    'guimba': (15.6583, 120.7681),
    'cuyapo': (15.7761, 120.6694),

    // Zambales
    'olongapo': (14.8386, 120.2842),
    'subic': (14.8789, 120.2356),
    'iba': (15.3267, 119.9806),

    // Metro Manila / NCR
    'manila': (14.5995, 120.9842),
    'quezon city': (14.6760, 121.0437),
    'makati': (14.5547, 121.0244),
    'pasig': (14.5764, 121.0851),
    'taguig': (14.5176, 121.0509),
    'caloocan': (14.6488, 120.9678),
    'paranaque': (14.4793, 121.0198),
    'pasay': (14.5378, 121.0014),
    'mandaluyong': (14.5794, 121.0359),
    'san juan': (14.6019, 121.0355),
    'marikina': (14.6507, 121.1029),
    'las pinas': (14.4445, 120.9939),
    'muntinlupa': (14.4081, 121.0415),
    'valenzuela': (14.7011, 120.9830),
    'malabon': (14.6625, 120.9569),
    'navotas': (14.6667, 120.9417),

    // Bulacan
    'malolos': (14.8433, 120.8114),
    'meycauayan': (14.7347, 120.9578),
    'san jose del monte': (14.8139, 121.0453),
    'baliuag': (14.9536, 120.9008),
    'marilao': (14.7578, 120.9483),
  };

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. OPEN LOCATION CODE (PLUS CODE) DECODER
  // ═══════════════════════════════════════════════════════════════════════════

  /// Checks if a string is or contains a Plus Code (e.g. `2C26+P6G`, `7QQ22C26+P6G`, `XGFW+JQ`).
  static bool isPlusCode(String text) {
    final clean = text.trim();
    return RegExp(
      r'[23456789CFGHJMPQRVWX]{2,8}\+[23456789CFGHJMPQRVWX]{2,4}',
      caseSensitive: false,
    ).hasMatch(clean);
  }

  /// Extracts the Plus Code portion from an address string.
  static String? extractPlusCode(String text) {
    final match = RegExp(
      r'([23456789CFGHJMPQRVWX]{2,8}\+[23456789CFGHJMPQRVWX]{2,4})',
      caseSensitive: false,
    ).firstMatch(text.trim());
    return match?.group(1)?.toUpperCase();
  }

  /// Decodes a full 8 to 11 character Plus Code (e.g. `7QQ22C26+P6G`).
  static MobilisMapPoint? decodeFullPlusCode(String code) {
    try {
      final clean = code.toUpperCase().replaceAll('+', '').trim();
      if (clean.length < 8) return null;

      double lat = -90.0;
      double lng = -180.0;
      double latRes = 20.0;
      double lngRes = 20.0;

      // First 5 pairs (10 digits)
      final pairCount = math.min(clean.length ~/ 2, 5);
      for (int i = 0; i < pairCount; i++) {
        final latChar = clean[i * 2];
        final lngChar = clean[i * 2 + 1];

        final latVal = _olcChars.indexOf(latChar);
        final lngVal = _olcChars.indexOf(lngChar);
        if (latVal == -1 || lngVal == -1) return null;

        lat += latVal * latRes;
        lng += lngVal * lngRes;

        latRes /= 20.0;
        lngRes /= 20.0;
      }

      // Final center point
      final centerLat = lat + (latRes * 20.0) / 2.0;
      final centerLng = lng + (lngRes * 20.0) / 2.0;

      final point = MobilisMapPoint(latitude: centerLat, longitude: centerLng);
      return isValidPhilippines(point) ? point : null;
    } catch (_) {
      return null;
    }
  }

  /// Decodes a short Plus Code (e.g. `2C26+P6G`) using a reference location
  /// (e.g. from the city name mentioned in the address, or the Pangasinan/Luzon center).
  static MobilisMapPoint? decodeShortPlusCode(
    String shortCode, {
    double refLat = defaultLat,
    double refLng = defaultLng,
  }) {
    try {
      final clean = shortCode.toUpperCase().trim();
      final plusIndex = clean.indexOf('+');
      if (plusIndex < 0) return null;

      // If already a full code (8+ chars before '+'), decode directly
      if (plusIndex >= 8) {
        return decodeFullPlusCode(clean);
      }

      // Compute prefix for reference latitude & longitude
      // OLC first 4 chars represent ~1 degree blocks (lat: -90..90, lng: -180..180)
      final latVal0 = ((refLat + 90.0) / 20.0).floor().clamp(0, 19);
      final lngVal0 = ((refLng + 180.0) / 20.0).floor().clamp(0, 19);
      final latVal1 = (((refLat + 90.0) % 20.0) / 1.0).floor().clamp(0, 19);
      final lngVal1 = (((refLng + 180.0) % 20.0) / 1.0).floor().clamp(0, 19);

      final prefix4 =
          '${_olcChars[latVal0]}${_olcChars[lngVal0]}${_olcChars[latVal1]}${_olcChars[lngVal1]}';

      // If short code has 4 chars before '+' (e.g. 2C26+P6G), prefix is 4 chars
      String fullCode;
      if (plusIndex == 4) {
        fullCode = '$prefix4$clean';
      } else if (plusIndex == 6) {
        // Missing only 2 prefix chars
        final prefix2 = '${_olcChars[latVal0]}${_olcChars[lngVal0]}';
        fullCode = '$prefix2$clean';
      } else {
        fullCode = '$prefix4$clean';
      }

      var point = decodeFullPlusCode(fullCode);
      if (point != null && isValidPhilippines(point)) {
        // Adjust for block boundaries if needed
        return point;
      }

      // Try adjacent 1-degree neighbor blocks if reference point is near a boundary
      for (final latOffset in [-1.0, 1.0, 0.0]) {
        for (final lngOffset in [-1.0, 1.0, 0.0]) {
          final adjLat = refLat + latOffset;
          final adjLng = refLng + lngOffset;
          final adjLat0 = ((adjLat + 90.0) / 20.0).floor().clamp(0, 19);
          final adjLng0 = ((adjLng + 180.0) / 20.0).floor().clamp(0, 19);
          final adjLat1 = (((adjLat + 90.0) % 20.0) / 1.0).floor().clamp(0, 19);
          final adjLng1 = (((adjLng + 180.0) % 20.0) / 1.0).floor().clamp(0, 19);
          final altPrefix =
              '${_olcChars[adjLat0]}${_olcChars[adjLng0]}${_olcChars[adjLat1]}${_olcChars[adjLng1]}';
          final altFull = '$altPrefix$clean';
          final candidate = decodeFullPlusCode(altFull);
          if (candidate != null && isValidPhilippines(candidate)) {
            return candidate;
          }
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. MASTER RESOLVER: ADDRESS / CITY / PLUS CODE / TRACKER -> COORDINATES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Resolves any location string (Plus Code, City name, Address, Coordinates)
  /// into a verified Philippine [MobilisMapPoint].
  ///
  /// Priority:
  /// 1. Embedded numeric coordinates (lat, lng)
  /// 2. In-memory cache
  /// 3. Plus Code (with locality-assisted decoding)
  /// 4. Known Philippine City / Municipality dictionary
  /// 5. Online Nominatim geocoding
  /// 6. Fallback to PSDC Garage / Reference point
  static Future<MobilisMapPoint> resolveLocation(
    dynamic locationValue, {
    dynamic latitudeValue,
    dynamic longitudeValue,
    String? referenceTown,
    MobilisMapPoint fallback = const MobilisMapPoint(
      latitude: defaultLat,
      longitude: defaultLng,
    ),
  }) async {
    // 1. Direct coordinates if provided and valid
    final direct = parseCoordinate(latitudeValue, longitudeValue);
    if (direct != null && isValidPhilippines(direct)) {
      return direct;
    }

    final raw = locationValue?.toString().trim() ?? '';
    if (raw.isEmpty) return fallback;

    // 2. Embedded numeric coordinates in string (e.g. "15.9987, 120.4021")
    final coordMatch = RegExp(
      r'(-?\d{1,2}(?:\.\d+)?)\s*[,/]\s*(-?\d{1,3}(?:\.\d+)?)',
    ).firstMatch(raw);
    if (coordMatch != null) {
      final point = parseCoordinate(coordMatch.group(1), coordMatch.group(2));
      if (point != null && isValidPhilippines(point)) {
        return point;
      }
    }

    final cacheKey = raw.toLowerCase();
    if (_cache.containsKey(cacheKey) && _cache[cacheKey] != null) {
      return _cache[cacheKey]!;
    }

    // 3. Extract locality reference from text for Plus Code resolving
    final refCoords = _findKnownCityInText(raw) ??
        (referenceTown != null ? _findKnownCityInText(referenceTown) : null) ??
        (defaultLat, defaultLng);

    // 4. Plus Code Decoding
    final plusCode = extractPlusCode(raw);
    if (plusCode != null) {
      final decoded = decodeShortPlusCode(
        plusCode,
        refLat: refCoords.$1,
        refLng: refCoords.$2,
      );
      if (decoded != null && isValidPhilippines(decoded)) {
        _cache[cacheKey] = decoded;
        return decoded;
      }
    }

    // 5. Known Philippine City / Municipality lookup
    final knownCity = _findKnownCityInText(raw);
    if (knownCity != null) {
      final point = MobilisMapPoint(
        latitude: knownCity.$1,
        longitude: knownCity.$2,
      );
      _cache[cacheKey] = point;
      return point;
    }

    // 6. Online OpenStreetMap Geocoding (with PH country code filter)
    final online = await _geocodeOnline(raw);
    if (online != null && isValidPhilippines(online)) {
      _cache[cacheKey] = online;
      return online;
    }

    return fallback;
  }

  /// Synchronous fast resolver (uses dictionary & Plus Code, skips online HTTP).
  static MobilisMapPoint resolveLocationSync(
    dynamic locationValue, {
    dynamic latitudeValue,
    dynamic longitudeValue,
    MobilisMapPoint fallback = const MobilisMapPoint(
      latitude: defaultLat,
      longitude: defaultLng,
    ),
  }) {
    final direct = parseCoordinate(latitudeValue, longitudeValue);
    if (direct != null && isValidPhilippines(direct)) {
      return direct;
    }

    final raw = locationValue?.toString().trim() ?? '';
    if (raw.isEmpty) return fallback;

    final cacheKey = raw.toLowerCase();
    if (_cache.containsKey(cacheKey) && _cache[cacheKey] != null) {
      return _cache[cacheKey]!;
    }

    final coordMatch = RegExp(
      r'(-?\d{1,2}(?:\.\d+)?)\s*[,/]\s*(-?\d{1,3}(?:\.\d+)?)',
    ).firstMatch(raw);
    if (coordMatch != null) {
      final point = parseCoordinate(coordMatch.group(1), coordMatch.group(2));
      if (point != null && isValidPhilippines(point)) {
        _cache[cacheKey] = point;
        return point;
      }
    }

    final refCoords = _findKnownCityInText(raw) ?? (defaultLat, defaultLng);
    final plusCode = extractPlusCode(raw);
    if (plusCode != null) {
      final decoded = decodeShortPlusCode(
        plusCode,
        refLat: refCoords.$1,
        refLng: refCoords.$2,
      );
      if (decoded != null && isValidPhilippines(decoded)) {
        _cache[cacheKey] = decoded;
        return decoded;
      }
    }

    final knownCity = _findKnownCityInText(raw);
    if (knownCity != null) {
      final point = MobilisMapPoint(
        latitude: knownCity.$1,
        longitude: knownCity.$2,
      );
      _cache[cacheKey] = point;
      return point;
    }

    return fallback;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. HELPER UTILITIES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Checks if a [MobilisMapPoint] falls within the Philippine geographical bounds.
  static bool isValidPhilippines(MobilisMapPoint? point) {
    if (point == null) return false;
    // Reject Null Island (0,0) or near-zero
    if (point.latitude.abs() < 0.001 && point.longitude.abs() < 0.001) {
      return false;
    }
    return point.latitude >= 4.5 &&
        point.latitude <= 21.5 &&
        point.longitude >= 116.5 &&
        point.longitude <= 127.0;
  }

  /// Parses latitude and longitude from dynamic values, trying both orders.
  static MobilisMapPoint? parseCoordinate(dynamic latVal, dynamic lngVal) {
    if (latVal == null || lngVal == null) return null;
    final lat = double.tryParse(latVal.toString().trim());
    final lng = double.tryParse(lngVal.toString().trim());
    if (lat == null || lng == null) return null;

    final p1 = MobilisMapPoint(latitude: lat, longitude: lng);
    if (isValidPhilippines(p1)) return p1;

    // Try swapped (in case coordinates were saved as lon, lat)
    final p2 = MobilisMapPoint(latitude: lng, longitude: lat);
    if (isValidPhilippines(p2)) return p2;

    return null;
  }

  /// Finds any known city / municipality name within a text string.
  static (double, double)? _findKnownCityInText(String text) {
    final lower = text.toLowerCase();

    // Check longer matching names first to avoid partial matches
    final entries = _knownLocations.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));

    for (final entry in entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Asynchronously queries OpenStreetMap Nominatim with caching.
  static Future<MobilisMapPoint?> _geocodeOnline(String query) async {
    try {
      // Strip leading plus code for better Nominatim search if text contains both
      var cleanQuery = query;
      final plusCode = extractPlusCode(query);
      if (plusCode != null) {
        cleanQuery = query.replaceAll(plusCode, '').replaceAll(',', ' ').trim();
      }
      if (cleanQuery.isEmpty) cleanQuery = query;

      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': cleanQuery,
        'format': 'jsonv2',
        'limit': '1',
        'countrycodes': 'ph',
      });

      final res = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'MobilisApp/1.0',
        },
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final list = jsonDecode(res.body);
        if (list is List && list.isNotEmpty && list.first is Map) {
          final map = list.first as Map;
          final lat = double.tryParse(map['lat']?.toString() ?? '');
          final lon = double.tryParse(map['lon']?.toString() ?? '');
          if (lat != null && lon != null) {
            final point = MobilisMapPoint(latitude: lat, longitude: lon);
            if (isValidPhilippines(point)) return point;
          }
        }
      }
    } catch (_) {
      // Ignore network errors and fallback
    }
    return null;
  }

  /// Calculates geodesic distance between two points in kilometers.
  static double distanceKm(MobilisMapPoint a, MobilisMapPoint b) {
    const earthRadiusKm = 6371.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180.0;
    final dLon = (b.longitude - a.longitude) * math.pi / 180.0;
    final lat1 = a.latitude * math.pi / 180.0;
    final lat2 = b.latitude * math.pi / 180.0;

    final sinDLat2 = math.sin(dLat / 2);
    final sinDLon2 = math.sin(dLon / 2);
    final h = sinDLat2 * sinDLat2 + math.cos(lat1) * math.cos(lat2) * sinDLon2 * sinDLon2;
    return earthRadiusKm * 2 * math.asin(math.sqrt(h.clamp(0.0, 1.0)));
  }
}
