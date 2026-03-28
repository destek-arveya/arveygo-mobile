import SwiftUI
import UIKit

// MARK: - App Pages
enum AppPage: String, CaseIterable {
    case dashboard = "Dashboard"
    case liveMap = "Canlı Harita"
    case vehicles = "Araçlar"
    case drivers = "Sürücüler"
    case routeHistory = "Rota Geçmişi"
    case alarms = "Alarmlar"
    case geofences = "Geofence"
    case fleetManagement = "Filo Yönetimi"
    case settings = "Ayarlar"
    case support = "Destek Talebi"
}

struct ContentView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var selectedPage: AppPage = .dashboard
    @State private var showSideMenu = false
    @State private var showSupportRequest = false
    @State private var alarmsSearchText = ""
    @GestureState private var dragOffset: CGFloat = 0

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
                    DashboardView(showSideMenu: $showSideMenu, selectedPage: $selectedPage, alarmsSearchText: $alarmsSearchText)
                case .liveMap:
                    LiveMapView(showSideMenu: $showSideMenu, selectedPage: $selectedPage, alarmsSearchText: $alarmsSearchText)
                case .vehicles:
                    VehiclesListView(showSideMenu: $showSideMenu, selectedPage: $selectedPage, alarmsSearchText: $alarmsSearchText)
                case .drivers:
                    DriversView(showSideMenu: $showSideMenu)
                case .routeHistory:
                    RouteHistoryView(showSideMenu: $showSideMenu)
                case .alarms:
                    AlarmsView(showSideMenu: $showSideMenu, initialSearchText: alarmsSearchText)
                case .geofences:
                    GeofencesView(showSideMenu: $showSideMenu)
                case .fleetManagement:
                    FleetManagementView(showSideMenu: $showSideMenu)
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
        .gesture(
            DragGesture()
                .onEnded { value in
                    // Swipe from left edge → open menu
                    if value.startLocation.x < 30 && value.translation.width > 60 {
                        withAnimation(.spring(response: 0.3)) {
                            showSideMenu = true
                        }
                    }
                    // Swipe left → close menu
                    if showSideMenu && value.translation.width < -60 {
                        withAnimation(.spring(response: 0.3)) {
                            showSideMenu = false
                        }
                    }
                }
        )
        .onChange(of: selectedPage) { oldPage, newPage in
            // Clear alarms search text when navigating away from alarms
            // or when navigating to alarms from side menu (not from VehicleDetail)
            if oldPage == .alarms { alarmsSearchText = "" }
            if newPage == .alarms && oldPage != .alarms {
                // alarmsSearchText already set by VehicleDetailView callback or stays ""
            }
        }
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
