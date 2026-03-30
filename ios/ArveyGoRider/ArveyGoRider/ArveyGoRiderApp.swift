import SwiftUI

@main
struct ArveyGoRiderApp: App {
    @StateObject private var beaconManager = BeaconManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(beaconManager)
        }
    }
}
