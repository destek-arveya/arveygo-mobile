import SwiftUI

struct SettingsView: View {
    enum LegalDocument: String, Identifiable {
        case terms
        case privacy

        var id: String { rawValue }

        var title: String {
            switch self {
            case .terms: return "Kullanım Koşulları"
            case .privacy: return "Gizlilik Politikası"
            }
        }

        var summary: String {
            switch self {
            case .terms:
                return "Platformu kullanırken hesap güvenliği, veri doğruluğu ve kullanım sınırları bu dokümanda açıklanır."
            case .privacy:
                return "Konum, araç telemetrisi ve hesap verilerinin nasıl işlendiği ve korunduğu bu dokümanda yer alır."
            }
        }
    }

    @Binding var showSideMenu: Bool
    @ObservedObject private var DL = DashboardStrings.shared
    @ObservedObject private var LS = LoginStrings.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) private var colorScheme

    @State private var activeDocument: LegalDocument?

    private var ds: DS { DS(isDark: colorScheme == .dark) }
    private var isDark: Bool { colorScheme == .dark }

    private let languages: [(code: String, flag: String, label: String)] = [
        ("TR", "🇹🇷", "Türkçe"),
        ("EN", "🇬🇧", "English"),
        ("ES", "🇪🇸", "Español"),
        ("FR", "🇫🇷", "Français")
    ]

    private var surface: Color {
        isDark ? Color(red: 18/255, green: 24/255, blue: 47/255) : .white
    }

    private var surfaceAlt: Color {
        isDark ? Color.white.opacity(0.04) : Color.black.opacity(0.025)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    isDark ? Color(red: 10/255, green: 14/255, blue: 31/255) : Color(red: 242/255, green: 245/255, blue: 252/255),
                    ds.pageBg
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    settingsHero
                    preferencesCard
                    navigationCard
                    appInfoCard
                    legalCard
                    footerBlock
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(ds.pageBg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(isDark ? .dark : .light, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(DL.settingsTitle)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(ds.text1)
                    Text("Tercihler ve uygulama ayarları")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ds.text3)
                }
            }
        }
        .sheet(item: $activeDocument) { document in
            NavigationStack {
                legalDocumentSheet(document)
            }
        }
    }

    private var settingsHero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.navy, AppTheme.indigo],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 54, height: 54)

                    Image(systemName: "gearshape.2.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Kontrol ve kişiselleştirme")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(ds.text1)
                    Text("Dil, tema, bildirim ve uygulama tercihlerini tek bir merkezden yönet.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(ds.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                settingsStat(title: "Dil", value: LS.currentLang)
                settingsStat(title: "Tema", value: themeManager.mode.title)
                settingsStat(title: "Sürüm", value: "1.0.0")
            }
        }
        .padding(20)
        .background(surface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(ds.divider, lineWidth: 1)
        )
        .shadow(color: ds.cardShadow, radius: 14, x: 0, y: 6)
    }

    private func settingsStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ds.text3)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ds.text1)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(surfaceAlt, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(ds.divider, lineWidth: 1)
        )
    }

    private var preferencesCard: some View {
        settingsCard(title: "Tercihler", subtitle: "Günlük kullanım için temel ayarlar") {
            VStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    settingsSectionHeader(icon: "globe", title: DL.languageLabel, detail: "Arayüz dilini seç")

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(languages, id: \.code) { language in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    LS.currentLang = language.code
                                    DL.currentLang = language.code
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Text(language.flag)
                                        .font(.system(size: 16))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(language.label)
                                            .font(.system(size: 14, weight: .semibold))
                                        Text(language.code)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(LS.currentLang == language.code ? .white.opacity(0.82) : ds.text3)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .foregroundStyle(LS.currentLang == language.code ? Color.white : ds.text1)
                                .padding(.horizontal, 14)
                                .frame(height: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(LS.currentLang == language.code ? AnyShapeStyle(AppTheme.buttonGradient) : AnyShapeStyle(surfaceAlt))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(LS.currentLang == language.code ? Color.white.opacity(0.10) : ds.divider, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Divider().overlay(ds.divider)

                VStack(alignment: .leading, spacing: 12) {
                    settingsSectionHeader(icon: "circle.lefthalf.filled", title: themeLabel, detail: "Uygulamanın görünüm modunu belirle")

                    HStack(spacing: 10) {
                        ForEach(ThemeManager.ThemeMode.allCases, id: \.rawValue) { mode in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    themeManager.mode = mode
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(mode.label)
                                        .font(.system(size: 18))
                                    Text(mode.title)
                                        .font(.system(size: 14, weight: .semibold))
                                    Text(modeDescription(mode))
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(themeManager.mode == mode ? .white.opacity(0.82) : ds.text3)
                                        .lineLimit(2)
                                }
                                .foregroundStyle(themeManager.mode == mode ? Color.white : ds.text1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(themeManager.mode == mode ? AnyShapeStyle(AppTheme.buttonGradient) : AnyShapeStyle(surfaceAlt))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(themeManager.mode == mode ? Color.white.opacity(0.10) : ds.divider, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var navigationCard: some View {
        settingsCard(title: "Uygulama", subtitle: "Bildirim ve erişim tercihleri") {
            VStack(spacing: 0) {
                NavigationLink(destination: NotificationSettingsView()) {
                    settingsRow(
                        icon: "bell.badge.fill",
                        tint: Color(hex: "#EF4444"),
                        title: DL.notificationSettings,
                        subtitle: DL.notificationSettingsSubtitle
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var appInfoCard: some View {
        settingsCard(title: DL.appInfoTitle, subtitle: "Sürüm ve platform bilgileri") {
            VStack(spacing: 0) {
                infoRow(icon: "app.badge.fill", label: DL.appInfoApp, value: "ArveyGo v1.0.0")
                Divider().overlay(ds.divider).padding(.leading, 54)
                infoRow(icon: "iphone.gen3", label: DL.appInfoPlatform, value: "iOS \(UIDevice.current.systemVersion)")
                Divider().overlay(ds.divider).padding(.leading, 54)
                infoRow(icon: "building.2.fill", label: DL.appInfoDeveloper, value: "Arveya Teknoloji")
            }
        }
    }

    private var legalCard: some View {
        settingsCard(title: DL.legalTitle, subtitle: "Yasal metinler ve kullanım çerçevesi") {
            VStack(spacing: 0) {
                Button { activeDocument = .terms } label: {
                    settingsRow(icon: "doc.text.fill", tint: AppTheme.indigo, title: DL.termsOfUse, subtitle: "Hizmet kullanım koşullarını incele")
                }
                .buttonStyle(.plain)

                Divider().overlay(ds.divider).padding(.leading, 54)

                Button { activeDocument = .privacy } label: {
                    settingsRow(icon: "hand.raised.fill", tint: AppTheme.online, title: DL.privacyPolicy, subtitle: "Veri işleme ve gizlilik yaklaşımı")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var footerBlock: some View {
        VStack(spacing: 4) {
            Text("© 2026 Arveya Teknoloji A.Ş.")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ds.text3)
            Text(DL.allRightsReserved)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ds.text3.opacity(0.72))
        }
        .padding(.top, 2)
    }

    private func settingsCard<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(ds.text1)
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ds.text2)
            }

            content()
        }
        .padding(18)
        .background(surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(ds.divider, lineWidth: 1)
        )
        .shadow(color: ds.cardShadow, radius: 12, x: 0, y: 5)
    }

    private func settingsSectionHeader(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.indigo)
                .frame(width: 34, height: 34)
                .background(AppTheme.indigo.opacity(isDark ? 0.18 : 0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(ds.text1)
                Text(detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ds.text3)
            }

            Spacer()
        }
    }

    private func settingsRow(icon: String, tint: Color, title: String, subtitle: String?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(tint.opacity(isDark ? 0.18 : 0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(ds.text1)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(ds.text2)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ds.text3.opacity(0.8))
        }
        .contentShape(Rectangle())
        .padding(.vertical, 12)
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.indigo)
                .frame(width: 38, height: 38)
                .background(AppTheme.indigo.opacity(isDark ? 0.18 : 0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(ds.text1)
                Text(value)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ds.text2)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
    }

    private func modeDescription(_ mode: ThemeManager.ThemeMode) -> String {
        switch mode {
        case .light: return "Açık yüzeyler ve yüksek görünürlük"
        case .dark: return "Göz yormayan koyu görünüm"
        case .system: return "Cihaz ayarını otomatik takip eder"
        }
    }

    private var themeLabel: String {
        DL.currentLang == "EN" ? "Theme" : "Tema"
    }

    private func legalDocumentSheet(_ document: LegalDocument) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text(document.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(ds.text1)

                Text(document.summary)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ds.text2)

                VStack(alignment: .leading, spacing: 12) {
                    legalParagraph("ArveyGo, filo operasyonlarının güvenli ve izlenebilir biçimde yürütülmesi için konum, telemetri ve kullanıcı ayarlarını işler.")
                    legalParagraph("Kullanıcı hesaplarının güvenliği, yetkisiz paylaşımın önlenmesi ve veri bütünlüğünün korunması kurum sorumluluklarıyla birlikte değerlendirilir.")
                    legalParagraph("Daha kapsamlı hukuk metni web sürümü ve kurumsal sözleşmeler içinde yayımlanır; mobil uygulama tarafında bu özet, kullanım farkındalığı sağlamak için sunulur.")
                }
            }
            .padding(20)
        }
        .background(ds.pageBg.ignoresSafeArea())
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Kapat") { activeDocument = nil }
                    .foregroundStyle(AppTheme.indigo)
            }
        }
    }

    private func legalParagraph(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(ds.text2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(ds.divider, lineWidth: 1)
            )
    }
}

#Preview {
    NavigationStack {
        SettingsView(showSideMenu: .constant(false))
    }
}
