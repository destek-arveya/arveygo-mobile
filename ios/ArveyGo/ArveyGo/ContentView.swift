import SwiftUI
import UIKit

// MARK: - App Pages
enum AppPage: String, CaseIterable {
    case dashboard = "Dashboard"
    case liveMap = "Canlı Harita"
    case vehicles = "Araçlar"
    case routeHistory = "Rota Geçmişi"
}

struct ContentView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var selectedPage: AppPage = .dashboard
    @State private var showSideMenu = false

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
                    DashboardView(showSideMenu: $showSideMenu)
                case .liveMap:
                    LiveMapView(showSideMenu: $showSideMenu)
                case .vehicles:
                    VehiclesListView(showSideMenu: $showSideMenu)
                case .routeHistory:
                    RouteHistoryView(showSideMenu: $showSideMenu)
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
            // Reconnect WebSocket when app returns to foreground (global, not just live map)
            WebSocketManager.shared.reconnect()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
