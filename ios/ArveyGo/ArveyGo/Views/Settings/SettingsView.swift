import SwiftUI

struct SettingsView: View {
    enum LegalDocument: String, Identifiable {
        case terms
        case privacy

        var id: String { rawValue }

        var title: String {
            switch self {
            case .terms: return DashboardStrings.shared.t("Kullanım Koşulları", "Terms of Use", "Términos de uso", "Conditions d'utilisation")
            case .privacy: return DashboardStrings.shared.t("Gizlilik Politikası", "Privacy Policy", "Política de privacidad", "Politique de confidentialité")
            }
        }

        var summary: String {
            switch self {
            case .terms:
                return DashboardStrings.shared.t("Platformu kullanırken hesap güvenliği, veri doğruluğu ve kullanım sınırları bu dokümanda açıklanır.", "This document explains account security, data accuracy, and usage boundaries while using the platform.", "Este documento explica la seguridad de la cuenta, la precisión de los datos y los límites de uso en la plataforma.", "Ce document explique la sécurité du compte, l'exactitude des données et les limites d'usage de la plateforme.")
            case .privacy:
                return DashboardStrings.shared.t("Konum, araç telemetrisi ve hesap verilerinin nasıl işlendiği ve korunduğu bu dokümanda yer alır.", "This document describes how location, vehicle telemetry, and account data are processed and protected.", "Este documento describe cómo se procesan y protegen los datos de ubicación, telemetría y cuenta.", "Ce document décrit comment les données de localisation, télémétrie véhicule et compte sont traitées et protégées.")
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
                    Text(DL.t("Tercihler ve uygulama ayarları", "Preferences and app settings", "Preferencias y ajustes de la app", "Préférences et réglages de l'application"))
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
                    Text(DL.t("Kontrol ve kişiselleştirme", "Control and personalization", "Control y personalización", "Contrôle et personnalisation"))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(ds.text1)
                    Text(DL.t("Dil, tema, bildirim ve uygulama tercihlerini tek bir merkezden yönet.", "Manage language, theme, notifications, and app preferences from one place.", "Gestiona idioma, tema, notificaciones y preferencias de la app desde un solo lugar.", "Gérez langue, thème, notifications et préférences de l'app depuis un seul endroit."))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(ds.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                settingsStat(title: DL.languageLabel, value: LS.currentLang)
                settingsStat(title: DL.t("Tema", "Theme", "Tema", "Thème"), value: themeManager.mode.title)
                settingsStat(title: DL.t("Sürüm", "Version", "Versión", "Version"), value: "1.0.0")
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
        settingsCard(title: DL.t("Tercihler", "Preferences", "Preferencias", "Préférences"), subtitle: DL.t("Günlük kullanım için temel ayarlar", "Core settings for daily use", "Ajustes clave para el uso diario", "Réglages essentiels au quotidien")) {
            VStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    settingsSectionHeader(icon: "globe", title: DL.languageLabel, detail: DL.t("Arayüz dilini seç", "Choose the interface language", "Elige el idioma de la interfaz", "Choisissez la langue de l'interface"))

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
                    settingsSectionHeader(icon: "circle.lefthalf.filled", title: themeLabel, detail: DL.t("Uygulamanın görünüm modunu belirle", "Choose the app appearance mode", "Elige el modo de apariencia", "Choisissez le mode d'apparence"))

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
        settingsCard(title: DL.t("Uygulama", "Application", "Aplicación", "Application"), subtitle: DL.t("Bildirim ve erişim tercihleri", "Notification and access preferences", "Preferencias de notificación y acceso", "Préférences de notification et d'accès")) {
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
        settingsCard(title: DL.appInfoTitle, subtitle: DL.t("Sürüm ve platform bilgileri", "Version and platform information", "Información de versión y plataforma", "Informations sur la version et la plateforme")) {
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
        settingsCard(title: DL.legalTitle, subtitle: DL.t("Yasal metinler ve kullanım çerçevesi", "Legal texts and usage framework", "Textos legales y marco de uso", "Textes juridiques et cadre d'utilisation")) {
            VStack(spacing: 0) {
                Button { activeDocument = .terms } label: {
                    settingsRow(icon: "doc.text.fill", tint: AppTheme.indigo, title: DL.termsOfUse, subtitle: DL.t("Hizmet kullanım koşullarını incele", "Review service usage terms", "Revisa las condiciones de uso del servicio", "Consultez les conditions d'utilisation du service"))
                }
                .buttonStyle(.plain)

                Divider().overlay(ds.divider).padding(.leading, 54)

                Button { activeDocument = .privacy } label: {
                    settingsRow(icon: "hand.raised.fill", tint: AppTheme.online, title: DL.privacyPolicy, subtitle: DL.t("Veri işleme ve gizlilik yaklaşımı", "Data processing and privacy approach", "Enfoque de privacidad y tratamiento de datos", "Approche de confidentialité et traitement des données"))
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
        case .light: return DL.t("Açık yüzeyler ve yüksek görünürlük", "Bright surfaces and high visibility", "Superficies claras y alta visibilidad", "Surfaces claires et haute visibilité")
        case .dark: return DL.t("Göz yormayan koyu görünüm", "Dark appearance that reduces eye strain", "Apariencia oscura que reduce la fatiga visual", "Mode sombre qui réduit la fatigue visuelle")
        case .system: return DL.t("Cihaz ayarını otomatik takip eder", "Automatically follow the device setting", "Seguir automáticamente la configuración del dispositivo", "Suivre automatiquement le réglage de l'appareil")
        }
    }

    private var themeLabel: String {
        DL.t("Tema", "Theme", "Tema", "Thème")
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
                    legalParagraph(DL.t("ArveyGo, filo operasyonlarının güvenli ve izlenebilir biçimde yürütülmesi için konum, telemetri ve kullanıcı ayarlarını işler.", "ArveyGo processes location, telemetry, and user settings so fleet operations can run securely and traceably.", "ArveyGo procesa ubicación, telemetría y ajustes de usuario para que las operaciones de flota sean seguras y trazables.", "ArveyGo traite la localisation, la télémétrie et les réglages utilisateur afin que les opérations de flotte soient sûres et traçables."))
                    legalParagraph(DL.t("Kullanıcı hesaplarının güvenliği, yetkisiz paylaşımın önlenmesi ve veri bütünlüğünün korunması kurum sorumluluklarıyla birlikte değerlendirilir.", "User account security, prevention of unauthorized sharing, and protection of data integrity are handled alongside organizational responsibilities.", "La seguridad de las cuentas, la prevención del uso no autorizado y la protección de la integridad de los datos se gestionan junto con las responsabilidades de la organización.", "La sécurité des comptes, la prévention du partage non autorisé et la protection de l'intégrité des données sont gérées avec les responsabilités de l'organisation."))
                    legalParagraph(DL.t("Daha kapsamlı hukuk metni web sürümü ve kurumsal sözleşmeler içinde yayımlanır; mobil uygulama tarafında bu özet, kullanım farkındalığı sağlamak için sunulur.", "More comprehensive legal text is published in the web version and corporate agreements; this mobile summary is provided for awareness.", "El texto legal completo se publica en la versión web y en los acuerdos corporativos; este resumen móvil se ofrece como referencia.", "Un texte juridique plus complet est publié dans la version web et les accords d'entreprise ; ce résumé mobile est fourni à titre informatif."))
                }
            }
            .padding(20)
        }
        .background(ds.pageBg.ignoresSafeArea())
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(DL.t("Kapat", "Close", "Cerrar", "Fermer")) { activeDocument = nil }
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
