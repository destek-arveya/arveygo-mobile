import SwiftUI

@main
struct ArveyGoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authVM = AuthViewModel()
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authVM)
                .preferredColorScheme(themeManager.colorScheme)
        }
    }
}
