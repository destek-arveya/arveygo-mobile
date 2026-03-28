import SwiftUI

struct SettingsView: View {
    @Binding var showSideMenu: Bool
    @ObservedObject private var DL = DashboardStrings.shared
    @ObservedObject private var LS = LoginStrings.shared
    @ObservedObject private var tokenStore = DeviceTokenStore.shared
    @State private var isChangingLang = false
    @State private var tokenCopied = false

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

                        // ── Push Notification / Device Token Section ──
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "bell.badge")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.indigo)
                                Text("PUSH BİLDİRİM".uppercased())
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(AppTheme.textMuted)
                                    .tracking(1)
                            }

                            VStack(spacing: 0) {
                                // Request permission + get token button
                                Button(action: {
                                    AppDelegate.requestPushPermission()
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "bell.and.waves.left.and.right")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white)
                                            .frame(width: 28, height: 28)
                                            .background(AppTheme.indigo)
                                            .cornerRadius(7)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Device Token Al")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(AppTheme.navy)
                                            Text("APNs izni iste ve token'ı al")
                                                .font(.system(size: 11))
                                                .foregroundColor(AppTheme.textMuted)
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.right.circle")
                                            .font(.system(size: 16))
                                            .foregroundColor(AppTheme.indigo)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                }
                                .buttonStyle(.plain)

                                // Show token if available
                                if let token = tokenStore.token {
                                    Divider().padding(.leading, 44)

                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "key.fill")
                                                .font(.system(size: 11))
                                                .foregroundColor(Color(hex: "#16A34A"))
                                            Text("Device Token")
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundColor(Color(hex: "#16A34A"))
                                        }

                                        Text(token)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(AppTheme.textSecondary)
                                            .textSelection(.enabled)
                                            .lineLimit(nil)
                                            .fixedSize(horizontal: false, vertical: true)

                                        Button(action: {
                                            UIPasteboard.general.string = token
                                            withAnimation { tokenCopied = true }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                                withAnimation { tokenCopied = false }
                                            }
                                        }) {
                                            HStack(spacing: 6) {
                                                Image(systemName: tokenCopied ? "checkmark" : "doc.on.doc")
                                                    .font(.system(size: 12))
                                                Text(tokenCopied ? "Kopyalandı!" : "Token'ı Kopyala")
                                                    .font(.system(size: 12, weight: .semibold))
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(tokenCopied ? Color(hex: "#16A34A") : AppTheme.indigo)
                                            .foregroundColor(.white)
                                            .cornerRadius(8)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                }
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
            .overlay {
                if isChangingLang {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        VStack(spacing: 14) {
                            ProgressView()
                                .scaleEffect(1.3)
                                .tint(.white)
                            Text(DL.languageLabel)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(28)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                    }
                    .transition(.opacity)
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
