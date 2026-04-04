import SwiftUI

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Theme Manager — persisted theme preference
// ═══════════════════════════════════════════════════════════════════════════
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    enum ThemeMode: String, CaseIterable {
        case light  = "light"
        case dark   = "dark"
        case system = "system"

        var label: String {
            switch self {
            case .light:  return "☀️"
            case .dark:   return "🌙"
            case .system: return "📱"
            }
        }

        var title: String {
            DashboardStrings.shared.t(
                self == .light ? "Açık" : self == .dark ? "Koyu" : "Sistem",
                self == .light ? "Light" : self == .dark ? "Dark" : "System",
                self == .light ? "Claro" : self == .dark ? "Oscuro" : "Sistema",
                self == .light ? "Clair" : self == .dark ? "Sombre" : "Système"
            )
        }
    }

    @Published var mode: ThemeMode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: "arveygo_theme")
        }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: "arveygo_theme") ?? "system"
        self.mode = ThemeMode(rawValue: saved) ?? .system
    }

    var colorScheme: ColorScheme? {
        switch mode {
        case .light:  return .light
        case .dark:   return .dark
        case .system: return nil
        }
    }
}
