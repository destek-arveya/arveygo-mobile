import SwiftUI

@main
struct ArveyGoRiderApp: App {
    @StateObject private var beaconManager = BeaconManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(beaconManager)
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Arka plana geçince yayın aktifse iOS'a sinyal ver
            // CBPeripheralManager + bluetooth-peripheral background mode
            // yayını otomatik sürdürür, ekstra kod gerekmez.
            if newPhase == .active {
                // Ön plana gelince wasActive kontrol edilerek yayın devam eder
                // (BeaconManager.resumeIfNeeded zaten bunu halleder)
                _ = newPhase
            }
        }
    }
}
