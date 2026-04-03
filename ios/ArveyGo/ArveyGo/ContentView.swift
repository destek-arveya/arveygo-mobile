import SwiftUI
import UIKit

extension Notification.Name {
    static let arveygoSwitchMainTab = Notification.Name("arveygoSwitchMainTab")
}

// MARK: - Tab Enum (Bottom Navigation)
enum AppTab: String, CaseIterable {
    case dashboard = "Dashboard"
    case alarms    = "Alarms"
    case liveMap   = "LiveMap"
    case fleet     = "Fleet"
    case hub       = "Hub"
}

// MARK: - Legacy AppPage (kept for internal navigation within views)
enum AppPage: String, CaseIterable {
    case dashboard = "Dashboard"
    case liveMap = "Canlı Harita"
    case vehicles = "Araçlar"
    case drivers = "Sürücüler"
    case routeHistory = "Rota Geçmişi"
    case alarms = "Alarmlar"
    case geofences = "Geofence"
    case fleetManagement = "Filo Yönetimi"
    case reports = "Raporlar"
    case settings = "Ayarlar"
    case support = "Destek Talebi"
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Content View
// ═══════════════════════════════════════════════════════════════════════════
struct ContentView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTab: AppTab = .liveMap
    @State private var showSupportRequest = false
    @StateObject private var dashboardVM = DashboardViewModel()

    // Legacy states kept for child views that still use them
    @State private var selectedPage: AppPage = .liveMap
    @State private var showSideMenu = false
    @State private var alarmsSearchText = ""
    @State private var alarmsAutoOpenCreate = false
    @State private var alarmsPrePlate = ""
    @State private var alarmsInitialEvent: AlarmEvent? = nil

