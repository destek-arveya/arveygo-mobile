import UIKit
import UserNotifications

/// Singleton that stores the most recently received APNs device token.
/// SettingsView reads this to display/copy the token.
final class DeviceTokenStore: ObservableObject {
    static let shared = DeviceTokenStore()
    @Published var token: String? = nil
}

/// AppDelegate handles APNs registration and receives the device token.
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// Call this from SettingsView (or anywhere) to request permission + register.
    static func requestPushPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            print("[APNs] Permission granted: \(granted), error: \(String(describing: error))")
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    // MARK: - APNs Callbacks

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("═══════════════════════════════════════════════════")
        print("[APNs] ✅ DEVICE TOKEN:")
        print(token)
        print("═══════════════════════════════════════════════════")

        DispatchQueue.main.async {
            DeviceTokenStore.shared.token = token
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[APNs] ❌ Registration failed: \(error.localizedDescription)")
    }

    // MARK: - Foreground Notification

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        print("[APNs] Notification tapped: \(userInfo)")
        completionHandler()
    }
}
