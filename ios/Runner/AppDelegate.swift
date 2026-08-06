import UIKit
import Flutter
import UserNotifications
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Workmanager: the background Dart isolate runs on its own plugin
    // registry, so every plugin used by background tasks (sqflite,
    // shared_preferences, notifications, ...) must be registered here.
    // Without this callback the midnight daily reset crashes in background.
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }

    // BGTaskScheduler handlers must be registered before app launch finishes.
    // Identifiers must match BGTaskSchedulerPermittedIdentifiers in Info.plist
    // and the uniqueName used on the Dart side.
    // Daily reset: BGProcessingTask scheduled for next midnight (best effort).
    WorkmanagerPlugin.registerBGProcessingTask(withIdentifier: "com.chrono.daily_reset")
    // Safety check: BGAppRefreshTask, re-scheduled by the plugin every ~6h.
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "com.chrono.daily_reset_check",
      frequency: NSNumber(value: 6 * 60 * 60)
    )

    // Request notification permissions
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self

      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
      UNUserNotificationCenter.current().requestAuthorization(
        options: authOptions,
        completionHandler: { granted, error in
          if granted {
            print("iOS notification permission granted")
          } else if let error = error {
            print("iOS notification permission error: \(error)")
          }
        }
      )
    }

    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Handle notification when app is in foreground
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([[.banner, .sound, .badge]])
    } else {
      completionHandler([[.alert, .sound, .badge]])
    }
  }
}
