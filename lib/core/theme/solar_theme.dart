// lib/core/theme/solar_theme.dart
import 'package:flutter/material.dart';

class SolarTheme {
  // --- INTELLIGENT SOLAR CALCULATOR ---
  static ThemeMode get currentThemeMode {
    final now = DateTime.now();
    // final now = DateTime(2026, 6, 15, 23, 30);
    final month = now.month;
    final hour = now.hour + (now.minute / 60.0);

    const ephemeris = {
      1:  [7.8, 16.8],
      2:  [7.2, 17.5],
      3:  [6.3, 18.3],
      4:  [6.2, 20.0],
      5:  [5.5, 20.8],
      6:  [5.2, 21.3],
      7:  [5.5, 21.2],
      8:  [6.0, 20.3],
      9:  [6.8, 19.2],
      10: [7.3, 18.0],
      11: [7.0, 16.5],
      12: [7.8, 16.0],
    };

    final times = ephemeris[month] ?? [6.0, 18.0];
    final sunrise = times[0];
    final sunset = times[1];

    final isNight = hour < sunrise || hour >= sunset;
    return isNight ? ThemeMode.dark : ThemeMode.light;
  }

  // ==========================================
  // 1. LIGHT PALETTE
  // ==========================================
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorSchemeSeed: Colors.blue, // Automatically generates correct Material 3 contrasts
    scaffoldBackgroundColor: Colors.grey.shade50,
    cardColor: Colors.white,
    dividerColor: Colors.grey.shade200,
  );

  // ==========================================
  // 2. DARK PALETTE - OLED Optimized
  // ==========================================
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorSchemeSeed: Colors.blue, // Ensures buttons are legible in dark mode
    scaffoldBackgroundColor: const Color(0xFF121212),
    cardColor: const Color(0xFF1E1E1E),
    dividerColor: const Color(0xFF2C2C2C),
  );
}