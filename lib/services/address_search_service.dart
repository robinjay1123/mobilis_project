import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

/// Represents an address or location suggestion returned by [AddressSearchService].
class AddressSuggestion {
  final String title;
  final String subtitle;
  final String fullAddress;
  final double latitude;
  final double longitude;

  const AddressSuggestion({
    required this.title,
    required this.subtitle,
    required this.fullAddress,
    required this.latitude,
    required this.longitude,
  });

  @override
  String toString() => '$title ($subtitle)';
}

/// Fast, resilient address autocomplete search service tailored for the Philippines.
///
/// Features:
/// 1. Instant 0ms local Philippine city/municipality matching so users see suggestions immediately.
/// 2. Live online OpenStreetMap Nominatim geocoding restricted to the Philippines (`countrycodes: ph`).
/// 3. Geocoding package fallback if online Nominatim is unavailable.
/// 4. In-memory caching and deduplication.
class AddressSearchService {
  static final AddressSearchService _instance = AddressSearchService._internal();
  factory AddressSearchService() => _instance;
  AddressSearchService._internal();

  static final Map<String, List<AddressSuggestion>> _cache = {};

  // Comprehensive Philippine locations registry for instant zero-latency suggestions
  static const List<AddressSuggestion> _presetPhilippineCities = [
    // Pangasinan & Northern Luzon
    AddressSuggestion(
      title: 'Urdaneta City',
      subtitle: 'Pangasinan, Ilocos Region',
      fullAddress: 'Urdaneta City, Pangasinan, Philippines',
      latitude: 15.9758,
      longitude: 120.5719,
    ),
    AddressSuggestion(
      title: 'Dagupan City',
      subtitle: 'Pangasinan, Ilocos Region',
      fullAddress: 'Dagupan City, Pangasinan, Philippines',
      latitude: 16.0433,
      longitude: 120.3333,
    ),
    AddressSuggestion(
      title: 'San Carlos City',
      subtitle: 'Pangasinan, Ilocos Region',
      fullAddress: 'San Carlos City, Pangasinan, Philippines',
      latitude: 15.9281,
      longitude: 120.3488,
    ),
    AddressSuggestion(
      title: 'Santa Barbara',
      subtitle: 'Pangasinan, Ilocos Region',
      fullAddress: 'Santa Barbara, Pangasinan, Philippines',
      latitude: 15.9987,
      longitude: 120.4021,
    ),
    AddressSuggestion(
      title: 'Lingayen',
      subtitle: 'Pangasinan, Ilocos Region',
      fullAddress: 'Lingayen, Pangasinan, Philippines',
      latitude: 16.0218,
      longitude: 120.2319,
    ),
    AddressSuggestion(
      title: 'Calasiao',
      subtitle: 'Pangasinan, Ilocos Region',
      fullAddress: 'Calasiao, Pangasinan, Philippines',
      latitude: 16.0125,
      longitude: 120.3589,
    ),
    AddressSuggestion(
      title: 'Malasiqui',
      subtitle: 'Pangasinan, Ilocos Region',
      fullAddress: 'Malasiqui, Pangasinan, Philippines',
      latitude: 15.9197,
      longitude: 120.4144,
    ),
    AddressSuggestion(
      title: 'Alaminos City',
      subtitle: 'Pangasinan, Ilocos Region',
      fullAddress: 'Alaminos City, Pangasinan, Philippines',
      latitude: 16.1558,
      longitude: 119.9806,
    ),
    AddressSuggestion(
      title: 'Rosales',
      subtitle: 'Pangasinan, Ilocos Region',
      fullAddress: 'Rosales, Pangasinan, Philippines',
      latitude: 15.8922,
      longitude: 120.5975,
    ),
    AddressSuggestion(
      title: 'Binalonan',
      subtitle: 'Pangasinan, Ilocos Region',
      fullAddress: 'Binalonan, Pangasinan, Philippines',
      latitude: 16.0483,
      longitude: 120.5936,
    ),
    AddressSuggestion(
      title: 'Bayambang',
      subtitle: 'Pangasinan, Ilocos Region',
      fullAddress: 'Bayambang, Pangasinan, Philippines',
      latitude: 15.8127,
      longitude: 120.4557,
    ),
    AddressSuggestion(
      title: 'Mangaldan',
      subtitle: 'Pangasinan, Ilocos Region',
      fullAddress: 'Mangaldan, Pangasinan, Philippines',
      latitude: 16.0708,
      longitude: 120.4028,
    ),
    AddressSuggestion(
      title: 'Baguio City',
      subtitle: 'Benguet, Cordillera Administrative Region',
      fullAddress: 'Baguio City, Benguet, Philippines',
      latitude: 16.4023,
      longitude: 120.5960,
    ),
    AddressSuggestion(
      title: 'La Trinidad',
      subtitle: 'Benguet, Cordillera Administrative Region',
      fullAddress: 'La Trinidad, Benguet, Philippines',
      latitude: 16.4556,
      longitude: 120.5878,
    ),
    AddressSuggestion(
      title: 'San Fernando City',
      subtitle: 'La Union, Ilocos Region',
      fullAddress: 'San Fernando City, La Union, Philippines',
      latitude: 16.6159,
      longitude: 120.3209,
    ),
    AddressSuggestion(
      title: 'Vigan City',
      subtitle: 'Ilocos Sur, Ilocos Region',
      fullAddress: 'Vigan City, Ilocos Sur, Philippines',
      latitude: 17.5747,
      longitude: 120.3869,
    ),
    AddressSuggestion(
      title: 'Laoag City',
      subtitle: 'Ilocos Norte, Ilocos Region',
      fullAddress: 'Laoag City, Ilocos Norte, Philippines',
      latitude: 18.1960,
      longitude: 120.5927,
    ),
    AddressSuggestion(
      title: 'Tarlac City',
      subtitle: 'Tarlac, Central Luzon',
      fullAddress: 'Tarlac City, Tarlac, Philippines',
      latitude: 15.4802,
      longitude: 120.5979,
    ),
    AddressSuggestion(
      title: 'Capas',
      subtitle: 'Tarlac, Central Luzon',
      fullAddress: 'Capas, Tarlac, Philippines',
      latitude: 15.3333,
      longitude: 120.5833,
    ),
    AddressSuggestion(
      title: 'Angeles City',
      subtitle: 'Pampanga, Central Luzon',
      fullAddress: 'Angeles City, Pampanga, Philippines',
      latitude: 15.1450,
      longitude: 120.5887,
    ),
    AddressSuggestion(
      title: 'San Fernando City',
      subtitle: 'Pampanga, Central Luzon',
      fullAddress: 'San Fernando City, Pampanga, Philippines',
      latitude: 15.0342,
      longitude: 120.6850,
    ),
    AddressSuggestion(
      title: 'Mabalacat City',
      subtitle: 'Pampanga, Central Luzon',
      fullAddress: 'Mabalacat City, Pampanga, Philippines',
      latitude: 15.2167,
      longitude: 120.5833,
    ),
    AddressSuggestion(
      title: 'Clark Freeport Zone',
      subtitle: 'Pampanga, Central Luzon',
      fullAddress: 'Clark Freeport Zone, Pampanga, Philippines',
      latitude: 15.1850,
      longitude: 120.5430,
    ),
    AddressSuggestion(
      title: 'Cabanatuan City',
      subtitle: 'Nueva Ecija, Central Luzon',
      fullAddress: 'Cabanatuan City, Nueva Ecija, Philippines',
      latitude: 15.4864,
      longitude: 120.9733,
    ),
    AddressSuggestion(
      title: 'Olongapo City',
      subtitle: 'Zambales, Central Luzon',
      fullAddress: 'Olongapo City, Zambales, Philippines',
      latitude: 14.8386,
      longitude: 120.2842,
    ),
    AddressSuggestion(
      title: 'Subic Bay',
      subtitle: 'Zambales, Central Luzon',
      fullAddress: 'Subic, Zambales, Philippines',
      latitude: 14.8789,
      longitude: 120.2356,
    ),

    // Metro Manila / NCR
    AddressSuggestion(
      title: 'Manila',
      subtitle: 'Metro Manila, Philippines',
      fullAddress: 'City of Manila, Metro Manila, Philippines',
      latitude: 14.5995,
      longitude: 120.9842,
    ),
    AddressSuggestion(
      title: 'Quezon City',
      subtitle: 'Metro Manila, Philippines',
      fullAddress: 'Quezon City, Metro Manila, Philippines',
      latitude: 14.6760,
      longitude: 121.0437,
    ),
    AddressSuggestion(
      title: 'Makati City',
      subtitle: 'Metro Manila, Philippines',
      fullAddress: 'Makati City, Metro Manila, Philippines',
      latitude: 14.5547,
      longitude: 121.0244,
    ),
    AddressSuggestion(
      title: 'Taguig City (BGC)',
      subtitle: 'Metro Manila, Philippines',
      fullAddress: 'Taguig City, Metro Manila, Philippines',
      latitude: 14.5176,
      longitude: 121.0509,
    ),
    AddressSuggestion(
      title: 'Pasig City',
      subtitle: 'Metro Manila, Philippines',
      fullAddress: 'Pasig City, Metro Manila, Philippines',
      latitude: 14.5764,
      longitude: 121.0851,
    ),
    AddressSuggestion(
      title: 'Mandaluyong City',
      subtitle: 'Metro Manila, Philippines',
      fullAddress: 'Mandaluyong City, Metro Manila, Philippines',
      latitude: 14.5794,
      longitude: 121.0359,
    ),
    AddressSuggestion(
      title: 'Parañaque City',
      subtitle: 'Metro Manila, Philippines',
      fullAddress: 'Parañaque City, Metro Manila, Philippines',
      latitude: 14.4793,
      longitude: 121.0198,
    ),
    AddressSuggestion(
      title: 'Pasay City',
      subtitle: 'Metro Manila, Philippines',
      fullAddress: 'Pasay City, Metro Manila, Philippines',
      latitude: 14.5378,
      longitude: 121.0014,
    ),
    AddressSuggestion(
      title: 'Caloocan City',
      subtitle: 'Metro Manila, Philippines',
      fullAddress: 'Caloocan City, Metro Manila, Philippines',
      latitude: 14.6488,
      longitude: 120.9678,
    ),
    AddressSuggestion(
      title: 'Las Piñas City',
      subtitle: 'Metro Manila, Philippines',
      fullAddress: 'Las Piñas City, Metro Manila, Philippines',
      latitude: 14.4445,
      longitude: 120.9939,
    ),
    AddressSuggestion(
      title: 'Muntinlupa City (Alabang)',
      subtitle: 'Metro Manila, Philippines',
      fullAddress: 'Muntinlupa City, Metro Manila, Philippines',
      latitude: 14.4081,
      longitude: 121.0415,
    ),
    AddressSuggestion(
      title: 'Marikina City',
      subtitle: 'Metro Manila, Philippines',
      fullAddress: 'Marikina City, Metro Manila, Philippines',
      latitude: 14.6507,
      longitude: 121.1029,
    ),

    // Southern Luzon
    AddressSuggestion(
      title: 'Antipolo City',
      subtitle: 'Rizal, Calabarzon',
      fullAddress: 'Antipolo City, Rizal, Philippines',
      latitude: 14.5842,
      longitude: 121.1764,
    ),
    AddressSuggestion(
      title: 'Bacoor City',
      subtitle: 'Cavite, Calabarzon',
      fullAddress: 'Bacoor City, Cavite, Philippines',
      latitude: 14.4624,
      longitude: 120.9645,
    ),
    AddressSuggestion(
      title: 'Dasmariñas City',
      subtitle: 'Cavite, Calabarzon',
      fullAddress: 'Dasmariñas City, Cavite, Philippines',
      latitude: 14.3294,
      longitude: 120.9367,
    ),
    AddressSuggestion(
      title: 'Tagaytay City',
      subtitle: 'Cavite, Calabarzon',
      fullAddress: 'Tagaytay City, Cavite, Philippines',
      latitude: 14.1153,
      longitude: 120.9621,
    ),
    AddressSuggestion(
      title: 'Calamba City',
      subtitle: 'Laguna, Calabarzon',
      fullAddress: 'Calamba City, Laguna, Philippines',
      latitude: 14.2117,
      longitude: 121.1656,
    ),
    AddressSuggestion(
      title: 'Santa Rosa City',
      subtitle: 'Laguna, Calabarzon',
      fullAddress: 'Santa Rosa City, Laguna, Philippines',
      latitude: 14.3122,
      longitude: 121.1114,
    ),
    AddressSuggestion(
      title: 'Batangas City',
      subtitle: 'Batangas, Calabarzon',
      fullAddress: 'Batangas City, Batangas, Philippines',
      latitude: 13.7565,
      longitude: 121.0583,
    ),
    AddressSuggestion(
      title: 'Lipa City',
      subtitle: 'Batangas, Calabarzon',
      fullAddress: 'Lipa City, Batangas, Philippines',
      latitude: 13.9419,
      longitude: 121.1644,
    ),

    // Visayas
    AddressSuggestion(
      title: 'Cebu City',
      subtitle: 'Cebu, Central Visayas',
      fullAddress: 'Cebu City, Cebu, Philippines',
      latitude: 10.3157,
      longitude: 123.8854,
    ),
    AddressSuggestion(
      title: 'Mandaue City',
      subtitle: 'Cebu, Central Visayas',
      fullAddress: 'Mandaue City, Cebu, Philippines',
      latitude: 10.3333,
      longitude: 123.9333,
    ),
    AddressSuggestion(
      title: 'Lapu-Lapu City',
      subtitle: 'Cebu, Central Visayas',
      fullAddress: 'Lapu-Lapu City, Cebu, Philippines',
      latitude: 10.3103,
      longitude: 123.9494,
    ),
    AddressSuggestion(
      title: 'Iloilo City',
      subtitle: 'Iloilo, Western Visayas',
      fullAddress: 'Iloilo City, Iloilo, Philippines',
      latitude: 10.7202,
      longitude: 122.5621,
    ),
    AddressSuggestion(
      title: 'Bacolod City',
      subtitle: 'Negros Occidental, Western Visayas',
      fullAddress: 'Bacolod City, Negros Occidental, Philippines',
      latitude: 10.6766,
      longitude: 122.9511,
    ),
    AddressSuggestion(
      title: 'Tacloban City',
      subtitle: 'Leyte, Eastern Visayas',
      fullAddress: 'Tacloban City, Leyte, Philippines',
      latitude: 11.2433,
      longitude: 125.0039,
    ),

    // Mindanao
    AddressSuggestion(
      title: 'Davao City',
      subtitle: 'Davao del Sur, Davao Region',
      fullAddress: 'Davao City, Davao del Sur, Philippines',
      latitude: 7.1907,
      longitude: 125.4504,
    ),
    AddressSuggestion(
      title: 'Tagum City',
      subtitle: 'Davao del Norte, Davao Region',
      fullAddress: 'Tagum City, Davao del Norte, Philippines',
      latitude: 7.4478,
      longitude: 125.8078,
    ),
    AddressSuggestion(
      title: 'Panabo City',
      subtitle: 'Davao del Norte, Davao Region',
      fullAddress: 'Panabo City, Davao del Norte, Philippines',
      latitude: 7.3000,
      longitude: 125.6833,
    ),
    AddressSuggestion(
      title: 'Digos City',
      subtitle: 'Davao del Sur, Davao Region',
      fullAddress: 'Digos City, Davao del Sur, Philippines',
      latitude: 6.7500,
      longitude: 125.3500,
    ),
    AddressSuggestion(
      title: 'Cagayan de Oro City',
      subtitle: 'Misamis Oriental, Northern Mindanao',
      fullAddress: 'Cagayan de Oro City, Misamis Oriental, Philippines',
      latitude: 8.4542,
      longitude: 124.6319,
    ),
    AddressSuggestion(
      title: 'General Santos City',
      subtitle: 'South Cotabato, Soccsksargen',
      fullAddress: 'General Santos City, South Cotabato, Philippines',
      latitude: 6.1164,
      longitude: 125.1716,
    ),
    AddressSuggestion(
      title: 'Zamboanga City',
      subtitle: 'Zamboanga Peninsula',
      fullAddress: 'Zamboanga City, Zamboanga del Sur, Philippines',
      latitude: 6.9214,
      longitude: 122.0790,
    ),
    AddressSuggestion(
      title: 'Puerto Princesa City',
      subtitle: 'Palawan, Mimaropa',
      fullAddress: 'Puerto Princesa City, Palawan, Philippines',
      latitude: 9.7392,
      longitude: 118.7353,
    ),
  ];

