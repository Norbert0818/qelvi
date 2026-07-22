// lib/core/location/address_service.dart
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';

class AddressCleaner {
  static String clean(String raw, bool showCity) {
    if (raw.trim().isEmpty) return '';
    if (raw == 'Unknown location' || raw == 'Locație necunoscută') return raw;

    String text = raw.trim();
    text = text.replaceAll(RegExp(r'\bStrada\b', caseSensitive: false), 'Str.');
    text = text.replaceAll(RegExp(r'\bBulevardul\b', caseSensitive: false), 'Bd.');
    text = text.replaceAll(RegExp(r'\bBd\.\b', caseSensitive: false), 'Bd.');

    List<String> parts = text.split(',').map((e) => e.trim()).toList();

    final containsKeywords = [
      'hotel', 'pensiune', 'panzió', 'panzio', 'motel', 'hostel', 'resort',
      'petrom', 'rompetrol', 'lukoil', 'socar',
      'airport', 'aeroport', 'kaufland', 'lidl', 'auchan', 'carrefour', 'penny', 'profi', 'mega image'
    ];
    final exactMatchKeywords = ['omv', 'mol', 'peco', 'gaz'];

    for (String part in parts) {
      final pLower = part.toLowerCase();

      for (String kw in containsKeywords) {
        if (pLower.contains(kw)) {
          return part;
        }
      }

      for (String kw in exactMatchKeywords) {
        if (RegExp('\\b$kw\\b').hasMatch(pLower)) {
          return part;
        }
      }
    }

    parts = parts.where((p) {
      if (RegExp(r'^\d{4,6}$').hasMatch(p)) return false;
      final up = p.toUpperCase();
      if (['ROU', 'ROMANIA', 'ROMÂNIA', 'HU', 'HUN', 'MAGYARORSZÁG'].contains(up)) return false;
      return true;
    }).toList();

    if (parts.isEmpty) return '';

    if (!showCity) {
      bool firstIsStreet = RegExp(r'\d').hasMatch(parts[0]) ||
          parts[0].toLowerCase().startsWith('str.') ||
          parts[0].toLowerCase().startsWith('bd.') ||
          parts[0].toLowerCase().startsWith('calea') ||
          parts[0].toLowerCase().startsWith('piața') ||
          parts[0].toLowerCase().startsWith('dn') ||
          parts[0].toLowerCase().startsWith('dj') ||
          parts[0].toLowerCase().startsWith('dc');

      if (firstIsStreet) {
        return parts[0];
      } else {
        if (parts.length >= 2) return '${parts[0]}, ${parts[1]}';
        return parts[0];
      }
    } else {
      if (parts.length > 3) return parts.sublist(0, 3).join(', ');
      return parts.join(', ');
    }
  }
}

class AddressService {
  Future<String> resolveAddress(Position pos) async {
    final prefs = await SharedPreferences.getInstance();
    final showCity = prefs.getBool('show_city_in_trips') ?? true;

    final placeName = await _tryResolvePlaceName(pos);
    if (placeName != null && placeName.trim().isNotEmpty) {
      return AddressCleaner.clean(placeName, showCity);
    }

    final reverseGeo = await _reverseGeocodeShort(pos);
    return AddressCleaner.clean(reverseGeo, showCity);
  }

  Future<String?> _tryResolvePlaceName(Position pos) async {
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
    if (apiKey.isEmpty) return null;

    final url =
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
        '?location=${pos.latitude},${pos.longitude}'
        '&radius=60'
        '&key=$apiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = (data['results'] as List?) ?? [];

      for (final item in results) {
        final place = Map<String, dynamic>.from(item as Map);
        final types = ((place['types'] as List?) ?? []).cast<String>();
        final rawName = (place['name'] as String?)?.trim() ?? '';
        final name = rawName.toLowerCase();

        final isPreferredPlace =
            types.contains('lodging') ||
                types.contains('gas_station') ||
                types.contains('airport') ||
                types.contains('hotel') ||
                name.contains('hotel') ||
                name.contains('omv') ||
                name.contains('pensiune') ||
                name.contains('motel') ||
                name.contains('airport');

        if (isPreferredPlace && rawName.isNotEmpty) {
          return rawName;
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<String> _reverseGeocodeShort(Position pos) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );

      if (placemarks.isEmpty) return 'unknown_location'.tr();

      final placemark = placemarks.first;

      final street = (placemark.thoroughfare ?? placemark.street ?? '').trim();
      final houseNumber = (placemark.subThoroughfare ?? '').trim();
      String name = (placemark.name ?? '').trim();
      final city = (placemark.locality ?? '').trim();

      if (name.contains('+') || name.length <= 3) {
        name = '';
      }

      List<String> combined = [];

      if (name.isNotEmpty && name != street) combined.add(name);

      String streetFull = '$street $houseNumber'.trim();
      if (streetFull.isNotEmpty) combined.add(streetFull);
      if (city.isNotEmpty) combined.add(city);

      if (combined.isNotEmpty) {
        return combined.join(', ');
      }

      return 'unknown_location'.tr();
    } catch (_) {
      return 'unknown_location'.tr();
    }
  }
}