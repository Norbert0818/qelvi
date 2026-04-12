import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class AddressService {
  Future<String> resolveAddress(Position pos) async {
    final placeName = await _tryResolvePlaceName(pos);
    if (placeName != null && placeName.trim().isNotEmpty) {
      return placeName;
    }

    return _reverseGeocodeShort(pos);
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

      if (placemarks.isEmpty) return 'Unknown location';

      final placemark = placemarks.first;

      final street = (placemark.thoroughfare ?? placemark.street ?? '').trim();
      final houseNumber = (placemark.subThoroughfare ?? '').trim();
      final name = (placemark.name ?? '').trim();
      final city = (placemark.locality ?? '').trim();

      if (street.isNotEmpty && houseNumber.isNotEmpty) {
        return _normalizeShortAddress('$street $houseNumber');
      }

      if (street.isNotEmpty) {
        return _normalizeShortAddress(street);
      }

      if (name.isNotEmpty) {
        return _normalizeShortAddress(name);
      }

      if (city.isNotEmpty) {
        return city;
      }

      return 'Unknown location';
    } catch (_) {
      return 'Unknown location';
    }
  }

  String _normalizeShortAddress(String value) {
    var text = value.trim();

    text = text.replaceAll(
      RegExp(r'\bStrada\b', caseSensitive: false),
      'str.',
    );

    text = text.replaceAll(
      RegExp(r'\bBulevardul\b', caseSensitive: false),
      'bd.',
    );

    text = text.replaceAll(
      RegExp(r'\bBd\.\b', caseSensitive: false),
      'bd.',
    );

    text = text.replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    return text.trim();
  }
}