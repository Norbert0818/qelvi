// lib/app/app.dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../core/tracking/tracking_service.dart';
import '../features/sheets/sheets_page.dart';
import '../core/theme/solar_theme.dart'; // Add this import

class QelviApp extends StatelessWidget {
  final TrackingService trackingService;

  const QelviApp({
    super.key,
    required this.trackingService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Qelvi',
      debugShowCheckedModeBanner: false,

      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,

      // --- APPLIED THEME FIX ---
      theme: SolarTheme.lightTheme,
      darkTheme: SolarTheme.darkTheme,
      themeMode: SolarTheme.currentThemeMode,

      home: const SheetsPage(),
    );
  }
}

// ... (Keep the AppBootstrapper class exactly as it is) ...