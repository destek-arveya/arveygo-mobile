import SwiftUI

struct SideMenuView: View {
    @Binding var isShowing: Bool
    @Binding var selectedPage: AppPage
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject private var DL = DashboardStrings.shared

    private let menuWidth: CGFloat = 300

    var body: some View {
        HStack(spacing: 0) {
            // Menu content
            VStack(alignment: .leading, spacing: 0) {
                // ── Premium Header ──
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 14) {
                        // Avatar with gradient ring
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [AppTheme.indigo, AppTheme.lavender],
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
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            // Role badge
                            Text(authVM.currentUser?.role ?? "Süper Yönetici")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(AppTheme.lavender)
                                .tracking(0.5)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.12))
                                .cornerRadius(6)
                        }

                        Spacer()
                    }

                    Spacer().frame(height: 16)

                    // Company info card
                    HStack(spacing: 8) {
                        Image(systemName: "building.2")
                            .font(.system(size: 12))
                        Text(DL.menuCompany)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(10)
                }
                .padding(.horizontal, 24)
                .padding(.top, 56)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 10/255, green: 17/255, blue: 88/255),
                            Color(red: 9/255, green: 15/255, blue: 65/255),
                            Color(red: 6/255, green: 11/255, blue: 48/255)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // ── Menu items ──
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 2) {
                        menuSection(title: DL.menuSectionMain) {
                            menuItem(icon: "square.grid.2x2", label: DL.menuDashboard, page: .dashboard)
                            menuItem(icon: "map.fill", label: DL.menuLiveMap, page: .liveMap)
                            menuItem(icon: "clock.arrow.circlepath", label: DL.menuRouteHistory, page: .routeHistory)
                        }

                        menuSection(title: DL.menuSectionFleet) {
                            menuItem(icon: "car.2.fill", label: DL.menuVehicles, page: .vehicles)
                            menuItem(icon: "person.2.fill", label: DL.menuDrivers, page: .drivers)
                            menuItem(icon: "wrench.and.screwdriver.fill", label: DL.menuMaintenance, page: .fleetManagement)
                        }

                        menuSection(title: DL.menuSectionMonitor) {
                            menuItem(icon: "bell.fill", label: DL.menuAlarms, page: .alarms)
                            menuItem(icon: "hexagon.fill", label: DL.menuGeofence, page: .geofences)
                            menuItem(icon: "chart.bar.fill", label: DL.menuReports, page: .reports)
                        }

                        menuSection(title: DL.menuSectionSettings) {
                            menuItem(icon: "gearshape.fill", label: DL.menuSettings, page: .settings)
                        }

                        menuSection(title: DL.menuSectionSupport) {
                            menuItem(icon: "questionmark.circle.fill", label: DL.menuSupport, page: .support)
                        }

                        Spacer().frame(height: 8)

                        Divider()
                            .padding(.horizontal, 20)
                            .opacity(0.6)

                        Spacer().frame(height: 4)

                        // Logout button — modern style
                        Button(action: {
                            withAnimation {
                                isShowing = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                authVM.logout()
                            }
                        }) {
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 9)
                                    .fill(Color.red.opacity(0.08))
                                    .frame(width: 34, height: 34)
                                    .overlay(
                                        Image(systemName: "rectangle.portrait.and.arrow.right")
                                            .font(.system(size: 14))
                                            .foregroundColor(.red.opacity(0.8))
                                    )

                                Text(DL.menuLogout)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.red.opacity(0.8))

                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                        }
                        .padding(.horizontal, 12)
                    }
                    .padding(.vertical, 12)
                }

                // ── Version Footer ──
                HStack(spacing: 8) {
                    Circle()
                        .fill(AppTheme.online)
                        .frame(width: 6, height: 6)
                    Text("ArveyGo iOS v1.0.0")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textFaint)
                        .tracking(0.3)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .frame(width: menuWidth)
            .background(AppTheme.surface)
            .shadow(color: .black.opacity(0.15), radius: 24, x: 8, y: 0)

            Spacer()
        }
        .offset(x: isShowing ? 0 : -menuWidth - 20)
    }

    // MARK: - Menu Section
    @ViewBuilder
    func menuSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(AppTheme.textFaint.opacity(0.7))
                .tracking(1.2)
                .padding(.leading, 24)
                .padding(.top, 20)
                .padding(.bottom, 8)

            content()
        }
    }

    // MARK: - Menu Item
    @ViewBuilder
    func menuItem(icon: String, label: String, page: AppPage? = nil) -> some View {
        let isActive = page != nil && selectedPage == page
        Button(action: {
            if let page = page {
                withAnimation(.spring(response: 0.3)) {
                    selectedPage = page
                    isShowing = false
                }
            } else {
                withAnimation(.spring(response: 0.3)) {
                    isShowing = false
                }
            }
        }) {
            HStack(spacing: 12) {
                // Icon with background box
                RoundedRectangle(cornerRadius: 9)
                    .fill(isActive ? AppTheme.indigo.opacity(0.12) : AppTheme.bg)
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 14))
                            .foregroundColor(isActive ? AppTheme.indigo : AppTheme.textMuted)
                    )

                Text(label)
                    .font(.system(size: 14, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? AppTheme.navy : AppTheme.textSecondary)
                    .lineLimit(1)

                Spacer()

                if isActive {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppTheme.indigo)
                        .frame(width: 3, height: 20)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                isActive
                    ? LinearGradient(
                        colors: [AppTheme.indigo.opacity(0.10), AppTheme.indigo.opacity(0.04)],
                        startPoint: .leading,
                        endPoint: .trailing
                      )
                    : LinearGradient(colors: [.clear, .clear], startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(12)
            .padding(.horizontal, 12)
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3).ignoresSafeArea()
        SideMenuView(isShowing: .constant(true), selectedPage: .constant(.dashboard))
            .environmentObject(AuthViewModel())
    }
}
