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
    var plate: String
    var model: String
    var status: VehicleStatus
    var kontakOn: Bool
    var totalKm: Int
    var todayKm: Int
    var driver: String
    var city: String
    var lat: Double
    var lng: Double

    // WebSocket / ATS fields
    var imei: String = ""
    var companyId: Int = 0
    var name: String = ""
    var speed: Double = 0
    var direction: Double = 0
    var ignition: Bool = false
    var isOnline: Bool = false
    var fix: Bool = false
    var hdop: Double = 0
    var input1: Bool = false
    var input2: Bool = false
    var output: Bool = false
    var batteryVoltage: Double? = nil
    var externalVoltage: Double? = nil
    var odometer: Double = 0
    var speedLimit: Int = 0
    var driverId: String? = nil
    var alarmCode: String? = nil
    var deviceTime: String? = nil
    var ts: Int = 0

    var formattedTotalKm: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        return formatter.string(from: NSNumber(value: totalKm)) ?? "\(totalKm)"
    }

    var formattedTodayKm: String {
        return "\(todayKm) km"
    }

    var formattedSpeed: String {
        return "\(Int(speed)) km/h"
    }

    /// Create a Vehicle from a WebSocket JSON payload
    static func fromWSPayload(_ json: [String: Any]) -> Vehicle? {
        guard let imei = json["imei"] as? String, !imei.isEmpty else { return nil }

        let plate = (json["plate"] as? String) ?? ""
        let name = (json["name"] as? String) ?? ""
        let lat = (json["lat"] as? Double) ?? 0
        let lon = (json["lon"] as? Double) ?? 0
        let speed = (json["speed"] as? Double) ?? ((json["speed"] as? Int).map { Double($0) } ?? 0)
        let direction = (json["direction"] as? Double) ?? ((json["direction"] as? Int).map { Double($0) } ?? 0)
        let ignition = (json["ignition"] as? Bool) ?? false
        let isOnline = (json["is_online"] as? Bool) ?? false
        let fix = (json["fix"] as? Bool) ?? false
        let hdop = (json["hdop"] as? Double) ?? 0
        let input1 = (json["input1"] as? Bool) ?? false
        let input2 = (json["input2"] as? Bool) ?? false
        let output = (json["output"] as? Bool) ?? false
        let odometer = (json["odometer"] as? Double) ?? ((json["odometer"] as? Int).map { Double($0) } ?? 0)
        let speedLimit = (json["speed_limit"] as? Int) ?? 0
        let companyId = (json["company_id"] as? Int) ?? 0
        let driverId = json["driver_id"] as? String
        let alarmCode = json["alarm_code"] as? String
        let deviceTime = json["device_time"] as? String
        let ts = (json["ts"] as? Int) ?? 0
        let batteryVoltage = json["battery_voltage"] as? Double
        let externalVoltage = json["external_voltage"] as? Double

        // Determine status
        let status: VehicleStatus
        if !isOnline {
            status = .offline
        } else if ignition && speed > 0 {
            status = .online
        } else {
            status = .idle
        }

        return Vehicle(
            id: imei,
            plate: plate,
            model: name,
            status: status,
            kontakOn: ignition,
            totalKm: Int(odometer),
            todayKm: Int(speed),
            driver: driverId ?? "",
            city: "",
            lat: lat,
            lng: lon,
            imei: imei,
            companyId: companyId,
            name: name,
            speed: speed,
            direction: direction,
            ignition: ignition,
            isOnline: isOnline,
            fix: fix,
            hdop: hdop,
            input1: input1,
            input2: input2,
            output: output,
            batteryVoltage: batteryVoltage,
            externalVoltage: externalVoltage,
            odometer: odometer,
            speedLimit: speedLimit,
            driverId: driverId,
            alarmCode: alarmCode,
            deviceTime: deviceTime,
            ts: ts
        )
    }

    /// Merge fields from another Vehicle (update patch) into this one.
    /// Preserves non-nil existing values when the patch field is default/empty.
    mutating func mergeUpdate(from patch: Vehicle) {
        if !patch.plate.isEmpty { plate = patch.plate }
        if !patch.model.isEmpty { model = patch.model }
        if patch.lat != 0 || patch.lng != 0 { lat = patch.lat; lng = patch.lng }
        speed = patch.speed
        direction = patch.direction
        ignition = patch.ignition
        isOnline = patch.isOnline
        kontakOn = patch.ignition
        status = patch.status
        if patch.odometer > 0 { odometer = patch.odometer; totalKm = Int(patch.odometer) }
        todayKm = Int(patch.speed) // used as speed display in some contexts
        if let dt = patch.deviceTime { deviceTime = dt }
        if patch.ts > 0 { ts = patch.ts }
        fix = patch.fix
        hdop = patch.hdop
        input1 = patch.input1
        input2 = patch.input2
        output = patch.output
        if let bv = patch.batteryVoltage { batteryVoltage = bv }
        if let ev = patch.externalVoltage { externalVoltage = ev }
        if let di = patch.driverId { driverId = di }
        if let ac = patch.alarmCode { alarmCode = ac }
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
