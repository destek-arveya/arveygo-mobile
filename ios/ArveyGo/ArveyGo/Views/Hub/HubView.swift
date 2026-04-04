import SwiftUI

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Hub View — "Diğer Her Şey" merkezi
// ═══════════════════════════════════════════════════════════════════════════
struct HubView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var DL = DashboardStrings.shared
    @Binding var selectedTab: AppTab

    // Alarm navigation bridge from child views
    @Binding var alarmsSearchText: String
    @Binding var alarmsAutoOpenCreate: Bool
    @Binding var alarmsPrePlate: String

    // Internal navigation
    @State private var navigateToReports = false
    @State private var navigateToGeofence = false
    @State private var navigateToRouteHistory = false
    @State private var navigateToDrivers = false
    @State private var navigateToVehicles = false
    @State private var navigateToSettings = false
    @State private var navigateToSupport = false

    // Vehicles → Alarms bridge
    @State private var vehiclesSelectedPage: AppPage = .vehicles
    @State private var vehiclesAlarmsSearch: String = ""
    @State private var vehiclesAlarmsAutoOpen: Bool = false
    @State private var vehiclesAlarmsPrePlate: String = ""

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

    private var isDark: Bool { colorScheme == .dark }
    private var pageBackground: Color {
        isDark ? Color(red: 12/255, green: 17/255, blue: 36/255) : H.pageBg
    }
    private var navigationBackground: Color {
        isDark ? Color(red: 14/255, green: 20/255, blue: 42/255) : H.pageBg
    }
    private var cardBackground: Color {
        isDark ? Color(red: 23/255, green: 29/255, blue: 54/255) : H.cardBg
    }
    private var primaryText: Color {
        isDark ? AppTheme.darkText : H.text1
    }
    private var secondaryText: Color {
        isDark ? AppTheme.darkTextSub : H.text2
    }
    private var mutedText: Color {
        isDark ? AppTheme.darkTextMuted : H.text3
    }
    private var cardShadow: Color {
        isDark ? Color.black.opacity(0.24) : Color.black.opacity(0.05)
    }
    private var borderColor: Color {
        isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
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

                    // ── Logout ──
                    logoutButton
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                }
                .padding(.top, 4)
            }
            .background(pageBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(navigationBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(isDark ? .dark : .light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(DL.t("Merkez", "Hub", "Centro", "Hub"))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(primaryText)
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
                    selectedPage: $vehiclesSelectedPage,
                    alarmsSearchText: $vehiclesAlarmsSearch,
                    alarmsAutoOpenCreate: $vehiclesAlarmsAutoOpen,
                    alarmsPrePlate: $vehiclesAlarmsPrePlate
                )
                .onChange(of: vehiclesSelectedPage) { _, newPage in
                    if newPage == .alarms {
                        let search = vehiclesAlarmsSearch
                        let autoOpen = vehiclesAlarmsAutoOpen
                        let prePlate = vehiclesAlarmsPrePlate
                        navigateToVehicles = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            alarmsSearchText = search
                            alarmsAutoOpenCreate = autoOpen
                            alarmsPrePlate = prePlate
                            selectedTab = .alarms
                            vehiclesSelectedPage = .vehicles
                            vehiclesAlarmsSearch = ""
                            vehiclesAlarmsAutoOpen = false
                            vehiclesAlarmsPrePlate = ""
                        }
                    } else if newPage == .routeHistory {
                        navigateToVehicles = false
                        vehiclesSelectedPage = .vehicles
                    }
                }
            }
            .navigationDestination(isPresented: $navigateToSupport) {
                SupportRequestView(presentationMode: .push)
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
                    .foregroundColor(primaryText)

                Text(authVM.currentUser?.role ?? DL.t("Süper Yönetici", "Super Admin", "Superadministrador", "Super administrateur"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(H.primary.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(H.primary.opacity(0.08))
                    .clipShape(Capsule())
            }

            Spacer()

            Button(action: { navigateToSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isDark ? Color.white : H.primary)
                    .frame(width: 42, height: 42)
                    .background(H.primary.opacity(isDark ? 0.18 : 0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(borderColor, lineWidth: 1)
                    )
            }
            .accessibilityLabel(DL.menuSettings)
        }
        .padding(18)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: H.r, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: H.r, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .shadow(color: cardShadow, radius: 12, x: 0, y: 4)
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
                        .foregroundStyle(primaryText)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(mutedText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 140)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: H.r, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: H.r, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .shadow(color: color.opacity(isDark ? 0.12 : 0.08), radius: 12, x: 0, y: 4)
            .shadow(color: cardShadow.opacity(0.45), radius: 4, x: 0, y: 2)
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
            .background((isDark ? Color.red.opacity(0.14) : Color.red.opacity(0.06)))
            .clipShape(RoundedRectangle(cornerRadius: H.r, style: .continuous))
        }
        .buttonStyle(HubBounceStyle())
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: — Helpers
    // ═══════════════════════════════════════════════════════════════════════
    private func hubSubtitle(_ key: String) -> String {
        switch key {
        case "reports":
            return DL.t("Filo raporları ve analiz", "Fleet reports & analytics", "Informes y analítica de flota", "Rapports et analyses de flotte")
        case "geofence":
            return DL.t("Sanal sınırlar ve bölgeler", "Virtual boundaries", "Límites virtuales", "Limites virtuelles")
        case "routeHistory":
            return DL.t("Geçmiş seferler ve rotalar", "Past trips & routes", "Viajes y rutas anteriores", "Trajets et itinéraires passés")
        case "drivers":
            return DL.t("Sürücü yönetimi", "Driver management", "Gestión de conductores", "Gestion des conducteurs")
        case "vehicles":
            return DL.t("Tüm filo araçları", "All fleet vehicles", "Todos los vehículos de la flota", "Tous les véhicules de la flotte")
        case "support":
            return DL.t("Yardım ve destek", "Help & support", "Ayuda y soporte", "Aide et assistance")
        default:
            return ""
        }
    }

    private var settingsSubtitle: String {
        DL.t("Dil, bildirimler, uygulama bilgisi", "Language, notifications, app info", "Idioma, notificaciones, información de la app", "Langue, notifications, infos de l'app")
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
    HubView(
        selectedTab: .constant(.hub),
        alarmsSearchText: .constant(""),
        alarmsAutoOpenCreate: .constant(false),
        alarmsPrePlate: .constant("")
    )
    .environmentObject(AuthViewModel())
}
