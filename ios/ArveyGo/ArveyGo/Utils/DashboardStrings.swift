import SwiftUI

/// Dashboard page localization strings – TR/EN
class DashboardStrings: ObservableObject {
    static let shared = DashboardStrings()

    @Published var currentLang: String = "TR"

    // Navigation
    var title: String { s("Dashboard", "Dashboard") }
    var subtitle: String { s("Araç Takip / Genel Bakış", "Vehicle Tracking / Overview") }

    // Greeting
    var goodMorning: String { s("Günaydın", "Good Morning") }
    var goodAfternoon: String { s("İyi Günler", "Good Afternoon") }
    var goodEvening: String { s("İyi Akşamlar", "Good Evening") }
    var fleetSummaryDesc: String { s("Filonuzun güncel durumu aşağıda özetlenmiştir.", "Your fleet's current status is summarized below.") }

    // Welcome Card (Android)
    func welcomeMsg(_ name: String) -> String { s("Hoş Geldiniz, \(name)", "Welcome, \(name)") }
    var welcomeSubtitle: String { s("Filonuzun son durumunu görüntüleyin", "View your fleet's latest status") }
    func kontakOnChip(_ n: Int) -> String { s("\(n) Kontak Açık", "\(n) Ignition On") }
    func kontakOffChip(_ n: Int) -> String { s("\(n) Kontak Kapalı", "\(n) Ignition Off") }
    func bilgiYokChip(_ n: Int) -> String { s("\(n) Bilgi Yok", "\(n) No Data") }

    // Period Filter
    var fleetOverview: String { s("Filo Özeti", "Fleet Overview") }
    var periodToday: String { s("Bugün", "Today") }
    var periodWeek: String { s("Hafta", "Week") }
    var periodMonth: String { s("Ay", "Month") }
    var periodQuarter: String { s("3 Ay", "Quarter") }
    var periodYear: String { s("Yıl", "Year") }

    // Cards
    var vehiclesTitle: String { s("Araçlar", "Vehicles") }
    var viewAll: String { s("Tümünü Gör", "View All") }
    var activeVehicles: String { s("Aktif Araçlar", "Active Vehicles") }
    var allLabel: String { s("Tümü", "All") }

    var driverScores: String { s("Sürücü Skorları", "Driver Scores") }
    var driverPerformance: String { s("Sürücü Performansı", "Driver Performance") }
    var detailLabel: String { s("Detay", "Detail") }
    var avgPrefix: String { s("Ort", "Avg") }

    var fleetMap: String { s("Filo Haritası", "Fleet Map") }
    var liveMapAction: String { s("Canlı Harita", "Live Map") }
    var activeLabel: String { s("Aktif", "Active") }
    var offlineLabel: String { s("Çevrimdışı", "Offline") }
    var idleLabel: String { s("Rölanti", "Idle") }

    var recentAlarms: String { s("Son Alarmlar", "Recent Alarms") }

    var aiInsights: String { s("AI Filo İçgörüleri", "AI Fleet Insights") }
    var aiAnalysis: String { s("AI Filo Analizi", "AI Fleet Analysis") }

    // AI insights
    func aiSummary(online: Int, km: String) -> String {
        s("Filonuzda **\(online)** araç aktif durumda. Günlük toplam **\(km) km** yol katedildi.",
          "**\(online)** vehicles active in your fleet. Total **\(km) km** covered today.")
    }
    var highPriority: String { s("Yüksek", "High") }
    var lowPriority: String { s("Düşük", "Low") }

    // ---------- Helper ----------
    private func s(_ tr: String, _ en: String) -> String {
        currentLang == "TR" ? tr : en
    }
}
