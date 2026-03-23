import Foundation

// MARK: - User Model
struct AppUser: Codable, Identifiable {
    let id: String
    var name: String
    var email: String
    var avatar: String
    var role: String
    var roleKey: String
    var companyId: Int

    static let dummy = AppUser(
        id: "1",
        name: "Admin",
        email: "admin@admin.com",
        avatar: "A",
        role: "Süper Yönetici",
        roleKey: "super_admin",
        companyId: 1
    )
}

// MARK: - Vehicle Model
struct Vehicle: Identifiable, Hashable {
    let id: String
    let plate: String
    let model: String
    let status: VehicleStatus
    let kontakOn: Bool
    let totalKm: Int
    let todayKm: Int
    let driver: String
    let city: String
    let lat: Double
    let lng: Double

    var formattedTotalKm: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        return formatter.string(from: NSNumber(value: totalKm)) ?? "\(totalKm)"
    }

    var formattedTodayKm: String {
        return "\(todayKm) km"
    }
}

enum VehicleStatus: String, CaseIterable {
    case online = "online"
    case offline = "offline"
    case idle = "idle"

    var color: SwiftUI.Color {
        switch self {
        case .online: return AppTheme.online
        case .offline: return AppTheme.offline
        case .idle: return AppTheme.idle
        }
    }

    var label: String {
        switch self {
        case .online: return "Aktif"
        case .offline: return "Çevrimdışı"
        case .idle: return "Rölanti"
        }
    }

    var icon: String {
        switch self {
        case .online: return "checkmark.circle.fill"
        case .offline: return "xmark.circle.fill"
        case .idle: return "pause.circle.fill"
        }
    }
}

// MARK: - Driver Score
struct DriverScore: Identifiable {
    let id: String
    let name: String
    let plate: String
    let score: Int
    let totalKm: Int
    let color: SwiftUI.Color

    var scoreColor: SwiftUI.Color {
        if score >= 85 { return AppTheme.online }
        if score >= 70 { return AppTheme.idle }
        return AppTheme.offline
    }
}

// MARK: - Alert Item
struct FleetAlert: Identifiable {
    let id: String
    let title: String
    let description: String
    let time: String
    let severity: AlertSeverity
}

enum AlertSeverity: String {
    case red, amber, blue, green

    var color: SwiftUI.Color {
        switch self {
        case .red: return .red
        case .amber: return .orange
        case .blue: return .blue
        case .green: return .green
        }
    }
}

// MARK: - Dashboard Metric
struct DashboardMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let icon: String
    let iconBg: SwiftUI.Color
    let iconColor: SwiftUI.Color
    let change: String
    let changeType: ChangeType
}

enum ChangeType {
    case up, down, flat

    var color: SwiftUI.Color {
        switch self {
        case .up: return AppTheme.online
        case .down: return AppTheme.offline
        case .flat: return AppTheme.textFaint
        }
    }

    var icon: String {
        switch self {
        case .up: return "chevron.up"
        case .down: return "chevron.down"
        case .flat: return "minus"
        }
    }
}

import SwiftUI
