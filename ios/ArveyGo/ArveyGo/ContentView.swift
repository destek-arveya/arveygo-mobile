import SwiftUI
import UIKit

// MARK: - App Pages
enum AppPage: String, CaseIterable {
    case dashboard = "Dashboard"
    case liveMap = "Canlı Harita"
    case vehicles = "Araçlar"
    case routeHistory = "Rota Geçmişi"
    case alarms = "Alarmlar"
    case geofences = "Geofence"
    case settings = "Ayarlar"
    case support = "Destek Talebi"
}

struct ContentView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var selectedPage: AppPage = .dashboard
    @State private var showSideMenu = false
    @State private var showSupportRequest = false

    var body: some View {
        Group {
            if authVM.isLoggedIn {
                mainView
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                NavigationStack {
                    LoginView()
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authVM.isLoggedIn)
    }

    var mainView: some View {
        ZStack {
            // Active page
            Group {
                switch selectedPage {
                case .dashboard:
                    DashboardView(showSideMenu: $showSideMenu, selectedPage: $selectedPage)
                case .liveMap:
                    LiveMapView(showSideMenu: $showSideMenu, selectedPage: $selectedPage)
                case .vehicles:
                    VehiclesListView(showSideMenu: $showSideMenu, selectedPage: $selectedPage)
                case .routeHistory:
                    RouteHistoryView(showSideMenu: $showSideMenu)
                case .alarms:
                    AlarmsView(showSideMenu: $showSideMenu)
                case .geofences:
                    GeofencesView(showSideMenu: $showSideMenu)
                case .settings:
                    SettingsView(showSideMenu: $showSideMenu)
                case .support:
                    SupportRequestView(showSideMenu: $showSideMenu)
                }
            }
            .disabled(showSideMenu)

            // Side menu overlay
            if showSideMenu {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            showSideMenu = false
                        }
                    }
                    .transition(.opacity)
            }

            // Side menu
            SideMenuView(isShowing: $showSideMenu, selectedPage: $selectedPage)
        }
        .animation(.spring(response: 0.3), value: showSideMenu)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // WebSocketManager handles foreground reconnection internally now
            // This is a backup in case the internal observer missed it
            print("[ContentView] App returning to foreground")
        }
        .onChange(of: WebSocketManager.shared.consecutiveFailures) { _, failures in
            if failures >= WebSocketManager.maxConsecutiveFailures {
                showSupportRequest = true
            }
        }
        .fullScreenCover(isPresented: $showSupportRequest) {
            SupportRequestView()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
