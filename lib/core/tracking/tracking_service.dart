import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'foreground_task_handler.dart';
import '../location/address_service.dart';

class TrackingSnapshot {
  final bool isTracking;
  final double distanceKm;
  final String elapsed;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? startAddress;
  final String? endAddress;

  const TrackingSnapshot({
    required this.isTracking,
    required this.distanceKm,
    required this.elapsed,
    this.startTime,
    this.endTime,
    this.startAddress,
    this.endAddress,
  });

  TrackingSnapshot copyWith({
    bool? isTracking,
    double? distanceKm,
    String? elapsed,
    DateTime? startTime,
    DateTime? endTime,
    String? startAddress,
    String? endAddress,
  }) {
    return TrackingSnapshot(
      isTracking: isTracking ?? this.isTracking,
      distanceKm: distanceKm ?? this.distanceKm,
      elapsed: elapsed ?? this.elapsed,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      startAddress: startAddress ?? this.startAddress,
      endAddress: endAddress ?? this.endAddress,
    );
  }

  factory TrackingSnapshot.empty() {
    return const TrackingSnapshot(
      isTracking: false,
      distanceKm: 0.0,
      elapsed: '00:00:00',
    );
  }
}

class TrackingStartResult {
  final TrackingSnapshot snapshot;

  const TrackingStartResult(this.snapshot);
}

class TrackingStopResult {
  final TrackingSnapshot snapshot;

  const TrackingStopResult(this.snapshot);
}

class TrackingService {
  final AddressService _addressService;

  TrackingService(this._addressService);

  static const _startAddressKey = 'start_address';
  static const _startTimeKey = 'start_time';
  static const _distanceKmKey = 'distance_km';
  static const _totalDistanceLegacyKey = 'total_distance';

  //it works just in main
  // Future<void> init() async {
  //   FlutterForegroundTask.initCommunicationPort();
  //
  //   FlutterForegroundTask.init(
  //     androidNotificationOptions: AndroidNotificationOptions(
  //       channelId: 'qelvi_tracking',
  //       channelName: 'Trip Tracking',
  //       channelDescription: 'Tracking notification while a trip is running.',
  //       onlyAlertOnce: false,
  //     ),
  //     iosNotificationOptions: const IOSNotificationOptions(
  //       showNotification: true,
  //       playSound: true,
  //     ),
  //     foregroundTaskOptions: ForegroundTaskOptions(
  //       eventAction: ForegroundTaskEventAction.repeat(1000),
  //       autoRunOnBoot: true,
  //       autoRunOnMyPackageReplaced: true,
  //       allowWakeLock: true,
  //       allowWifiLock: true,
  //     ),
  //   );
  // }

  Future<bool> ensurePermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;
    }

    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    final whenInUse = await Permission.locationWhenInUse.request();
    if (!whenInUse.isGranted) return false;

    final always = await Permission.locationAlways.request();
    if (!always.isGranted && Platform.isIOS) {
      await openAppSettings();
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return false;
      }
    }

    return true;
  }

  Future<bool> isRunning() async {
    return FlutterForegroundTask.isRunningService;


  }

  Future<TrackingStartResult> startTrip() async {
    final ok = await ensurePermissions();
    if (!ok) {
      throw Exception('Location permission was not granted.');
    }

    final alreadyRunning = await isRunning();
    if (alreadyRunning) {
      throw Exception('Tracking already started.');
    }

    final pos = await Geolocator.getCurrentPosition();
    final startAddress = await _addressService.resolveAddress(pos);
    final startTime = DateTime.now();

    final serviceResult = await FlutterForegroundTask.startService(
      notificationTitle: 'Qelvi is tracking',
      notificationText: '0.00 km tracked',
      notificationButtons: [
        const NotificationButton(id: 'btn_stop', text: '🛑 STOP'),
      ],
      callback: startCallback,
    );

    if (serviceResult is! ServiceRequestSuccess) {
      throw Exception('Failed to start foreground service: $serviceResult');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_startAddressKey, startAddress);
    await prefs.setString(_startTimeKey, startTime.toIso8601String());
    await prefs.setDouble(_distanceKmKey, 0.0);

    final snapshot = TrackingSnapshot(
      isTracking: true,
      distanceKm: 0.0,
      elapsed: '00:00:00',
      startTime: startTime,
      startAddress: startAddress,
      endTime: null,
      endAddress: null,
    );

    return TrackingStartResult(snapshot);
  }

  Future<TrackingStopResult> stopTrip() async {
    final running = await isRunning();
    if (!running) {
      throw Exception('Tracking is not running.');
    }

    final prefs = await SharedPreferences.getInstance();
    final savedStartTimeRaw = prefs.getString(_startTimeKey);
    final savedStartAddress = prefs.getString(_startAddressKey);
    final savedDistanceKm = prefs.getDouble(_distanceKmKey) ?? 0.0;

    await FlutterForegroundTask.stopService();

    final pos = await Geolocator.getCurrentPosition();
    final endAddress = await _addressService.resolveAddress(pos);
    final endTime = DateTime.now();

    final startTime =
    savedStartTimeRaw != null ? DateTime.tryParse(savedStartTimeRaw) : null;

    final elapsed = startTime != null
        ? _formatDuration(endTime.difference(startTime))
        : '00:00:00';

    await prefs.remove(_startAddressKey);
    await prefs.remove(_startTimeKey);
    await prefs.remove(_distanceKmKey);
    await prefs.remove(_totalDistanceLegacyKey);

    return TrackingStopResult(
      TrackingSnapshot(
        isTracking: false,
        distanceKm: savedDistanceKm,
        elapsed: elapsed,
        startTime: startTime,
        startAddress: savedStartAddress,
        endTime: endTime,
        endAddress: endAddress,
      ),
    );
  }


  Future<TrackingSnapshot> restoreState() async {
    final prefs = await SharedPreferences.getInstance();

    final savedStartAddress = prefs.getString(_startAddressKey);
    final savedStartTimeRaw = prefs.getString(_startTimeKey);
    final savedDistanceKm = prefs.getDouble(_distanceKmKey);
    final savedLegacyMeters = prefs.getDouble(_totalDistanceLegacyKey);

    double km = 0.0;
    if (savedDistanceKm != null) km = savedDistanceKm;
    if (savedLegacyMeters != null) km = savedLegacyMeters / 1000.0;

    final running = await isRunning();
    final startTime =
    savedStartTimeRaw != null ? DateTime.tryParse(savedStartTimeRaw) : null;

    final elapsed = (running && startTime != null)
        ? _formatDuration(DateTime.now().difference(startTime))
        : '00:00:00';

    return TrackingSnapshot(
      isTracking: running,
      distanceKm: km,
      elapsed: elapsed,
      startTime: startTime,
      startAddress: savedStartAddress,
      endTime: null,
      endAddress: null,
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }


}