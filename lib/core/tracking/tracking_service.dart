// lib/core/tracking/tracking_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'foreground_task_handler.dart';
import '../location/address_service.dart';

import '../storage/prefs_service.dart';
import '../../features/sheets/models/day_sheet.dart';
import '../../features/sheets/models/trip_row.dart';
import 'package:easy_localization/easy_localization.dart';

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
  final PrefsService _prefsService = PrefsService();

  TrackingService(this._addressService);

  static const _startAddressKey = 'start_address';
  static const _startTimeKey = 'start_time';
  static const _distanceKmKey = 'distance_km';
  static const _totalDistanceLegacyKey = 'total_distance';

  // --- ÚJ: Platform-specifikus GPS beállítások (iOS leállás és pontatlanság ellen) ---
  LocationSettings _getPlatformLocationSettings() {
    if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 5,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
        pauseLocationUpdatesAutomatically: false,
      );
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
        forceLocationManager: false,
        intervalDuration: const Duration(seconds: 2),
      );
    } else {
      return const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      );
    }
  }

  Future<bool> ensurePermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    // --- APPLE JAVÍTÁS: Nem dobjuk ki automatikusan a Beállításokba, ha tiltva van! ---
    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    if (permission == LocationPermission.whileInUse) {
      final alwaysStatus = await Permission.locationAlways.request();
      // --- APPLE JAVÍTÁS: Itt sem nyitjuk meg erőszakosan a Settings-et! ---
      if (!alwaysStatus.isGranted) {
        return false;
      }
    }

    return true;
  }

  Future<bool> hasRequiredPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return false;
    }

    if (permission == LocationPermission.whileInUse) {
      final alwaysStatus = await Permission.locationAlways.status;
      if (!alwaysStatus.isGranted) return false;
    }

    return true;
  }

  Future<bool> isRunning() async {
    return FlutterForegroundTask.isRunningService;
  }

  Future<TrackingStartResult> startTrip({bool isBackground = false}) async {
    if (!isBackground) {
      final ok = await ensurePermissions();
      if (!ok) {
        throw Exception(tr('err_location_permission'));
      }
    }

    final alreadyRunning = await isRunning();
    if (alreadyRunning) {
      throw Exception(tr('err_already_started'));
    }

    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: _getPlatformLocationSettings(),
      );
    } catch (e) {
      pos = await Geolocator.getLastKnownPosition();
    }

    String startAddress = tr('unknown_location');
    if (pos != null) {
      startAddress = await _addressService.resolveAddress(pos);
    }

    final startTime = DateTime.now();

    final serviceResult = await FlutterForegroundTask.startService(
      notificationTitle: 'Qelvi GPS Tracking',
      notificationText: '0 km tracked',
      callback: startCallback,
    );

    if (serviceResult is! ServiceRequestSuccess) {
      throw Exception('${tr('err_start_service')}: $serviceResult');
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

  Future<TrackingStopResult> stopAndSaveTrip() async {
    final running = await isRunning();
    if (!running) {
      throw Exception(tr('err_not_running'));
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    final savedStartTimeRaw = prefs.getString(_startTimeKey);
    final savedStartAddress = prefs.getString(_startAddressKey);

    // Felfelé kerekítés a mért útra
    final savedDistanceKm = (prefs.getDouble(_distanceKmKey) ?? 0.0).ceilToDouble();

    await FlutterForegroundTask.stopService();

    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: _getPlatformLocationSettings(),
      );
    } catch (e) {
      pos = await Geolocator.getLastKnownPosition();
    }

    String endAddress = tr('unknown_location');
    if (pos != null) {
      endAddress = await _addressService.resolveAddress(pos);
    }

    final endTime = DateTime.now();
    final startTime = savedStartTimeRaw != null ? DateTime.tryParse(savedStartTimeRaw) : null;
    final elapsed = startTime != null ? _formatDuration(endTime.difference(startTime)) : '00:00:00';

    final todayStr = _formatDate(endTime);

    final defaultVehicleType = prefs.getString('default_vehicle_type') ?? '';
    final defaultFuelType = prefs.getString('default_fuel_type') ?? '';
    final defaultCarNumber = prefs.getString('default_car_number') ?? '';
    final defaultDriverName = prefs.getString('default_driver_name') ?? '';
    final activeEventName = prefs.getString('active_event_name') ?? '';

    List<DaySheet> allSheets = await _prefsService.loadDaySheets();

    int sheetIndex = allSheets.indexWhere((s) =>
    s.date == todayStr &&
        s.carNumber == defaultCarNumber &&
        s.eventName == activeEventName &&
        !s.isArchived
    );

    DaySheet activeSheet;
    if (sheetIndex >= 0) {
      activeSheet = allSheets[sheetIndex];
    } else {
      int calculatedOdo = prefs.getInt('default_starting_odometer') ?? 0;

      final carSheets = allSheets.where((s) => s.carNumber == defaultCarNumber).toList();
      if (carSheets.isNotEmpty) {
        carSheets.sort((a, b) {
          try {
            final pA = a.date.split('.');
            final pB = b.date.split('.');
            final dA = DateTime(int.parse(pA[2]), int.parse(pA[1]), int.parse(pA[0]));
            final dB = DateTime(int.parse(pB[2]), int.parse(pB[1]), int.parse(pB[0]));
            return dB.compareTo(dA);
          } catch (_) { return 0; }
        });

        final lastSheet = carSheets.first;
        if (lastSheet.startingOdometer > 0) {
          // --- JAVÍTVA: Itt is .ceil() kerekítést használunk egységesen! ---
          calculatedOdo = lastSheet.startingOdometer + lastSheet.totalKm.ceil();
        } else {
          calculatedOdo = prefs.getInt('default_starting_odometer') ?? 0;
        }
      }

      activeSheet = DaySheet(
        id: DateTime.now().millisecondsSinceEpoch,
        vehicleType: defaultVehicleType,
        fuelType: defaultFuelType,
        date: todayStr,
        carNumber: defaultCarNumber,
        driverName: defaultDriverName,
        eventName: activeEventName,
        startingOdometer: calculatedOdo,
        rows: [],
      );
      allSheets.insert(0, activeSheet);
    }

    activeSheet.rows.add(
      TripRow(
        departurePlace: savedStartAddress ?? '',
        departureTime: _formatTime(startTime),
        arrivalPlace: endAddress,
        arrivalTime: _formatTime(endTime),
        km: savedDistanceKm,
      ),
    );

    await _prefsService.saveDaySheets(allSheets);

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

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  String _formatTime(DateTime? d) {
    if (d == null) return '';
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}