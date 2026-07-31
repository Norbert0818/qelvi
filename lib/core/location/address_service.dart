// lib/core/location/address_service.dart
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:easy_localization/easy_localization.dart';

class AddressCleaner {
  // --- TELJES ROMÁN ÉS MAGYAR MEGYE LISTA A BIZTOS SZŰRÉSHEZ ---
  static const _counties = {
    // Román megyék
    'alba', 'arad', 'argeș', 'arges', 'bacău', 'bacau', 'bihor', 'bistrița-năsăud', 'bistrita-nasaud',
    'botoșani', 'botosani', 'brașov', 'brasov', 'brăila', 'braila', 'buzău', 'buzau', 'caraș-severin',
    'caras-severin', 'călărași', 'calarasi', 'cluj', 'constanța', 'constanta', 'covasna', 'dâmbovița',
    'dambovita', 'dolj', 'galați', 'galati', 'giurgiu', 'gorj', 'harghita', 'hunedoara', 'ialomița',
    'ialomita', 'iași', 'iasi', 'ilfov', 'maramureș', 'maramures', 'mehedinți', 'mehedinti', 'mureș',
    'mures', 'neamț', 'neamt', 'olt', 'prahova', 'satu mare', 'sălaj', 'salaj', 'sibiu', 'suceava',
    'teleorman', 'timiș', 'timis', 'tulcea', 'vaslui', 'vâlcea', 'valcea', 'vrancea', 'bucurești', 'bucuresti',
    // Magyar megyék
    'bács-kiskun', 'baranya', 'békés', 'bekes', 'borsod-abaúj-zemplén', 'borsod-abauj-zemplen',
    'csongrád-csanád', 'csongrad-csanad', 'csongrád', 'csongrad', 'fejér', 'fejer', 'győr-moson-sopron',
    'gyor-moson-sopron', 'hajdú-bihar', 'hajdu-bihar', 'heves', 'jász-nagykun-szolnok', 'jasz-nagykun-szolnok',
    'komárom-esztergom', 'komarom-esztergom', 'nógrád', 'nograd', 'pest', 'somogy', 'szabolcs-szatmár-bereg',
    'szabolcs-szatmar-bereg', 'tolna', 'vas', 'veszprém', 'veszprem', 'zala', 'budapest'
  };

  static bool _isCounty(String text) {
    final cleanText = text.toLowerCase()
        .replaceAll('județul', '')
        .replaceAll('judetul', '')
        .replaceAll('jud.', '')
        .replaceAll('jud', '')
        .replaceAll('county', '')
        .replaceAll('megye', '')
        .trim();
    return _counties.contains(cleanText);
  }

