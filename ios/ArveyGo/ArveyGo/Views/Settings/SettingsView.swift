import SwiftUI

struct SettingsView: View {
    @Binding var showSideMenu: Bool
    @ObservedObject private var DL = DashboardStrings.shared
    @ObservedObject private var LS = LoginStrings.shared
    @ObservedObject private var themeManager = ThemeManager.shared

    private let languages: [(code: String, flag: String)] = [
        ("TR", "🇹🇷"),
        ("EN", "🇬🇧"),
        ("ES", "🇪🇸"),
        ("FR", "🇫🇷")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.bg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        // ── GENEL ──
                        sectionCard(title: DL.settingsTitle.uppercased()) {
                            // Language — compact horizontal chips
                            VStack(spacing: 0) {
                                HStack(spacing: 10) {
                                    sectionIcon("globe", color: AppTheme.indigo)
                                    Text(DL.languageLabel)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(AppTheme.navy)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 13)
                                .padding(.bottom, 10)

                                HStack(spacing: 8) {
                                    ForEach(languages, id: \.code) { lang in
                                        Button {
                                            withAnimation(.easeInOut(duration: 0.15)) {
                                                LS.currentLang = lang.code
                                                DL.currentLang = lang.code
                                            }
                                        } label: {
                                            HStack(spacing: 5) {
                                                Text(lang.flag).font(.system(size: 14))
                                                Text(lang.code)
                                                    .font(.system(size: 11, weight: .semibold))
                                                    .foregroundColor(LS.currentLang == lang.code ? .white : AppTheme.navy)
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 7)
                                            .background(LS.currentLang == lang.code ? AppTheme.indigo : AppTheme.bg)
                                            .cornerRadius(8)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 13)
                            }

                            Divider().padding(.leading, 52)

                            // ── Tema Seçimi ──
                            VStack(spacing: 0) {
                                HStack(spacing: 10) {
                                    sectionIcon("circle.lefthalf.filled", color: AppTheme.indigo)
                                    Text(themeLabel)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(AppTheme.navy)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 13)
                                .padding(.bottom, 10)

                                HStack(spacing: 8) {
                                    ForEach(ThemeManager.ThemeMode.allCases, id: \.rawValue) { mode in
                                        Button {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                themeManager.mode = mode
                                            }
                                        } label: {
                                            HStack(spacing: 5) {
                                                Text(mode.label).font(.system(size: 14))
                                                Text(mode.title)
                                                    .font(.system(size: 11, weight: .semibold))
                                                    .foregroundColor(themeManager.mode == mode ? .white : AppTheme.navy)
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 7)
                                            .background(themeManager.mode == mode ? AppTheme.indigo : AppTheme.bg)
                                            .cornerRadius(8)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 13)
                            }

                            Divider().padding(.leading, 52)

                            // Bildirim Ayarları
                            NavigationLink(destination: NotificationSettingsView()) {
                                rowContent(icon: "bell.badge.fill", iconColor: Color(hex: "#EF4444"),
                                           title: DL.notificationSettings,
                                           subtitle: DL.notificationSettingsSubtitle,
                                           showChevron: true)
                            }
                            .buttonStyle(.plain)
                        }

                        // ── UYGULAMA BİLGİSİ ──
                        sectionCard(title: DL.appInfoTitle.uppercased()) {
                            infoRow(icon: "app.badge", label: DL.appInfoApp, value: "ArveyGo v1.0.0")
                            Divider().padding(.leading, 52)
                            infoRow(icon: "apple.logo", label: DL.appInfoPlatform, value: "iOS \(UIDevice.current.systemVersion)")
                            Divider().padding(.leading, 52)
                            infoRow(icon: "building.2", label: DL.appInfoDeveloper, value: "Arveya Teknoloji")
                        }

                        // ── YASAL ──
                        sectionCard(title: DL.legalTitle.uppercased()) {
                            rowContent(icon: "doc.text", iconColor: AppTheme.indigo,
                                       title: DL.termsOfUse, subtitle: nil, showChevron: true)
                            Divider().padding(.leading, 52)
                            rowContent(icon: "hand.raised.fill", iconColor: AppTheme.indigo,
                                       title: DL.privacyPolicy, subtitle: nil, showChevron: true)
                        }

                        // Footer
                        VStack(spacing: 4) {
                            Text("© 2026 Arveya Teknoloji A.Ş.")
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.textMuted)
                            Text(DL.allRightsReserved)
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.textMuted.opacity(0.6))
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text(DL.settingsTitle)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.navy)
                }
            }
        }
    }

    // MARK: - Theme label
    private var themeLabel: String {
        DL.currentLang == "EN" ? "Theme" : "Tema"
    }

    // MARK: - Components

    @ViewBuilder
    private func sectionCard(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppTheme.textMuted)
                .tracking(0.5)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(AppTheme.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.borderSoft, lineWidth: 1)
            )
        }
    }

    private func sectionIcon(_ name: String, color: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 14))
            .foregroundColor(color)
            .frame(width: 28, height: 28)
    }

    @ViewBuilder
    private func rowContent(icon: String, iconColor: Color, title: String, subtitle: String?, showChevron: Bool) -> some View {
        HStack(spacing: 10) {
            sectionIcon(icon, color: iconColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.navy)
                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textMuted)
                }
            }
            Spacer()
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.textMuted.opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            sectionIcon(icon, color: AppTheme.indigo)
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.navy)
            Spacer()
            Text(value)
                .font(.system(size: 12))
                .foregroundColor(AppTheme.textMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    SettingsView(showSideMenu: .constant(false))
}
