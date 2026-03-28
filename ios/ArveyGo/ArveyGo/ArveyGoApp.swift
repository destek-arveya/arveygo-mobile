import SwiftUI

@main
struct ArveyGoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authVM = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authVM)
                .preferredColorScheme(.light)
        }
    }
}
