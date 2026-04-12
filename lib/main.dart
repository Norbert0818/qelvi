import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'app/app.dart';
import 'core/location/address_service.dart';
import 'core/tracking/tracking_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');
  FlutterForegroundTask.initCommunicationPort();

  final trackingService = TrackingService(AddressService());
  // await trackingService.init();
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
      onlyAlertOnce: false,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: true,
      playSound: true,
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