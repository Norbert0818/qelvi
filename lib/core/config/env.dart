import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get googleMapsApiKey =>
      dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  static String get apiBaseUrl =>
      dotenv.env['QELVI_API_BASE_URL'] ?? '';

  static String get apiKey =>
      dotenv.env['QELVI_API_KEY'] ?? '';
}