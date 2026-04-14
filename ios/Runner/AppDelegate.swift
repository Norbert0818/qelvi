import UIKit
import Flutter
import flutter_foreground_task // Ezt a sort hozzáadjuk

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
  _ application: UIApplication,
  didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // --- EZT A KÉT SORT HOZZÁADJUK A HÁTTÉRFOLYAMATHOZ ---
    SwiftFlutterForegroundTaskPlugin.setPluginRegistrantCallback(registerPlugins)
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    // -----------------------------------------------------

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

// Ezt a függvényt is hozzáadjuk a fájl legaljára!
func registerPlugins(registry: FlutterPluginRegistry) {
  GeneratedPluginRegistrant.register(with: registry)
}