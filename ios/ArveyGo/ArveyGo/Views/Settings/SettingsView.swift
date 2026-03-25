import SwiftUI

struct SettingsView: View {
    @Binding var showSideMenu: Bool
    @ObservedObject private var DL = DashboardStrings.shared
    @ObservedObject private var LS = LoginStrings.shared

    private let languages: [(code: String, flag: String, name: String)] = [
        ("TR", "🇹🇷", "Türkçe"),
        ("EN", "🇬🇧", "English"),
        ("ES", "🇪🇸", "Español"),
        ("FR", "🇫🇷", "Français")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.bg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Language Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "globe")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.indigo)
                                Text(DL.languageLabel.uppercased())
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(AppTheme.textMuted)
                                    .tracking(1)
                            }

                            VStack(spacing: 0) {
                                ForEach(languages, id: \.code) { lang in
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            LS.currentLang = lang.code
                                            DL.currentLang = lang.code
                                        }
                                    }) {
                                        HStack(spacing: 12) {
                                            Text(lang.flag)
                                                .font(.system(size: 22))
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(lang.name)
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(AppTheme.navy)
                                                Text(lang.code)
                                                    .font(.system(size: 11))
                                                    .foregroundColor(AppTheme.textMuted)
                                            }
                                            Spacer()
                                            if LS.currentLang == lang.code {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 20))
                                                    .foregroundColor(AppTheme.indigo)
                                            } else {
                                                Circle()
                                                    .stroke(AppTheme.borderSoft, lineWidth: 1.5)
                                                    .frame(width: 20, height: 20)
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                        .background(LS.currentLang == lang.code ? AppTheme.indigo.opacity(0.06) : Color.clear)
                                    }
                                    .buttonStyle(.plain)

                                    if lang.code != languages.last?.code {
                                        Divider().padding(.leading, 52)
                                    }
                                }
                            }
                            .background(AppTheme.surface)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppTheme.borderSoft, lineWidth: 1)
                            )
                        }

                        // App Info Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.indigo)
                                Text(DL.appInfoTitle.uppercased())
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(AppTheme.textMuted)
                                    .tracking(1)
                            }

                            VStack(spacing: 0) {
                                settingsRow(icon: "app.badge", label: "ArveyGo", value: "v1.0.0")
                                Divider().padding(.leading, 44)
                                settingsRow(icon: "apple.logo", label: "Platform", value: "iOS")
                                Divider().padding(.leading, 44)
                                settingsRow(icon: "building.2", label: "Arveya Teknoloji", value: "© 2026")
                            }
                            .background(AppTheme.surface)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppTheme.borderSoft, lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { withAnimation(.spring(response: 0.3)) { showSideMenu.toggle() } }) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(AppTheme.navy)
                    }
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text(DL.settingsTitle)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.navy)
                    }
                }
            }
        }
    }

    func settingsRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.indigo)
                .frame(width: 28)
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.navy)
            Spacer()
            Text(value)
                .font(.system(size: 12))
                .foregroundColor(AppTheme.textMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

#Preview {
    SettingsView(showSideMenu: .constant(false))
}
