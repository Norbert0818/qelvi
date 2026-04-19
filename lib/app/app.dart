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

class AppBootstrapper extends StatefulWidget {
  final TrackingService trackingService;
  final Widget child;

  const AppBootstrapper({
    Key? key,
    required this.trackingService,
    required this.child,
  }) : super(key: key);

  @override
  State<AppBootstrapper> createState() => _AppBootstrapperState();
}

class _AppBootstrapperState extends State<AppBootstrapper> {
  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    bool hasPermissions = await widget.trackingService.ensurePermissions();
    if (!hasPermissions) {
      print("Figyelem: Nem kaptunk meg minden szükséges engedélyt!");
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}