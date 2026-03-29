import SwiftUI

/// Dashboard page localization strings – TR/EN/ES/FR
class DashboardStrings: ObservableObject {
    static let shared = DashboardStrings()

    @Published var currentLang: String {
        didSet { UserDefaults.standard.set(currentLang, forKey: "arveygo_lang") }
    }

    init() {
        self.currentLang = UserDefaults.standard.string(forKey: "arveygo_lang") ?? "TR"
    }

    // Navigation
    var title: String { s("Dashboard", "Dashboard", "Panel", "Tableau de bord") }
    var subtitle: String { s("Araç Takip / Genel Bakış", "Vehicle Tracking / Overview", "Rastreo / Resumen", "Suivi / Aperçu") }

    // Greeting
    var goodMorning: String { s("Günaydın", "Good Morning", "Buenos Días", "Bonjour") }
    var goodAfternoon: String { s("İyi Günler", "Good Afternoon", "Buenas Tardes", "Bon Après-midi") }
    var goodEvening: String { s("İyi Akşamlar", "Good Evening", "Buenas Noches", "Bonsoir") }
    var fleetSummaryDesc: String { s("Filonuzun güncel durumu aşağıda özetlenmiştir.", "Your fleet's current status is summarized below.", "El estado actual de su flota se resume a continuación.", "L'état actuel de votre flotte est résumé ci-dessous.") }

    // Welcome Card (Android)
    func welcomeMsg(_ name: String) -> String { s("Hoş Geldiniz, \(name)", "Welcome, \(name)", "Bienvenido, \(name)", "Bienvenue, \(name)") }
    var welcomeSubtitle: String { s("Filonuzun son durumunu görüntüleyin", "View your fleet's latest status", "Vea el estado más reciente de su flota", "Consultez le dernier état de votre flotte") }
    func kontakOnChip(_ n: Int) -> String { s("\(n) Kontak Açık", "\(n) Ignition On", "\(n) Encendido", "\(n) Contact On") }
    func kontakOffChip(_ n: Int) -> String { s("\(n) Kontak Kapalı", "\(n) Ignition Off", "\(n) Apagado", "\(n) Contact Off") }
    func bilgiYokChip(_ n: Int) -> String { s("\(n) Bilgi Yok", "\(n) No Data", "\(n) Sin Datos", "\(n) Pas de Données") }

    // Period Filter
    var fleetOverview: String { s("Filo Özeti", "Fleet Overview", "Resumen de Flota", "Aperçu de la Flotte") }
    var periodToday: String { s("Bugün", "Today", "Hoy", "Aujourd'hui") }
    var periodWeek: String { s("Hafta", "Week", "Semana", "Semaine") }
    var periodMonth: String { s("Ay", "Month", "Mes", "Mois") }
    var periodQuarter: String { s("3 Ay", "Quarter", "Trimestre", "Trimestre") }
    var periodYear: String { s("Yıl", "Year", "Año", "Année") }

    // Cards
    var vehiclesTitle: String { s("Araçlar", "Vehicles", "Vehículos", "Véhicules") }
    var viewAll: String { s("Tümünü Gör", "View All", "Ver Todo", "Voir Tout") }
    var activeVehicles: String { s("Aktif Araçlar", "Active Vehicles", "Vehículos Activos", "Véhicules Actifs") }
    var allLabel: String { s("Tümü", "All", "Todos", "Tous") }

    var driverScores: String { s("Sürücü Skorları", "Driver Scores", "Puntuaciones", "Scores Conducteurs") }
    var driverPerformance: String { s("Sürücü Performansı", "Driver Performance", "Rendimiento del Conductor", "Performance Conducteur") }
    var detailLabel: String { s("Detay", "Detail", "Detalle", "Détail") }
    var avgPrefix: String { s("Ort", "Avg", "Prom", "Moy") }

    var fleetMap: String { s("Filo Haritası", "Fleet Map", "Mapa de Flota", "Carte de Flotte") }
    var liveMapAction: String { s("Canlı Harita", "Live Map", "Mapa en Vivo", "Carte en Direct") }
    var activeLabel: String { s("Aktif", "Active", "Activo", "Actif") }
    var offlineLabel: String { s("Çevrimdışı", "Offline", "Fuera de línea", "Hors ligne") }
    var idleLabel: String { s("Rölanti", "Idle", "Ralentí", "Au Ralenti") }

    var recentAlarms: String { s("Son Alarmlar", "Recent Alarms", "Alarmas Recientes", "Alarmes Récentes") }

    var aiInsights: String { s("AI Filo İçgörüleri", "AI Fleet Insights", "Insights AI de Flota", "Insights IA de Flotte") }
    var aiAnalysis: String { s("AI Filo Analizi", "AI Fleet Analysis", "Análisis AI de Flota", "Analyse IA de Flotte") }

    // AI insights
    func aiSummary(online: Int, km: String) -> String {
        s("Filonuzda **\(online)** araç aktif durumda. Günlük toplam **\(km) km** yol katedildi.",
          "**\(online)** vehicles active in your fleet. Total **\(km) km** covered today.",
          "**\(online)** vehículos activos en su flota. Total **\(km) km** recorridos hoy.",
          "**\(online)** véhicules actifs dans votre flotte. Total de **\(km) km** parcourus aujourd'hui.")
    }
    var highPriority: String { s("Yüksek", "High", "Alta", "Haute") }
    var lowPriority: String { s("Düşük", "Low", "Baja", "Basse") }

    // Settings page
    var settingsTitle: String { s("Ayarlar", "Settings", "Configuración", "Paramètres") }
    var languageLabel: String { s("Dil", "Language", "Idioma", "Langue") }
    var appInfoTitle: String { s("Uygulama Bilgisi", "App Info", "Info de la App", "Info de l'App") }

    // ---------- Helper ----------
    private func s(_ tr: String, _ en: String, _ es: String, _ fr: String) -> String {
        switch currentLang {
        case "EN": return en
        case "ES": return es
        case "FR": return fr
        default: return tr
        }
    }
}