  static String clean(String raw, bool showCity) {
    if (raw.trim().isEmpty) return '';
    if (raw == 'Unknown location' || raw == 'Locație necunoscută') return raw;

    String text = raw.trim();
    text = text.replaceAll(RegExp(r'\bStrada\b', caseSensitive: false), 'Str.');
    text = text.replaceAll(RegExp(r'\bBulevardul\b', caseSensitive: false), 'Bd.');
    text = text.replaceAll(RegExp(r'\bBd\.\b', caseSensitive: false), 'Bd.');

    // Feldaraboljuk a vesszőknél
    List<String> parts = text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    // 1. Kiemelt helyek (Hotel, benzinkút stb.) azonnali visszaadása
    final containsKeywords = [
      'hotel', 'pensiune', 'panzió', 'panzio', 'motel', 'hostel', 'resort',
      'petrom', 'rompetrol', 'lukoil', 'socar',
      'airport', 'aeroport', 'kaufland', 'lidl', 'auchan', 'carrefour', 'penny', 'profi', 'mega image'
    ];
    final exactMatchKeywords = ['omv', 'mol', 'peco', 'gaz'];

    for (String part in parts) {
      final pLower = part.toLowerCase();
      for (String kw in containsKeywords) {
        if (pLower.contains(kw)) return part;
      }
      for (String kw in exactMatchKeywords) {
        if (RegExp('\\b$kw\\b').hasMatch(pLower)) return part;
      }
    }

    // 2. Irányítószámok, országok és egyértelmű megye-szavak kiszűrése
    parts = parts.where((p) {
      if (RegExp(r'^\d{4,6}$').hasMatch(p)) return false;
      final up = p.toUpperCase();
      if (['ROU', 'ROMANIA', 'ROMÂNIA', 'HU', 'HUN', 'MAGYARORSZÁG'].contains(up)) return false;
      if (up.startsWith('JUDEȚUL ') || up.startsWith('JUD. ') || up.startsWith('JUD ')) return false;
      if (up.endsWith(' MEGYE') || up.endsWith(' JUDET')) return false;
      return true;
    }).toList();

    if (parts.isEmpty) return '';

    // 3. Megyék levágása a végéről
    while (parts.length >= 2 && _isCounty(parts.last)) {
      parts.removeLast();
    }

    // --- ÚJ JAVÍTÁS 4: Házszámok okos összeolvasztása az utcanévvel ---
    // Ha a következő rész egy házszám (pl. "95A", "nr. 10"), egyesítjük az előzővel vessző nélkül!
    for (int i = 0; i < parts.length - 1; i++) {
      final nextPart = parts[i + 1];
      if (RegExp(r'^((nr\.?\s*)?\d+[a-zA-Z]?(/[a-zA-Z0-9]+)?|f\.?n\.?)$', caseSensitive: false).hasMatch(nextPart)) {
        final cleanNum = nextPart.replaceAll(RegExp(r'^nr\.?\s*', caseSensitive: false), '');
        // Csak akkor adjuk hozzá, ha az utca még nem tartalmazza a házszámot a végén
        if (!parts[i].toLowerCase().endsWith(cleanNum.toLowerCase())) {
          parts[i] = '${parts[i]} $cleanNum'.trim();
        }
        parts.removeAt(i + 1);
        i--; // Visszalépünk, hátha van még valami
      }
    }

    // --- ÚJ JAVÍTÁS 5: Agrésszív duplikáció és rész-szöveg szűrés ---
    // Kiszedi a "95A"-t, ha már ott van mellette a "Bd. Mihai Viteazul 95A"
    final deduplicated = <String>[];
    for (int i = 0; i < parts.length; i++) {
      final p = parts[i];
      bool isContained = false;
      for (int j = 0; j < parts.length; j++) {
        if (i == j) continue;
        final other = parts[j];
        if (other.toLowerCase().contains(p.toLowerCase()) && p.length < other.length) {
          isContained = true;
          break;
        }
      }
      if (!isContained) {
        if (!deduplicated.any((d) => d.toLowerCase() == p.toLowerCase())) {
          deduplicated.add(p);
        }
      }
    }
    parts = deduplicated;

    if (parts.isEmpty) return '';

    // 6. Megjelenítés szabályozása (Excel vs. UI)
    // Most már a parts[0] MINDIG tartalmazza a házszámot is, mert összeolvasztottuk!
    if (!showCity) {
      return parts[0]; 
    } else {
      return parts.join(', ');
    }
  }
}

class AddressService {
  Future<String> resolveAddress(Position pos) async {
    final placeName = await _tryResolvePlaceName(pos);
    if (placeName != null && placeName.trim().isNotEmpty) {
      return AddressCleaner.clean(placeName, true);
    }

    final reverseGeo = await _reverseGeocodeShort(pos);
    return AddressCleaner.clean(reverseGeo, true);
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

      // Egyszerűen csak kinyerjük az alapadatokat, a tisztító majd elvégzi a varázslatot
      String streetName = (placemark.thoroughfare ?? '').trim();
      if (streetName.isEmpty) streetName = (placemark.street ?? '').trim();
      
      final houseNumber = (placemark.subThoroughfare ?? '').trim();
      final city = (placemark.locality ?? '').trim();

      List<String> combined = [];
      if (streetName.isNotEmpty) combined.add(streetName);
      if (houseNumber.isNotEmpty) combined.add(houseNumber);
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
