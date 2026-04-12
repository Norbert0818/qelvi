import 'package:flutter/material.dart';
import '../core/tracking/tracking_service.dart';
import '../features/sheets/sheets_page.dart';

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
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const SheetsPage(),
    );
  }
}