    // Alarm glow effect
    @State private var alarmGlowing = false

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        Group {
            if authVM.isLoggedIn {
                mainTabView
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

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: — Main Tab View
    // ═══════════════════════════════════════════════════════════════════════
    var mainTabView: some View {
        VStack(spacing: 0) {
            // ── Active Page Content (fills remaining space) ──
            Group {
                switch selectedTab {
                case .dashboard:
                    NavigationStack {
                        DashboardAlternativeView(
                            vm: dashboardVM,
                            selectedPage: $selectedPage,
                            alarmsSearchText: $alarmsSearchText,
                            alarmsAutoOpenCreate: $alarmsAutoOpenCreate,
                            alarmsPrePlate: $alarmsPrePlate,
                            alarmsInitialEvent: $alarmsInitialEvent
                        )
                    }
                case .alarms:
                    AlarmsView(
                        showSideMenu: $showSideMenu,
                        initialSearchText: alarmsSearchText,
                        autoOpenCreate: alarmsAutoOpenCreate,
                        preSelectedPlate: alarmsPrePlate,
                        initialAlarmEvent: alarmsInitialEvent
                    )
                case .liveMap:
                    LiveMapView(
                        showSideMenu: $showSideMenu,
                        selectedPage: $selectedPage,
                        alarmsSearchText: $alarmsSearchText,
                        alarmsAutoOpenCreate: $alarmsAutoOpenCreate,
                        alarmsPrePlate: $alarmsPrePlate
                    )
                case .fleet:
                    FleetManagementView(showSideMenu: $showSideMenu)
                case .hub:
                    HubView(
                        selectedTab: $selectedTab,
                        alarmsSearchText: $alarmsSearchText,
                        alarmsAutoOpenCreate: $alarmsAutoOpenCreate,
                        alarmsPrePlate: $alarmsPrePlate
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // ── Bottom Tab Bar — flush to bottom edge ──
            bottomTabBar
        }
        .ignoresSafeArea(.keyboard)
        .onChange(of: selectedTab) { oldTab, newTab in
            if oldTab == .alarms {
                alarmsSearchText = ""
                alarmsAutoOpenCreate = false
                alarmsPrePlate = ""
                alarmsInitialEvent = nil
            }
        }
        .onChange(of: selectedPage) { _, newPage in
            switch newPage {
            case .dashboard: selectedTab = .dashboard
            case .alarms: selectedTab = .alarms
            case .liveMap: selectedTab = .liveMap
            case .fleetManagement: selectedTab = .fleet
            default: break
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            print("[ContentView] App returning to foreground")
        }
        .onReceive(NotificationCenter.default.publisher(for: .arveygoSwitchMainTab)) { note in
            guard let tab = note.object as? AppTab else { return }
            selectedTab = tab
        }
        .onChange(of: WebSocketManager.shared.consecutiveFailures) { _, failures in
            if failures >= WebSocketManager.maxConsecutiveFailures {
                showSupportRequest = true
            }
        }
        .fullScreenCover(isPresented: $showSupportRequest) {
            NavigationStack {
                SupportRequestView(presentationMode: .modal)
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: — Bottom Tab Bar (flush, edge-to-edge)
    // ═══════════════════════════════════════════════════════════════════════
    private var bottomTabBar: some View {
        VStack(spacing: 0) {
            // Top separator
            Rectangle()
                .fill(isDark
                      ? Color.white.opacity(0.06)
                      : Color(red: 228/255, green: 231/255, blue: 240/255).opacity(0.8))
                .frame(height: 0.5)

            // Tab items
            HStack(spacing: 0) {
                tabItem(tab: .dashboard,  icon: "square.grid.2x2.fill",       label: "Özet")
                tabItem(tab: .alarms,     icon: "bell.fill",                   label: "Alarmlar")
                mapCenterTab
                tabItem(tab: .fleet,      icon: "wrench.and.screwdriver.fill", label: "Filo")
                tabItem(tab: .hub,        icon: "circle.grid.2x2.fill",       label: "Hub")
            }
            .padding(.top, 6)
            .padding(.bottom, 2)
        }
        .background {
            (isDark
             ? Color(red: 16/255, green: 19/255, blue: 42/255)
             : Color(red: 252/255, green: 252/255, blue: 254/255))
            .ignoresSafeArea(edges: .bottom)
            .shadow(color: isDark ? .black.opacity(0.4) : .black.opacity(0.06),
                    radius: 8, x: 0, y: -2)
        }
    }

    // ── Standard Tab Item ──
    private func tabItem(tab: AppTab, icon: String, label: String) -> some View {
        let isActive = selectedTab == tab
        let isAlarm = tab == .alarms

        let activeColor = isDark
            ? Color(red: 139/255, green: 149/255, blue: 224/255)
            : Color(red: 9/255, green: 15/255, blue: 65/255)
        let inactiveColor = isDark
            ? Color(red: 80/255, green: 84/255, blue: 110/255)
            : Color(red: 155/255, green: 160/255, blue: 178/255)

        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    Image(systemName: icon)
                        .font(.system(size: 19, weight: isActive ? .semibold : .regular))
                        .foregroundStyle(isActive ? activeColor : inactiveColor)

                    // Alarm glow
                    if isAlarm && alarmGlowing {
                        Circle()
                            .fill(Color.red.opacity(0.3))
                            .frame(width: 32, height: 32)
                            .blur(radius: 8)
                    }
                }
                .frame(height: 24)

                Text(label)
                    .font(.system(size: 10, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? activeColor : inactiveColor)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .contentShape(Rectangle())
        }
    }

    // ── Center Map Tab — elevated circle ──
    private var mapCenterTab: some View {
        let isActive = selectedTab == .liveMap

        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                selectedTab = .liveMap
            }
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 9/255, green: 15/255, blue: 65/255),
                                Color(red: 55/255, green: 65/255, blue: 140/255)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                    .shadow(color: Color(red: 9/255, green: 15/255, blue: 65/255).opacity(isActive ? 0.4 : 0.2),
                            radius: isActive ? 10 : 6, x: 0, y: 3)

                Image(systemName: "location.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .offset(y: -10)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
