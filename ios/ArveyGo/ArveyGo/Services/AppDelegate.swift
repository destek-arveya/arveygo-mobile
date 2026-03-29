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
        registerNotificationCategories()

        // Request push permission immediately on app launch
        AppDelegate.requestPushPermission()

        return true
    }

    private func registerNotificationCategories() {
        // ALARM category — "Görüntüle" + "Kapat"
        let viewAction = UNNotificationAction(
            identifier: "ALARM_VIEW",
            title: "Görüntüle",
            options: [.foreground]
        )
        let dismissAction = UNNotificationAction(
            identifier: "ALARM_DISMISS",
            title: "Kapat",
            options: [.destructive]
        )
        let alarmCategory = UNNotificationCategory(
            identifier: "ALARM",
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        // GEOFENCE category — "Haritada Gör" + "Yoksay"
        let mapAction = UNNotificationAction(
            identifier: "GEOFENCE_MAP",
            title: "Haritada Gör",
            options: [.foreground]
        )
        let ignoreAction = UNNotificationAction(
            identifier: "GEOFENCE_IGNORE",
            title: "Yoksay",
            options: []
        )
        let geofenceCategory = UNNotificationCategory(
            identifier: "GEOFENCE",
            actions: [mapAction, ignoreAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([alarmCategory, geofenceCategory])
        print("[APNs] Notification categories registered: ALARM, GEOFENCE")
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
        let actionId = response.actionIdentifier

        print("[APNs] Action: \(actionId), userInfo: \(userInfo)")

        switch actionId {
        case "ALARM_VIEW":
            let alarmId = userInfo["alarm_id"]
            let vehicleId = userInfo["vehicle_id"]
            print("[APNs] → Alarm görüntüle: alarm=\(alarmId ?? "?"), vehicle=\(vehicleId ?? "?")")
            NotificationCenter.default.post(
                name: .init("apns.alarm.view"),
                object: nil,
                userInfo: ["alarm_id": alarmId ?? 0, "vehicle_id": vehicleId ?? 0]
            )
        case "ALARM_DISMISS":
            print("[APNs] → Alarm kapatıldı")
        case "GEOFENCE_MAP":
            let vehicleId = userInfo["vehicle_id"]
            print("[APNs] → Geofence haritada göster: vehicle=\(vehicleId ?? "?")")
            NotificationCenter.default.post(
                name: .init("apns.geofence.map"),
                object: nil,
                userInfo: ["vehicle_id": vehicleId ?? 0]
            )
        case "GEOFENCE_IGNORE":
            print("[APNs] → Geofence yoksayıldı")
        case UNNotificationDefaultActionIdentifier:
            // Bildirime direkt tıklandı (buton değil)
            print("[APNs] → Bildirime tıklandı")
        default:
            break
        }

        completionHandler()
    }
}