  /// Searches address suggestions using instant local matching and online OpenStreetMap geocoding.
  Future<List<AddressSuggestion>> getSuggestions(String query) async {
    final clean = query.trim();
    if (clean.length < 2) return const [];

    final cacheKey = clean.toLowerCase();
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final results = <AddressSuggestion>[];
    final seenCoords = <String>{};

    void addResult(AddressSuggestion item) {
      final key = '${item.latitude.toStringAsFixed(3)}_${item.longitude.toStringAsFixed(3)}';
      if (!seenCoords.contains(key)) {
        seenCoords.add(key);
        results.add(item);
      }
    }

    // 1. Instant local preset matching (0ms latency)
    final lowerQuery = clean.toLowerCase();
    for (final preset in _presetPhilippineCities) {
      final matchTitle = preset.title.toLowerCase().contains(lowerQuery);
      final matchSubtitle = preset.subtitle.toLowerCase().contains(lowerQuery);
      if (matchTitle || matchSubtitle) {
        addResult(preset);
      }
      if (results.length >= 5) break;
    }

    // 2. Online OpenStreetMap Nominatim search for specific streets, barangays, and addresses
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': clean,
        'format': 'jsonv2',
        'limit': '6',
        'countrycodes': 'ph',
        'addressdetails': '1',
      });

      final response = await http
          .get(
            uri,
            headers: const {
              'Accept': 'application/json',
              'Accept-Language': 'en',
              'User-Agent': 'MobilisApp/1.0 (contact@mobilis.ph)',
            },
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body);
        if (list is List) {
          for (final item in list) {
            if (item is! Map) continue;
            final lat = double.tryParse(item['lat']?.toString() ?? '');
            final lon = double.tryParse(item['lon']?.toString() ?? '');
            if (lat == null || lon == null) continue;

            if (!_isValidPhilippines(lat, lon)) continue;

            final displayName = item['display_name']?.toString() ?? '';
            final name = item['name']?.toString() ?? '';
            final parts = displayName.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();

            final title = name.isNotEmpty
                ? name
                : (parts.isNotEmpty ? parts.first : clean);

            // Build clean subtitle without repeating title
            final subtitleParts = parts.where((p) => p != title && p != 'Philippines').toList();
            final subtitle = subtitleParts.isNotEmpty
                ? subtitleParts.take(3).join(', ')
                : 'Philippines';

            addResult(
              AddressSuggestion(
                title: title,
                subtitle: subtitle,
                fullAddress: displayName.isNotEmpty ? displayName : '$title, $subtitle',
                latitude: lat,
                longitude: lon,
              ),
            );

            if (results.length >= 8) break;
          }
        }
      }
    } catch (e) {
      debugPrint('Nominatim suggestion query note: $e');
    }

    // 3. Device Geocoding package fallback if results are still sparse
    if (results.length < 2) {
      try {
        final locations = await locationFromAddress(clean);
        if (locations.isNotEmpty) {
          final loc = locations.first;
          if (_isValidPhilippines(loc.latitude, loc.longitude)) {
            addResult(
              AddressSuggestion(
                title: clean,
                subtitle: 'Philippines',
                fullAddress: clean,
                latitude: loc.latitude,
                longitude: loc.longitude,
              ),
            );
          }
        }
      } catch (_) {}
    }

    // Keep cache bounded
    if (_cache.length > 50) {
      _cache.remove(_cache.keys.first);
    }
    _cache[cacheKey] = results;

    return results;
  }

  static bool _isValidPhilippines(double lat, double lon) {
    if (lat.abs() < 0.001 && lon.abs() < 0.001) return false;
    return lat >= 4.5 && lat <= 21.5 && lon >= 116.5 && lon <= 127.0;
  }
}
