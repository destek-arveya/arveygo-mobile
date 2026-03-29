import SwiftUI
import UIKit

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
    @State private var selectedTab: AppTab = .dashboard
    @State private var showSupportRequest = false

    // Legacy states kept for child views that still use them
    @State private var selectedPage: AppPage = .dashboard
    @State private var showSideMenu = false
    @State private var alarmsSearchText = ""
    @State private var alarmsAutoOpenCreate = false
    @State private var alarmsPrePlate = ""

    // Alarm glow effect
    @State private var alarmGlowing = false

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
        ZStack(alignment: .bottom) {
            // ── Active Page Content ──
            Group {
                switch selectedTab {
                case .dashboard:
                    DashboardView(
                        showSideMenu: $showSideMenu,
                        selectedPage: $selectedPage,
                        alarmsSearchText: $alarmsSearchText,
                        alarmsAutoOpenCreate: $alarmsAutoOpenCreate,
                        alarmsPrePlate: $alarmsPrePlate
                    )
                case .alarms:
                    AlarmsView(
                        showSideMenu: $showSideMenu,
                        initialSearchText: alarmsSearchText,
                        autoOpenCreate: alarmsAutoOpenCreate,
                        preSelectedPlate: alarmsPrePlate
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
                    HubView(selectedTab: $selectedTab)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // ── Custom Bottom Tab Bar ──
            customTabBar
        }
        .ignoresSafeArea(.keyboard)
        .onChange(of: selectedTab) { oldTab, newTab in
            // Clear alarm params when leaving alarms
            if oldTab == .alarms {
                alarmsSearchText = ""
                alarmsAutoOpenCreate = false
                alarmsPrePlate = ""
            }
        }
        .onChange(of: selectedPage) { _, newPage in
            // Sync legacy page changes to tabs
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
        .onChange(of: WebSocketManager.shared.consecutiveFailures) { _, failures in
            if failures >= WebSocketManager.maxConsecutiveFailures {
                showSupportRequest = true
            }
        }
        .fullScreenCover(isPresented: $showSupportRequest) {
            SupportRequestView()
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: — Custom Tab Bar
    // ═══════════════════════════════════════════════════════════════════════
    private var customTabBar: some View {
        HStack(spacing: 0) {
            tabBarItem(tab: .dashboard,  icon: "square.grid.2x2.fill",  label: "Özet")
            tabBarItem(tab: .alarms,     icon: "bell.fill",             label: "Alarmlar")
            liveMapCenterButton
            tabBarItem(tab: .fleet,      icon: "wrench.and.screwdriver.fill", label: "Filo")
            tabBarItem(tab: .hub,        icon: "circle.grid.2x2.fill",  label: "Hub")
        }
        .padding(.top, 10)
        .padding(.bottom, bottomSafeArea > 0 ? 20 : 10)
        .padding(.horizontal, 4)
        .background(
            ZStack {
                // Frosted glass background
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white.opacity(0.85))

                // Top border line
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color(red: 228/255, green: 231/255, blue: 240/255).opacity(0.6), lineWidth: 0.5)
            }
            .shadow(color: Color(red: 9/255, green: 15/255, blue: 65/255).opacity(0.08), radius: 20, x: 0, y: -6)
        )
        .padding(.horizontal, 8)
    }

    // ── Regular Tab Item ──
    private func tabBarItem(tab: AppTab, icon: String, label: String) -> some View {
        let isActive = selectedTab == tab
        let isAlarm = tab == .alarms

        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        }) {
            VStack(spacing: 4) {
                ZStack {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: isActive ? .bold : .regular))
                        .foregroundStyle(
                            isActive
                            ? Color(red: 9/255, green: 15/255, blue: 65/255)
                            : Color(red: 160/255, green: 160/255, blue: 175/255)
                        )
                        .symbolEffect(.bounce, value: isActive)

                    // Alarm glow effect
                    if isAlarm && alarmGlowing {
                        Circle()
                            .fill(Color(red: 239/255, green: 68/255, blue: 68/255).opacity(0.35))
                            .frame(width: 36, height: 36)
                            .blur(radius: 8)
                    }
                }
                .frame(width: 28, height: 28)

                Text(label)
                    .font(.system(size: 10, weight: isActive ? .bold : .medium))
                    .foregroundStyle(
                        isActive
                        ? Color(red: 9/255, green: 15/255, blue: 65/255)
                        : Color(red: 160/255, green: 160/255, blue: 175/255)
                    )
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
    }

    // ── Center Live Map Button — bigger, different style ──
    private var liveMapCenterButton: some View {
        let isActive = selectedTab == .liveMap

        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = .liveMap
            }
        }) {
            ZStack {
                // Glow ring when active
                if isActive {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 9/255, green: 15/255, blue: 65/255).opacity(0.15),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 36
                            )
                        )
                        .frame(width: 72, height: 72)
                }

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 9/255, green: 15/255, blue: 65/255),
                                Color(red: 74/255, green: 83/255, blue: 160/255)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(color: Color(red: 9/255, green: 15/255, blue: 65/255).opacity(0.3), radius: 12, x: 0, y: 4)

                Image(systemName: "map.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, value: isActive)
            }
            .offset(y: -12)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
    }

    // ── Bottom safe area helper ──
    private var bottomSafeArea: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .safeAreaInsets.bottom ?? 0
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
