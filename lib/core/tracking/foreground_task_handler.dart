import 'dart:async';
import 'package:home_widget/home_widget.dart';
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

  // Beállítások a pontos GPS méréshez
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

    final km = _totalMeters / 1000.0;
    final elapsed = _startTime != null
        ? _formatDuration(now.difference(_startTime!))
        : '00:00:00';

    FlutterForegroundTask.sendDataToMain({
      'type': 'update',
      'distanceKm': km,
      'elapsed': elapsed,
    });
  }

  // Ezt hívja meg az Android garantáltan másodpercenként a háttérben
  @override
  void onRepeatEvent(DateTime timestamp) {
    _tick();
  }

  void _tick() {
    if (_startTime == null) return;

    final now = DateTime.now();
    final km = _totalMeters / 1000.0;
    final elapsed = _formatDuration(now.difference(_startTime!));

    final statusText = '${km.toStringAsFixed(2)} km – $elapsed';

    // 1. Azonnal frissítjük az értesítést (ez tartja életben a szálat)
    FlutterForegroundTask.updateService(
      notificationTitle: 'Qelvi is tracking',
      notificationText: statusText,
      notificationButtons: [
        const NotificationButton(id: 'btn_stop', text: '🛑 STOP'),
      ],
    );

    // 2. Küldjük a jelet a UI-nak
    FlutterForegroundTask.sendDataToMain({
      'type': 'update',
      'distanceKm': km,
      'elapsed': elapsed,
    });

    // 3. Aszinkron mentjük a memóriát, hogy ne akasszuk meg az órát!
    SharedPreferences.getInstance().then((prefs) {
      prefs.setDouble('distance_km', km);
    });

    // 4. Aszinkron frissítjük a Widgetet
    HomeWidget.saveWidgetData<String>('status_text', statusText).then((_) {
      HomeWidget.updateWidget(name: 'QelviWidgetProvider');
    });
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    await _sub?.cancel();
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'stop' || id == 'btn_stop') {
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