import SwiftUI

struct SideMenuView: View {
    @Binding var isShowing: Bool
    @Binding var selectedPage: AppPage
    @EnvironmentObject var authVM: AuthViewModel

    private let menuWidth: CGFloat = 280

    var body: some View {
        HStack(spacing: 0) {
            // Menu content
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        AvatarCircle(
                            initials: authVM.currentUser?.avatar ?? "A",
                            size: 44
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(authVM.currentUser?.name ?? "Admin")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                            Text(authVM.currentUser?.role ?? "Süper Yönetici")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "building.2")
                            .font(.system(size: 10))
                        Text("Arveya Teknoloji")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 13/255, green: 21/255, blue: 80/255),
                            AppTheme.navy
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

                // Menu items
                ScrollView {
                    VStack(spacing: 2) {
                        menuSection(title: "ANA MENÜ") {
                            menuItem(icon: "square.grid.2x2", label: "Dashboard", page: .dashboard)
                            menuItem(icon: "map.fill", label: "Canlı Harita", page: .liveMap)
                            menuItem(icon: "clock.arrow.circlepath", label: "Rota Geçmişi", page: .routeHistory)
                        }

                        menuSection(title: "FİLO YÖNETİMİ") {
                            menuItem(icon: "car.2.fill", label: "Araçlar", page: .vehicles)
                            menuItem(icon: "person.2.fill", label: "Sürücüler")
                            menuItem(icon: "wrench.and.screwdriver.fill", label: "Bakım")
                            menuItem(icon: "doc.text.fill", label: "Belgeler")
                            menuItem(icon: "turkishlirasign.circle.fill", label: "Masraflar")
                        }

                        menuSection(title: "İZLEME") {
                            menuItem(icon: "bell.fill", label: "Alarmlar")
                            menuItem(icon: "hexagon.fill", label: "Geofence")
                            menuItem(icon: "chart.bar.fill", label: "Raporlar")
                        }

                        menuSection(title: "AYARLAR") {
                            menuItem(icon: "gearshape.fill", label: "Ayarlar")
                        }

                        Divider()
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)

                        // Logout button
                        Button(action: {
                            withAnimation {
                                isShowing = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                authVM.logout()
                            }
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 15))
                                    .frame(width: 24)
                                Text("Çıkış Yap")
                                    .font(.system(size: 13, weight: .medium))
                                Spacer()
                            }
                            .foregroundColor(.red)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Version
                HStack {
                    Text("ArveyGo iOS v1.0.0")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textFaint)
                }
                .padding(16)
            }
            .frame(width: menuWidth)
            .background(AppTheme.surface)

            Spacer()
        }
        .offset(x: isShowing ? 0 : -menuWidth - 20)
    }

    // MARK: - Menu Section
    @ViewBuilder
    func menuSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(AppTheme.textFaint)
                .tracking(1)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 4)

            content()
        }
    }

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
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .frame(width: 24)
                    .foregroundColor(isActive ? AppTheme.indigo : AppTheme.textMuted)

                Text(label)
                    .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? AppTheme.navy : AppTheme.textSecondary)

                Spacer()

                if isActive {
                    Circle()
                        .fill(AppTheme.indigo)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(isActive ? AppTheme.indigo.opacity(0.06) : Color.clear)
            .cornerRadius(8)
            .padding(.horizontal, 8)
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
