import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

class MyTaskHandler extends TaskHandler {
  Position? _lastAccepted;
  DateTime? _lastAcceptedAt;
  double _totalMeters = 0.0;
  DateTime? _startTime;
  StreamSubscription<Position>? _sub;
  Timer? _timer; // <-- A belső óránk

  static const double maxAccuracyMeters = 15.0;
  static const double minStepMeters = 2.0;
  static const double maxSpeedMps = 55.0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _startTime = DateTime.now();
    _totalMeters = 0.0;
    _lastAccepted = null;
    _lastAcceptedAt = null;

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    );

    _sub = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(_onPos);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _tick();
    });
  }

  Future<void> _onPos(Position pos) async {
    if (pos.accuracy.isNaN || pos.accuracy > maxAccuracyMeters) return;

    final now = DateTime.now();

    if (_lastAccepted != null && _lastAcceptedAt != null) {
      final step = Geolocator.distanceBetween(
        _lastAccepted!.latitude,
        _lastAccepted!.longitude,
        pos.latitude,
        pos.longitude,
      );

      // Ideiglenesen kikommentelheted a 2 méteres szűrőt a szobai teszteléshez!
      if (step < minStepMeters) return;

      final dt = now.difference(_lastAcceptedAt!).inMilliseconds / 1000.0;
      if (dt > 0) {
        final speed = step / dt;
        if (speed > maxSpeedMps) return;
      }

      _totalMeters += step;
    }

    _lastAccepted = pos;
    _lastAcceptedAt = now;

    // KISZEDTÜK INNEN A SharedPreferences MENTÉST!
    final km = _totalMeters / 1000.0;
    final elapsed = _startTime != null
        ? _formatDuration(now.difference(_startTime!))
        : '00:00:00';

    // Azonnal küldjük az adatot a UI-nak
    FlutterForegroundTask.sendDataToMain({
      'type': 'update',
      'distanceKm': km,
      'elapsed': elapsed,
    });
  }

  void _tick() {
    if (_startTime == null) return;

    final now = DateTime.now();
    final km = _totalMeters / 1000.0;
    final elapsed = _formatDuration(now.difference(_startTime!));

    FlutterForegroundTask.updateService(
      notificationTitle: 'Qelvi is tracking',
      notificationText: '${km.toStringAsFixed(2)} km tracked – $elapsed elapsed',
    );

    FlutterForegroundTask.sendDataToMain({
      'type': 'update',
      'distanceKm': km,
      'elapsed': elapsed,
    });
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Ezt most már békén hagyhatjuk, mert a belső Timer megoldja helyette!
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    await _sub?.cancel();
    _timer?.cancel();
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'stop') {
      FlutterForegroundTask.stopService();
    }
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}