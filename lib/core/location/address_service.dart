// lib/core/location/address_service.dart
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';

// ============================================================================
// ÚJ KÖZPONTI CÍMTISZTÍTÓ MOTOR
// ============================================================================
class AddressCleaner {
  static String clean(String raw, bool showCity) {
    if (raw.trim().isEmpty) return '';
    if (raw == 'Unknown location' || raw == 'Locație necunoscută') return raw;

    // Vesszők mentén darabokra szedjük a nyers címet
    List<String> parts = raw.split(',').map((e) => e.trim()).toList();
    if (parts.isEmpty) return '';

    // --- 1. INTELLIGENS HELYNÉV FELISMERŐ ---
    // Megnézzük a legelső elemet (pl. "Hotel Radisson Blu" vagy "OMV Station")
    final firstPartLower = parts[0].toLowerCase();
    final isPlace = firstPartLower.contains('hotel') ||
        firstPartLower.contains('pensiune') ||
        firstPartLower.contains('panzió') ||
        firstPartLower.contains('panzio') ||
        firstPartLower.contains('motel') ||
        firstPartLower.contains('omv') ||
        firstPartLower.contains('mol') ||
        firstPartLower.contains('petrom') ||
        firstPartLower.contains('rompetrol') ||
        firstPartLower.contains('lukoil') ||
        firstPartLower.contains('socar') ||
        firstPartLower.contains('peco') ||
        firstPartLower.contains('airport') ||
        firstPartLower.contains('aeroport') ||
        firstPartLower.contains('kaufland') ||
        firstPartLower.contains('lidl') ||
        firstPartLower.contains('auchan') ||
        firstPartLower.contains('carrefour') ||
        firstPartLower.contains('penny') ||
        firstPartLower.contains('profi') ||
        firstPartLower.contains('mega image');

    if (isPlace) {
      // Ha ez egy ismert hely, eldobunk minden utótagot (utca, szám, város)!
      // Példa: "Hotel Radisson Blu, Aleea Stadionului 1, Cluj" -> "Hotel Radisson Blu"
      return parts[0];
    }

    // --- 2. HA NORMÁL UTCA/CÍM ---
    // Alapvető rövidítések beállítása
    String text = raw.trim();
    text = text.replaceAll(RegExp(r'\bStrada\b', caseSensitive: false), 'Str.');
    text = text.replaceAll(RegExp(r'\bBulevardul\b', caseSensitive: false), 'Bd.');
    text = text.replaceAll(RegExp(r'\bBd\.\b', caseSensitive: false), 'Bd.');

    parts = text.split(',').map((e) => e.trim()).toList();

    // Kíméletlenül kidobjuk az irányítószámokat és az országot!
    parts = parts.where((p) {
      if (RegExp(r'^\d{4,6}$').hasMatch(p)) return false; // Irányítószám -> KUKA
      final up = p.toUpperCase();
      if (['ROU', 'ROMANIA', 'ROMÂNIA', 'HU', 'HUN', 'MAGYARORSZÁG'].contains(up)) return false; // Ország -> KUKA
      return true;
    }).toList();

    if (parts.isEmpty) return '';

    // Beállítás szerinti intelligens vágás
    if (showCity) {
      // Ha kéri a várost, maximum 3 adatot hagyunk meg (Név, Utca, Város)
      if (parts.length > 3) parts = parts.sublist(0, 3);
    } else {
      // Ha NEM kéri a várost, szigorúbban vágunk:
      if (parts.length >= 3) {
        // Ha van Név + Utca + Város -> Marad: Név + Utca
        parts = parts.sublist(0, 2);
      } else if (parts.length == 2) {
        // Ha csak Utca + Város van -> Marad: Utca
        parts = parts.sublist(0, 1);
      }
    }

    return parts.join(', ');
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
        '&radius=10'
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
      final name = (placemark.name ?? '').trim();
      final city = (placemark.locality ?? '').trim();

      if (street.isNotEmpty && houseNumber.isNotEmpty) {
        return '$street $houseNumber, $city';
      }

      if (street.isNotEmpty) {
        return '$street, $city';
      }

      if (name.isNotEmpty) {
        return '$name, $city';
      }

      if (city.isNotEmpty) {
        return city;
      }

      return 'unknown_location'.tr();
    } catch (_) {
      return 'unknown_location'.tr();
    }
  }
}