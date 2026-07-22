// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
// import 'package:home_widget/home_widget.dart';
import 'package:easy_localization/easy_localization.dart'; // Importálva a fordításhoz

import 'app/app.dart';
import 'core/location/address_service.dart';
import 'core/tracking/tracking_service.dart';

@pragma("vm:entry-point")
// Future<void> interactiveCallback(Uri? uri) async {
//   if (uri == null) return;
//
//   WidgetsFlutterBinding.ensureInitialized();
//   await EasyLocalization.ensureInitialized();
//   await dotenv.load(fileName: '.env');
//
//   FlutterForegroundTask.initCommunicationPort();
//   _initService();
//
//   final trackingService = TrackingService(AddressService());
//
//   if (uri.host == 'start') {
//     try {
//       await trackingService.startTrip(isBackground: true);
//
//       // Fordítás a Widget feliratára
//       await HomeWidget.saveWidgetData<String>('status_text', tr('tracking_started_widget'));
//       await HomeWidget.updateWidget(name: 'QelviWidgetProvider');
//     } catch (e) {
//       print("${tr('err_start_error')}: $e");
//     }
//   } else if (uri.host == 'stop') {
//     try {
//       await trackingService.stopAndSaveTrip();
//
//       // Fordítás a Widget feliratára
//       await HomeWidget.saveWidgetData<String>('status_text', tr('trip_saved_widget'));
//       await HomeWidget.updateWidget(name: 'QelviWidgetProvider');
//     } catch (e) {
//       print("${tr('err_widget_save')}: $e");
//     }
//   }
// }

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await dotenv.load(fileName: '.env');

  FlutterForegroundTask.initCommunicationPort();
  // HomeWidget.registerInteractivityCallback(interactiveCallback);

  final trackingService = TrackingService(AddressService());
  _initService();

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en'),
        Locale('ro'),
        Locale('hu')
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: QelviApp(trackingService: trackingService),
    ),
  );
}

void _initService() {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'qelvi_tracking',
      // Ezek a nevek az Android rendszerbeállítások / Alkalmazások / Értesítések menüben fognak látszani
      channelName: tr('notification_channel_name'),
      channelDescription: tr('notification_channel_desc'),
      onlyAlertOnce: true,
      visibility: NotificationVisibility.VISIBILITY_PUBLIC,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: false,
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