import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'app/app.dart';
import 'core/location/address_service.dart';
import 'core/tracking/tracking_service.dart';

import 'package:home_widget/home_widget.dart';

@pragma("vm:entry-point")
Future<void> interactiveCallback(Uri? uri) async {
  if (uri == null) return;

  await dotenv.load(fileName: '.env');

  FlutterForegroundTask.initCommunicationPort();
  _initService();

  final trackingService = TrackingService(AddressService());

  if (uri.host == 'start') {
    print("🚀 WIDGET: START gomb megnyomva!");
    try {
      // --- EZT JAVÍTOTTUK: Megmondjuk neki, hogy a háttérből indul! ---
      await trackingService.startTrip(isBackground: true);

      await HomeWidget.saveWidgetData<String>('status_text', 'Tracking Started...');
      await HomeWidget.updateWidget(name: 'QelviWidgetProvider');
    } catch (e) {
      print("Hiba a startnál: $e");
    }
  } else if (uri.host == 'stop') {
    try {
      await trackingService.stopAndSaveTrip();

      await HomeWidget.saveWidgetData<String>('status_text', 'Trip Saved!');
      await HomeWidget.updateWidget(name: 'QelviWidgetProvider');
    } catch (e) {
      print("Widget mentési hiba: $e");
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  FlutterForegroundTask.initCommunicationPort();
  HomeWidget.registerInteractivityCallback(interactiveCallback);
  final trackingService = TrackingService(AddressService());
  _initService();
  runApp(QelviApp(trackingService: trackingService));
}

void _initService() {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'qelvi_tracking',
      channelName: 'Foreground Service Notification',
      channelDescription:
      'This notification appears when the foreground service is running.',
      onlyAlertOnce: true,
      visibility: NotificationVisibility.VISIBILITY_PUBLIC,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: true,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(1000),
      autoRunOnBoot: true,
      autoRunOnMyPackageReplaced: true,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );
}