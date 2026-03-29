import SwiftUI

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Hub View — "Diğer Her Şey" merkezi
// ═══════════════════════════════════════════════════════════════════════════
struct HubView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject private var DL = DashboardStrings.shared
    @Binding var selectedTab: AppTab

    // Internal navigation
    @State private var navigateToReports = false
    @State private var navigateToGeofence = false
    @State private var navigateToRouteHistory = false
    @State private var navigateToDrivers = false
    @State private var navigateToVehicles = false
    @State private var navigateToSettings = false
    @State private var navigateToSupport = false

    // ── Design System (matches Dashboard DS) ──
    private enum H {
        static let primary      = Color(red: 9/255, green: 15/255, blue: 65/255)
        static let primaryLight = Color(red: 74/255, green: 83/255, blue: 160/255)
        static let pageBg       = Color(red: 245/255, green: 246/255, blue: 250/255)
        static let cardBg       = Color.white
        static let text1        = Color(red: 26/255, green: 26/255, blue: 26/255)
        static let text2        = Color(red: 100/255, green: 100/255, blue: 112/255)
        static let text3        = Color(red: 160/255, green: 160/255, blue: 175/255)
        static let r: CGFloat   = 22
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // ── User Header ──
                    userHeader
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    // ── Quick Access Grid ──
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 14),
                        GridItem(.flexible(), spacing: 14)
                    ], spacing: 14) {
                        hubCard(
                            icon: "chart.bar.fill",
                            title: DL.menuReports,
                            subtitle: hubSubtitle("reports"),
                            color: Color(red: 99/255, green: 102/255, blue: 241/255), // indigo
                            action: { navigateToReports = true }
                        )
                        hubCard(
                            icon: "hexagon.fill",
                            title: DL.menuGeofence,
                            subtitle: hubSubtitle("geofence"),
                            color: Color(red: 16/255, green: 185/255, blue: 129/255), // emerald
                            action: { navigateToGeofence = true }
                        )
                        hubCard(
                            icon: "clock.arrow.circlepath",
                            title: DL.menuRouteHistory,
                            subtitle: hubSubtitle("routeHistory"),
                            color: Color(red: 245/255, green: 158/255, blue: 11/255), // amber
                            action: { navigateToRouteHistory = true }
                        )
                        hubCard(
                            icon: "person.2.fill",
                            title: DL.menuDrivers,
                            subtitle: hubSubtitle("drivers"),
                            color: Color(red: 56/255, green: 147/255, blue: 241/255), // sky
                            action: { navigateToDrivers = true }
                        )
                        hubCard(
                            icon: "car.2.fill",
                            title: DL.menuVehicles,
                            subtitle: hubSubtitle("vehicles"),
                            color: Color(red: 139/255, green: 92/255, blue: 246/255), // violet
                            action: { navigateToVehicles = true }
                        )
                        hubCard(
                            icon: "questionmark.circle.fill",
                            title: DL.menuSupport,
                            subtitle: hubSubtitle("support"),
                            color: Color(red: 236/255, green: 72/255, blue: 153/255), // pink
                            action: { navigateToSupport = true }
                        )
                    }
                    .padding(.horizontal, 20)

                    // ── Settings Row ──
                    settingsRow
                        .padding(.horizontal, 20)

                    // ── Logout ──
                    logoutButton
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                }
                .padding(.top, 4)
            }
            .background(H.pageBg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Hub")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(H.primary)
                }
            }
            // ── Navigation Destinations ──
            .navigationDestination(isPresented: $navigateToReports) {
                ReportsView(showSideMenu: .constant(false))
            }
            .navigationDestination(isPresented: $navigateToGeofence) {
                GeofencesView(showSideMenu: .constant(false))
            }
            .navigationDestination(isPresented: $navigateToRouteHistory) {
                RouteHistoryView(showSideMenu: .constant(false))
            }
            .navigationDestination(isPresented: $navigateToDrivers) {
                DriversView(showSideMenu: .constant(false))
            }
            .navigationDestination(isPresented: $navigateToVehicles) {
                VehiclesListView(
                    showSideMenu: .constant(false),
                    selectedPage: .constant(.vehicles),
                    alarmsSearchText: .constant(""),
                    alarmsAutoOpenCreate: .constant(false),
                    alarmsPrePlate: .constant("")
                )
            }
            .navigationDestination(isPresented: $navigateToSupport) {
                SupportRequestView()
            }
            .navigationDestination(isPresented: $navigateToSettings) {
                SettingsView(showSideMenu: .constant(false))
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: — User Header
    // ═══════════════════════════════════════════════════════════════════════
    private var userHeader: some View {
        HStack(spacing: 14) {
            // Avatar ring
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [H.primary, H.primaryLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)

                Circle()
                    .fill(Color(red: 26/255, green: 32/255, blue: 96/255))
                    .frame(width: 48, height: 48)

                Text(authVM.currentUser?.avatar ?? "A")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(authVM.currentUser?.name ?? "Admin")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(H.text1)

                Text(authVM.currentUser?.role ?? "Süper Yönetici")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(H.primary.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(H.primary.opacity(0.08))
                    .clipShape(Capsule())
            }

            Spacer()

            // Company badge
            VStack(spacing: 2) {
                Image(systemName: "building.2")
                    .font(.system(size: 14))
                    .foregroundStyle(H.text3)
                Text(DL.menuCompany)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(H.text3)
            }
        }
        .padding(18)
        .background(H.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: H.r, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 4)
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: — Hub Card
    // ═══════════════════════════════════════════════════════════════════════
    private func hubCard(icon: String, title: String, subtitle: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(color.opacity(0.12))
                        .frame(width: 48, height: 48)

                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(color)
                }

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(H.text1)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(H.text3)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 140)
            .background(H.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: H.r, style: .continuous))
            .shadow(color: color.opacity(0.08), radius: 12, x: 0, y: 4)
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(HubBounceStyle())
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: — Settings Row
    // ═══════════════════════════════════════════════════════════════════════
    private var settingsRow: some View {
        Button(action: { navigateToSettings = true }) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(H.primary.opacity(0.08))
                        .frame(width: 48, height: 48)

                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(H.primary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(DL.menuSettings)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(H.text1)
                    Text(settingsSubtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(H.text3)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(H.text3)
            }
            .padding(18)
            .background(H.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: H.r, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(HubBounceStyle())
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: — Logout
    // ═══════════════════════════════════════════════════════════════════════
    private var logoutButton: some View {
        Button(action: { authVM.logout() }) {
            HStack(spacing: 12) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.red.opacity(0.8))

                Text(DL.menuLogout)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.red.opacity(0.8))

                Spacer()
            }
            .padding(18)
            .background(Color.red.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: H.r, style: .continuous))
        }
        .buttonStyle(HubBounceStyle())
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: — Helpers
    // ═══════════════════════════════════════════════════════════════════════
    private func hubSubtitle(_ key: String) -> String {
        let lang = DL.currentLang
        switch key {
        case "reports":
            return lang == "EN" ? "Fleet reports & analytics" : "Filo raporları ve analiz"
        case "geofence":
            return lang == "EN" ? "Virtual boundaries" : "Sanal sınırlar & bölgeler"
        case "routeHistory":
            return lang == "EN" ? "Past trips & routes" : "Geçmiş seferler & rotalar"
        case "drivers":
            return lang == "EN" ? "Driver management" : "Sürücü yönetimi"
        case "vehicles":
            return lang == "EN" ? "All fleet vehicles" : "Tüm filo araçları"
        case "support":
            return lang == "EN" ? "Help & support" : "Yardım ve destek"
        default:
            return ""
        }
    }

    private var settingsSubtitle: String {
        DL.currentLang == "EN" ? "Language, notifications, app info" : "Dil, bildirimler, uygulama bilgisi"
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Hub Bounce Button Style
// ═══════════════════════════════════════════════════════════════════════════
struct HubBounceStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Preview
// ═══════════════════════════════════════════════════════════════════════════
#Preview {
    HubView(selectedTab: .constant(.hub))
        .environmentObject(AuthViewModel())
}
