import Foundation
import SwiftUI

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
struct Vehicle: Identifiable, Equatable {
    // Custom Equatable (telemetry/beacons/sensors are [String:Any] and not Equatable)
    static func == (lhs: Vehicle, rhs: Vehicle) -> Bool {
        lhs.id == rhs.id && lhs.ts == rhs.ts && lhs.lat == rhs.lat && lhs.lng == rhs.lng &&
        lhs.speed == rhs.speed && lhs.ignition == rhs.ignition && lhs.isOnline == rhs.isOnline &&
        lhs.plate == rhs.plate && lhs.livenessStatus == rhs.livenessStatus && lhs.connectedNow == rhs.connectedNow
    }
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

    // Vehicle category: "car", "motorcycle", "truck", etc.
    var vehicleCategory: String = "car"

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
    var deviceBattery: Double? = nil
    var odometer: Double = 0
    var speedLimit: Int = 0
    var temperatureC: Double? = nil
    var humidityPct: Double? = nil
    var driverId: String? = nil
    var driverName: String = ""
    var alarmCode: String? = nil
    var deviceTime: String? = nil
    var ts: Int = 0
    var deviceId: Int = 0
    var assignmentId: Int? = nil
    var pdop: Double? = nil
    var satellites: Int? = nil
    var gsmSignal: Int? = nil
    var altitude: Double? = nil
    var lastPacketAt: String? = nil
    var lastPacketTs: Int = 0
    var reportIntervalSec: Int? = nil
    var sleepIntervalSec: Int? = nil
    var offlineAfterSec: Int? = nil
    var secondsSinceLastPacket: Int? = nil
    var livenessStatus: String = ""
    var connectedNow: Bool = false
    var telemetry: [String: Any]? = nil
    var beacons: [[String: Any]]? = nil
    var beaconCount: Int = 0
    var sensors: [[String: Any]]? = nil
    var sensorCount: Int = 0

    // Ignition timestamps (from WebSocket)
    var firstIgnitionOnAtToday: String? = nil
    var lastIgnitionOnAt: String? = nil
    var lastIgnitionOffAt: String? = nil
    // API-enriched fields (from /api/mobile/vehicles/{id})
    var groupName: String = ""
    var vehicleBrand: String = ""
    var vehicleModel: String = ""
    var address: String = ""
    var dailyKm: Double = 0
    var fuelType: String = ""
    var dailyFuelLiters: Double = 0
    var dailyFuelPer100km: Double = 0
    var fuelPer100km: Double = 0

    var isMotorcycle: Bool { vehicleCategory == "motorcycle" }
    var hasValidCoordinates: Bool {
        lat.isFinite && lng.isFinite &&
        (-90.0...90.0).contains(lat) &&
        (-180.0...180.0).contains(lng) &&
        !(lat == 0 && lng == 0)
    }

    var mapIcon: String {
        switch vehicleCategory {
        case "motorcycle": return "motorcycle.fill"
        default: return "car.fill"
        }
    }

    var formattedTotalKm: String {
        // Odometer metre cinsinden gelebilir, km'ye çevir (noktadan sonrası metre olduğu için sadece km kısmı)
        let kmValue = totalKm > 10000 ? totalKm / 1000 : totalKm
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: kmValue)) ?? "\(kmValue)"
    }

    var formattedTodayKm: String {
        let kmVal = dailyKm > 0 ? dailyKm : Double(todayKm)
        if kmVal <= 0 { return "0 km" }
        if kmVal < 1 {
            return String(format: "%.0f m", kmVal * 1000)
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.maximumFractionDigits = 1
        return (formatter.string(from: NSNumber(value: kmVal)) ?? "\(Int(kmVal))") + " km"
    }

    var formattedSpeed: String {
        return "\(Int(speed)) km/h"
    }

    /// Estimated daily fuel consumption in liters: dailyKm * fuelPer100km / 100
    var estimatedDailyFuelLiters: Double {
        let rate = dailyFuelPer100km > 0 ? dailyFuelPer100km : fuelPer100km
        guard rate > 0, dailyKm > 0 else { return 0 }
        return dailyKm * rate / 100.0
    }

    /// Estimated daily fuel cost in TL
    var estimatedDailyFuelCostTL: Double {
        let liters = estimatedDailyFuelLiters
        guard liters > 0 else { return 0 }
        let pricePerLiter: Double
        let ft = fuelType.lowercased()
        if ft.contains("dizel") || ft.contains("diesel") {
            pricePerLiter = 42.75
        } else if ft.contains("benzin") || ft.contains("gasoline") {
            pricePerLiter = 44.49
        } else if ft.contains("lpg") {
            pricePerLiter = 17.54
        } else {
            pricePerLiter = 42.75 // default Dizel
        }
        return liters * pricePerLiter
    }

    var formattedDailyFuelCost: String {
        let cost = estimatedDailyFuelCostTL
        guard cost > 0 else { return "—" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.maximumFractionDigits = 0
        return "\u{20BA}" + (formatter.string(from: NSNumber(value: cost)) ?? "\(Int(cost))")
    }

    var formattedDailyFuelLiters: String {
        let liters = estimatedDailyFuelLiters
        guard liters > 0 else { return "—" }
        return String(format: "%.1f L", liters)
    }

    var kontakLabel: String {
        ignition ? "Kontak Açık" : "Kontak Kapalı"
    }

    func parseTimestamp(_ raw: String?) -> Date? {
        guard let raw = raw, !raw.isEmpty else { return nil }
        let cleaned = raw.replacingOccurrences(of: "\\.\\d+", with: "", options: .regularExpression)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: cleaned) {
            return date
        }

        let formatter1b = ISO8601DateFormatter()
        formatter1b.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date1b = formatter1b.date(from: raw) {
            return date1b
        }

        let formatter2 = DateFormatter()
        formatter2.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter2.timeZone = TimeZone(abbreviation: "UTC")
        return formatter2.date(from: cleaned)
    }

    func formatTimestamp(_ raw: String?, alwaysShowDate: Bool = false) -> String {
        guard let raw = raw, !raw.isEmpty else { return "—" }
        guard let date = parseTimestamp(raw) else { return raw }

        let outFormatter = DateFormatter()
        outFormatter.timeZone = TimeZone(identifier: "Europe/Istanbul")
        outFormatter.locale = Locale(identifier: "tr_TR")

        if alwaysShowDate {
            outFormatter.dateFormat = "dd.MM.yyyy HH:mm"
            return outFormatter.string(from: date)
        }

        if Calendar.current.isDateInToday(date) {
            outFormatter.dateFormat = "HH:mm"
        } else if Calendar.current.isDateInYesterday(date) {
            outFormatter.dateFormat = "'Dün' HH:mm"
        } else {
            outFormatter.dateFormat = "dd.MM HH:mm"
        }

        return outFormatter.string(from: date)
    }

    var formattedFirstIgnitionToday: String { formatTimestamp(firstIgnitionOnAtToday) }
    var formattedLastIgnitionOn: String { formatTimestamp(lastIgnitionOnAt) }
    var formattedLastIgnitionOff: String { formatTimestamp(lastIgnitionOffAt) }
    var formattedLastPacketAt: String { formatTimestamp(lastPacketAt) }
    var formattedFirstIgnitionTodayFull: String { formatTimestamp(firstIgnitionOnAtToday, alwaysShowDate: true) }
    var formattedLastIgnitionOnFull: String { formatTimestamp(lastIgnitionOnAt, alwaysShowDate: true) }
    var formattedLastIgnitionOffFull: String { formatTimestamp(lastIgnitionOffAt, alwaysShowDate: true) }
    var formattedLastPacketAtFull: String { formatTimestamp(lastPacketAt, alwaysShowDate: true) }

    /// Liveness status display label
    var livenessLabel: String {
        switch livenessStatus {
        case "connected": return "Bağlı"
        case "reporting": return "Raporluyor"
        case "sleeping": return "Uyku"
        case "late": return "Gecikmeli"
        case "offline": return "Çevrimdışı"
        default: return isOnline ? "Çevrimiçi" : "Çevrimdışı"
        }
    }

    var formattedDeviceTime: String {
        guard let raw = deviceTime, !raw.isEmpty else { return "—" }
        // Strip fractional seconds that can cause parse failure (e.g. .456+03:00)
        let cleaned = raw.replacingOccurrences(
            of: "\\.\\d+",
            with: "",
            options: .regularExpression
        )
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: cleaned) {
            let outFormatter = DateFormatter()
            outFormatter.dateFormat = "dd.MM.yyyy HH:mm"
            outFormatter.timeZone = TimeZone(identifier: "Europe/Istanbul")
            outFormatter.locale = Locale(identifier: "tr_TR")
            return outFormatter.string(from: date)
        }
        // Also try the original raw value (may have fractional seconds support on some OS)
        let formatter1b = ISO8601DateFormatter()
        formatter1b.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date1b = formatter1b.date(from: raw) {
            let outFormatter = DateFormatter()
            outFormatter.dateFormat = "dd.MM.yyyy HH:mm"
            outFormatter.timeZone = TimeZone(identifier: "Europe/Istanbul")
            outFormatter.locale = Locale(identifier: "tr_TR")
            return outFormatter.string(from: date1b)
        }
        // Fallback: try without timezone
        let formatter2 = DateFormatter()
        formatter2.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter2.timeZone = TimeZone(abbreviation: "UTC")
        if let date2 = formatter2.date(from: cleaned) {
            let outFormatter = DateFormatter()
            outFormatter.dateFormat = "dd.MM.yyyy HH:mm"
            outFormatter.timeZone = TimeZone(identifier: "Europe/Istanbul")
            outFormatter.locale = Locale(identifier: "tr_TR")
            return outFormatter.string(from: date2)
        }
        return raw
    }

    /// Create a Vehicle from a WebSocket JSON payload
    static func fromWSPayload(_ json: [String: Any]) -> Vehicle? {
        guard let imei = json["imei"] as? String, !imei.isEmpty else { return nil }

        let plate = (json["plate"] as? String) ?? ""
        let name = (json["name"] as? String) ?? ""
        let vehicleCategory = (json["vehicle_category"] as? String) ?? "car"
        let lat: Double = {
            let parsed: Double
            if let double = json["lat"] as? Double {
                parsed = double
            } else if let int = json["lat"] as? Int {
                parsed = Double(int)
            } else if let string = json["lat"] as? String, let double = Double(string) {
                parsed = double
            } else {
                parsed = 0
            }
            return parsed.isFinite && (-90.0...90.0).contains(parsed) ? parsed : 0
        }()
        let lon: Double = {
            let parsed: Double
            if let double = json["lon"] as? Double {
                parsed = double
            } else if let int = json["lon"] as? Int {
                parsed = Double(int)
            } else if let string = json["lon"] as? String, let double = Double(string) {
                parsed = double
            } else {
                parsed = 0
            }
            return parsed.isFinite && (-180.0...180.0).contains(parsed) ? parsed : 0
        }()
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
        let dailyKmVal = (json["dailyKm"] as? Double) ?? (json["daily_km"] as? Double) ?? ((json["dailyKm"] as? Int).map { Double($0) } ?? ((json["daily_km"] as? Int).map { Double($0) } ?? 0))
        let todayKmVal = (json["todayKm"] as? Double) ?? (json["today_km"] as? Double) ?? ((json["todayKm"] as? Int).map { Double($0) } ?? ((json["today_km"] as? Int).map { Double($0) } ?? 0))
        let fuelPer100kmVal = (json["fuelPer100km"] as? Double) ?? (json["fuel_per_100km"] as? Double) ?? 0
        let fuelTypeVal = (json["fuelType"] as? String) ?? (json["fuel_type"] as? String) ?? ""
        let speedLimit = (json["speed_limit"] as? Int) ?? 0
        let companyId = (json["company_id"] as? Int) ?? 0
        // driver_id: null olabilir (kart çıkarılınca), NSNull kontrolü yap
        let driverId: String? = {
            guard let raw = json["driver_id"] else { return nil }
            if raw is NSNull { return nil }
            if let s = raw as? String, !s.isEmpty, s != "null" { return s }
            return nil
        }()
        let alarmCode: String? = {
            guard let raw = json["alarm_code"] else { return nil }
            if raw is NSNull { return nil }
            if let s = raw as? String, !s.isEmpty, s != "null" { return s }
            return nil
        }()
        let deviceTime = json["device_time"] as? String
        let ts = (json["ts"] as? Int) ?? 0
        let deviceIdValue = (json["id"] as? Int) ?? (json["deviceId"] as? Int) ?? 0
        let assignmentId = json["assignment_id"] as? Int
        // Nullable string helper
        func nullableString(_ key: String) -> String? {
            guard let raw = json[key] else { return nil }
            if raw is NSNull { return nil }
            if let s = raw as? String, !s.isEmpty, s != "null" { return s }
            return nil
        }
        let firstIgnitionOnAtToday = nullableString("first_ignition_on_at_today")
        let lastIgnitionOnAt = nullableString("last_ignition_on_at")
        let lastIgnitionOffAt = nullableString("last_ignition_off_at")
        let lastPacketAt = nullableString("last_packet_at")
        let lastPacketTs = (json["last_packet_ts"] as? Int) ?? 0
        let batteryVoltage = (json["battery_voltage"] as? Double)
            ?? (json["battery"] as? Double)
            ?? (json["battery_voltage"] as? NSNumber)?.doubleValue
            ?? (json["battery"] as? NSNumber)?.doubleValue
        let externalVoltage = (json["external_voltage"] as? Double)
            ?? (json["externalVoltage"] as? Double)
            ?? (json["external_voltage"] as? NSNumber)?.doubleValue
            ?? (json["externalVoltage"] as? NSNumber)?.doubleValue
        // deviceBattery (battery_level_pct = percentage): check top-level, then camelCase, then inside telemetry
        let telObj = json["telemetry"] as? [String: Any]
        let deviceBattery: Double? = {
            if let v = json["battery_level_pct"] as? Double { return v }
            if let v = (json["battery_level_pct"] as? NSNumber)?.doubleValue { return v }
            if let v = json["deviceBatteryLevelPct"] as? Double { return v }
            if let v = (json["deviceBatteryLevelPct"] as? NSNumber)?.doubleValue { return v }
            if let v = json["device_battery"] as? Double { return v }
            if let v = json["deviceBattery"] as? Double { return v }
            if let v = (json["device_battery"] as? NSNumber)?.doubleValue { return v }
            if let v = (json["deviceBattery"] as? NSNumber)?.doubleValue { return v }
            if let tel = telObj, let v = tel["battery_level_pct"] as? Double { return v }
            if let tel = telObj, let v = (tel["battery_level_pct"] as? NSNumber)?.doubleValue { return v }
            return nil
        }()

        // Temperature: check top-level first (backend sends snake_case: temperature_c)
        var temperatureC: Double? = nil
        for key in ["temperature_c", "temperatureC", "tempCurrent"] {
            if let t = json[key] {
                temperatureC = (t as? Double) ?? (t as? NSNumber)?.doubleValue
                if temperatureC != nil { break }
            }
        }
        var humidityPct: Double? = nil
        for key in ["humidity_pct", "humidityPct"] {
            if let h = json[key] {
                humidityPct = (h as? Double) ?? (h as? NSNumber)?.doubleValue
                if humidityPct != nil { break }
            }
        }

        // If not at top level, look inside sensors array (backend sends sensor data here)
        if temperatureC == nil, let sensors = json["sensors"] as? [[String: Any]] {
            for sensor in sensors {
                for key in ["temperature_c", "temperatureC"] {
                    if let t = sensor[key] {
                        if let tv = (t as? Double) ?? (t as? NSNumber)?.doubleValue {
                            temperatureC = tv
                            if humidityPct == nil {
                                for hKey in ["humidity_pct", "humidityPct"] {
                                    if let h = sensor[hKey] {
                                        humidityPct = (h as? Double) ?? (h as? NSNumber)?.doubleValue
                                        if humidityPct != nil { break }
                                    }
                                }
                            }
                            break
                        }
                    }
                }
                if temperatureC != nil { break }
            }
        }

        print("🌡️ TEMP PARSE [\(plate)]: temperatureC=\(String(describing: temperatureC)), humidityPct=\(String(describing: humidityPct))")

        // New fields
        let pdop = (json["pdop"] as? Double) ?? (json["pdop"] as? NSNumber)?.doubleValue
        let satellites = json["satellites"] as? Int
        let gsmSignal = json["gsm_signal"] as? Int
        let altitude = (json["altitude"] as? Double) ?? (json["altitude"] as? NSNumber)?.doubleValue
        let reportIntervalSec = json["report_interval_sec"] as? Int
        let sleepIntervalSec = json["sleep_interval_sec"] as? Int
        let offlineAfterSec = json["offline_after_sec"] as? Int
        let secondsSinceLastPacket = json["seconds_since_last_packet"] as? Int
        let livenessStatus = (json["liveness_status"] as? String) ?? ""
        let connectedNow = (json["connected_now"] as? Bool) ?? false
        let telemetry = json["telemetry"] as? [String: Any]
        let beacons = json["beacons"] as? [[String: Any]]
        let beaconCount = (json["beacon_count"] as? Int) ?? 0
        let sensorsArr = json["sensors"] as? [[String: Any]]
        let sensorCount = (json["sensor_count"] as? Int) ?? 0

        // Status derivation — 4 states: Kontak Açık, Kontak Kapalı, Bilgi Yok, Cihaz Uykuda
        let status: VehicleStatus
        let effectiveOfflineAfterSec = offlineAfterSec ?? 3600
        if !isOnline && secondsSinceLastPacket != nil && secondsSinceLastPacket! > effectiveOfflineAfterSec { status = .noData }
        else if !isOnline { status = .ignitionOff }
        else if ignition { status = .ignitionOn }
        else { status = .ignitionOff }

        let effectiveDailyKm = dailyKmVal > 0 ? dailyKmVal : todayKmVal

        return Vehicle(
            id: imei,
            plate: plate,
            model: name,
            status: status,
            kontakOn: ignition,
            totalKm: Int(odometer),
            todayKm: Int(effectiveDailyKm),
            driver: driverId ?? "",
            city: "",
            lat: lat,
            lng: lon,
            vehicleCategory: vehicleCategory,
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
            deviceBattery: deviceBattery,
            odometer: odometer,
            speedLimit: speedLimit,
            temperatureC: temperatureC,
            humidityPct: humidityPct,
            driverId: driverId,
            alarmCode: alarmCode,
            deviceTime: deviceTime,
            ts: ts,
            deviceId: deviceIdValue,
            assignmentId: assignmentId,
            pdop: pdop,
            satellites: satellites,
            gsmSignal: gsmSignal,
            altitude: altitude,
            lastPacketAt: lastPacketAt,
            lastPacketTs: lastPacketTs,
            reportIntervalSec: reportIntervalSec,
            sleepIntervalSec: sleepIntervalSec,
            offlineAfterSec: offlineAfterSec,
            secondsSinceLastPacket: secondsSinceLastPacket,
            livenessStatus: livenessStatus,
            connectedNow: connectedNow,
            telemetry: telemetry,
            beacons: beacons,
            beaconCount: beaconCount,
            sensors: sensorsArr,
            sensorCount: sensorCount,
            firstIgnitionOnAtToday: firstIgnitionOnAtToday,
            lastIgnitionOnAt: lastIgnitionOnAt,
            lastIgnitionOffAt: lastIgnitionOffAt,
            dailyKm: effectiveDailyKm,
            fuelType: fuelTypeVal,
            dailyFuelPer100km: fuelPer100kmVal,
            fuelPer100km: fuelPer100kmVal
        )
    }

    /// Merge fields from another Vehicle (update patch) into this one.
    /// null alanları gerçekten null olarak işle, eski değeri koruma.
    mutating func mergeUpdate(from patch: Vehicle) {
        if !patch.plate.isEmpty { plate = patch.plate }
        if !patch.model.isEmpty { model = patch.model }
        if patch.vehicleCategory != "car" { vehicleCategory = patch.vehicleCategory }
        if patch.hasValidCoordinates { lat = patch.lat; lng = patch.lng }
        speed = patch.speed
        direction = patch.direction
        ignition = patch.ignition
        isOnline = patch.isOnline
        kontakOn = patch.ignition
        status = patch.status
        if patch.odometer > 0 { odometer = patch.odometer; totalKm = Int(patch.odometer) }
        if patch.todayKm > 0 { todayKm = patch.todayKm }
        // null alanları gerçekten null olarak işle
        deviceTime = patch.deviceTime
        if patch.ts > 0 { ts = patch.ts }
        fix = patch.fix
        hdop = patch.hdop
        input1 = patch.input1
        input2 = patch.input2
        output = patch.output
        // Sensör/batarya verileri her pakette gelmeyebilir, nil ise eski değeri koru
        if let v = patch.batteryVoltage { batteryVoltage = v }
        if let v = patch.externalVoltage { externalVoltage = v }
        if let v = patch.deviceBattery { deviceBattery = v }
        if let v = patch.temperatureC { temperatureC = v }
        if let v = patch.humidityPct { humidityPct = v }
        // driver_id null olabilir (kart çıkarılınca), eski değeri tutma
        driverId = patch.driverId
        if patch.driverId == nil { driverName = "" } else if !patch.driverName.isEmpty { driverName = patch.driverName }
        alarmCode = patch.alarmCode
        if let v = patch.firstIgnitionOnAtToday { firstIgnitionOnAtToday = v }
        if let v = patch.lastIgnitionOnAt { lastIgnitionOnAt = v }
        if let v = patch.lastIgnitionOffAt { lastIgnitionOffAt = v }
        if patch.deviceId > 0 { deviceId = patch.deviceId }
        if let ai = patch.assignmentId { assignmentId = ai }
        if let v = patch.pdop { pdop = v }
        if let v = patch.satellites { satellites = v }
        if let v = patch.gsmSignal { gsmSignal = v }
        if let v = patch.altitude { altitude = v }
        if let lpa = patch.lastPacketAt { lastPacketAt = lpa }
        if patch.lastPacketTs > 0 { lastPacketTs = patch.lastPacketTs }
        if let ri = patch.reportIntervalSec { reportIntervalSec = ri }
        if let si = patch.sleepIntervalSec { sleepIntervalSec = si }
        if let oa = patch.offlineAfterSec { offlineAfterSec = oa }
        secondsSinceLastPacket = patch.secondsSinceLastPacket
        if !patch.livenessStatus.isEmpty { livenessStatus = patch.livenessStatus }
        connectedNow = patch.connectedNow
        if let t = patch.telemetry { telemetry = t }
        if let b = patch.beacons { beacons = b }
        if patch.beaconCount > 0 { beaconCount = patch.beaconCount }
        if let s = patch.sensors { sensors = s }
        if patch.sensorCount > 0 { sensorCount = patch.sensorCount }
        // Preserve API-enriched fields (WS doesn't provide these)
        if !patch.groupName.isEmpty { groupName = patch.groupName }
        if !patch.vehicleBrand.isEmpty { vehicleBrand = patch.vehicleBrand }
        if !patch.vehicleModel.isEmpty { vehicleModel = patch.vehicleModel }
        if !patch.address.isEmpty { address = patch.address }
        if patch.dailyKm > 0 { dailyKm = patch.dailyKm }
        if !patch.fuelType.isEmpty { fuelType = patch.fuelType }
        if patch.dailyFuelLiters > 0 { dailyFuelLiters = patch.dailyFuelLiters }
        if patch.dailyFuelPer100km > 0 { dailyFuelPer100km = patch.dailyFuelPer100km }
        if patch.fuelPer100km > 0 { fuelPer100km = patch.fuelPer100km }
    }
}

enum VehicleStatus: String, CaseIterable {
    case ignitionOn = "ignition_on"
    case ignitionOff = "ignition_off"
    case noData = "no_data"
    case sleeping = "sleeping"

    var color: SwiftUI.Color {
        switch self {
        case .ignitionOn: return AppTheme.online
        case .ignitionOff: return AppTheme.offline
        case .noData: return Color(red: 148/255, green: 163/255, blue: 184/255)
        case .sleeping: return AppTheme.idle
        }
    }

    var label: String {
        switch self {
        case .ignitionOn: return DashboardStrings.shared.t("Kontak Açık", "Ignition On", "Encendido", "Contact mis")
        case .ignitionOff: return DashboardStrings.shared.t("Kontak Kapalı", "Ignition Off", "Apagado", "Contact coupé")
        case .noData: return DashboardStrings.shared.t("Bilgi Yok", "No Data", "Sin datos", "Aucune donnée")
        case .sleeping: return DashboardStrings.shared.t("Cihaz Uykuda", "Device Sleeping", "Dispositivo en reposo", "Appareil en veille")
        }
    }

    var icon: String {
        switch self {
        case .ignitionOn: return "checkmark.circle.fill"
        case .ignitionOff: return "xmark.circle.fill"
        case .noData: return "questionmark.circle.fill"
        case .sleeping: return "moon.fill"
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

// MARK: - Alarm Event
struct AlarmEvent: Identifiable, Hashable {
    let id: String
    let imei: String
    let plate: String
    let vehicleName: String
    let type: String
    let code: String
    let description: String
    let lat: Double
    let lng: Double
    let speed: Int
    let createdAt: String
    let isActive: Bool

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: AlarmEvent, rhs: AlarmEvent) -> Bool { lhs.id == rhs.id }

    var alarmKey: String { "\(code) \(type) \(description)" }

    var statusLabel: String { isActive ? "Aktif" : "Kapandı" }
    var statusColor: Color { isActive ? .green : .gray }

    var severity: AlertSeverity {
        let key = normalizedKey
        if key.contains("overspeed") || key.contains("hız") || key.contains("sos") || key.contains("power") {
            return .red
        }
        if key.contains("ignition_on") || key.contains("kontak aç") {
            return .green
        }
        if key.contains("ignition_off") || key.contains("kontak kapa") {
            return .amber
        }
        if key.contains("brake") || key.contains("fren") || key.contains("disconnect") || key.contains("idle") || key.contains("movement") || key.contains("hareket") {
            return .amber
        }
        if key.contains("geofence") || key.contains("gf_") {
            return .green
        }
        return .blue
    }

    var icon: String {
        let key = normalizedKey
        if key.contains("overspeed") || key.contains("hız") { return "gauge.with.dots.needle.33percent" }
        if key.contains("ignition_on") || key.contains("kontak aç") { return "power.circle.fill" }
        if key.contains("ignition_off") || key.contains("kontak kapa") { return "power.circle" }
        if key.contains("brake") || key.contains("fren") { return "exclamationmark.octagon.fill" }
        if key.contains("idle") || key.contains("rölanti") { return "clock.fill" }
        if key.contains("gf_exit") || key.contains("geofence") || key.contains("bölge") { return "mappin.and.ellipse" }
        if key.contains("disconnect") || key.contains("bağlantı") { return "antenna.radiowaves.left.and.right.slash" }
        if key.contains("sos") || key.contains("panik") { return "sos" }
        if key.contains("t_towing") || key.contains("çekici") || key.contains("taşıma") || key.contains("çekme") { return "car.side.rear.and.collision.and.car.side.front" }
        if key.contains("t_movement") || key.contains("hareket") { return "figure.walk.motion" }
        return "bell.fill"
    }

    var color: Color {
        switch severity {
        case .red: return .red
        case .amber: return .orange
        case .green: return .green
        case .blue: return AppTheme.indigo
        }
    }

    var typeLabel: String {
        let key = normalizedKey
        if key.contains("t_movement") || key.contains("hareket") { return "Hareket Algılandı" }
        if key.contains("t_towing") || key.contains("çekme") || key.contains("taşıma") { return "Çekme/Taşıma Alarmı" }
        if key.contains("ignition_on") || key.contains("kontak aç") { return "Kontak Açıldı" }
        if key.contains("ignition_off") || key.contains("kontak kapa") { return "Kontak Kapatıldı" }
        if key.contains("gf_exit") { return "Bölgeden Çıkış" }
        if key.contains("gf_enter") { return "Bölgeye Giriş" }
        if key.contains("overspeed") || key.contains("hız") { return "Hız Aşımı" }
        if key.contains("harsh_brake") || key.contains("fren") { return "Sert Fren" }
        if key.contains("idle") || key.contains("rölanti") { return "Rölanti" }
        if key.contains("disconnect") { return "Bağlantı Koptu" }
        if key.contains("sos") || key.contains("panik") { return "SOS / Panik" }
        if key.contains("power_cut") { return "Güç Kesildi" }
        if key.contains("low_battery") { return "Düşük Batarya" }
        if !description.isEmpty { return description }
        return type.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var dashboardTitle: String {
        let key = normalizedType
        if key == "geofence_enter" || key == "geofence_exit" || key.contains("gf_") {
            return "Geofence"
        }
        return typeLabel
    }

    var dashboardDescription: String {
        let key = normalizedType
        let vehicleLabel = !plate.isEmpty ? plate : vehicleName
        let rawDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

        switch key {
        case "geofence_enter", "gf_enter":
            return vehicleLabel.isEmpty ? "Giriş Yapıldı" : "\(vehicleLabel) • Giriş Yapıldı"
        case "geofence_exit", "gf_exit":
            return vehicleLabel.isEmpty ? "Çıkış Yapıldı" : "\(vehicleLabel) • Çıkış Yapıldı"
        default:
            if !rawDescription.isEmpty, !vehicleLabel.isEmpty, rawDescription != vehicleLabel {
                return "\(vehicleLabel) • \(rawDescription)"
            }
            if !rawDescription.isEmpty { return rawDescription }
            if !vehicleLabel.isEmpty, !code.isEmpty { return "\(vehicleLabel) — \(code)" }
            if !vehicleLabel.isEmpty { return vehicleLabel }
            return code
        }
    }

    var dashboardDisplayTime: String {
        Self.formattedDate(createdAt, format: "dd.MM.yyyy HH:mm") ?? createdAt
    }

    var formattedDate: String {
        Self.formattedDate(createdAt, format: "dd MMM HH:mm") ?? createdAt
    }

    var formattedFullDate: String {
        Self.formattedDate(createdAt, format: "dd MMMM yyyy, HH:mm") ?? createdAt
    }

    private var normalizedKey: String {
        "\(type) \(code) \(description)".lowercased()
    }

    private var normalizedType: String {
        type.lowercased()
    }

    static func from(json: [String: Any], index: Int = 0) -> AlarmEvent {
        let latVal = parseDouble(json["lat"])
        let lngVal = parseDouble(json["lng"])
        let speedVal = Int(parseDouble(json["speed"]))
        let rawIsActive = json["is_active"]
        let isActive: Bool = {
            if let bool = rawIsActive as? Bool { return bool }
            if let int = rawIsActive as? Int { return int != 0 }
            if let string = rawIsActive as? String {
                return ["1", "true", "active"].contains(string.lowercased())
            }
            return true
        }()

        return AlarmEvent(
            id: "\(json["id"] ?? "alarm_\(index)")",
            imei: json["imei"] as? String ?? "",
            plate: json["plate"] as? String ?? "",
            vehicleName: json["vehicle_name"] as? String ?? "",
            type: json["type"] as? String ?? "",
            code: json["code"] as? String ?? "",
            description: json["description"] as? String ?? "",
            lat: latVal,
            lng: lngVal,
            speed: speedVal,
            createdAt: json["created_at"] as? String ?? "",
            isActive: isActive
        )
    }

    private static func parseDouble(_ value: Any?) -> Double {
        if let double = value as? Double { return double }
        if let int = value as? Int { return Double(int) }
        if let string = value as? String, let double = Double(string) { return double }
        return 0
    }

    private static func parseCreatedAt(_ raw: String) -> Date? {
        guard !raw.isEmpty else { return nil }

        let normalizedCandidates = [
            raw,
            raw.replacingOccurrences(of: " ", with: "T"),
            raw.replacingOccurrences(of: "+03", with: "+03:00"),
            raw.replacingOccurrences(of: " ", with: "T").replacingOccurrences(of: "+03", with: "+03:00")
        ]

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]

        let isoFractionalFormatter = ISO8601DateFormatter()
        isoFractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for candidate in normalizedCandidates {
            if let date = isoFormatter.date(from: candidate) {
                return date
            }
            if let date = isoFractionalFormatter.date(from: candidate) {
                return date
            }
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/Istanbul")

        let formats = [
            "yyyy-MM-dd HH:mm:ssXXXXX",
            "yyyy-MM-dd HH:mm:ssX",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ssX",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss"
        ]

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: raw) {
                return date
            }
        }

        return nil
    }

    private static func formattedDate(_ raw: String, format: String) -> String? {
        guard let date = parseCreatedAt(raw) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.timeZone = TimeZone(identifier: "Europe/Istanbul")
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
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

// MARK: - Geofence Model
struct GeofencePoint: Codable, Hashable {
    let lat: Double
    let lng: Double
}

struct Geofence: Identifiable, Hashable {
    let id: Int
    let name: String
    let type: String          // "polygon" or "circle"
    let color: String         // hex e.g. "#3b82f6"
    let points: [GeofencePoint]
    let radius: Double?
    let centerLat: Double?
    let centerLng: Double?
    let createdAt: String?

    var swiftUIColor: Color {
        let h = color.trimmingCharacters(in: .init(charactersIn: "#"))
        let scanner = Scanner(string: h)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8)  & 0xFF) / 255
        let b = Double(rgb         & 0xFF) / 255
        return Color(red: r, green: g, blue: b)
    }

    var isCircle: Bool { type == "circle" }
}

// MARK: - Driver Model
struct Driver: Identifiable, Hashable {
    let id: String
    let driverCode: String
    let name: String
    let avatar: String
    let color: String
    let role: String
    let phone: String
    let email: String
    let license: String
    let licenseNo: String
    let employeeNo: String
    let vehicle: String
    let lastVehicle: String
    let model: String
    let city: String
    let vehicleCount: Int
    let status: String          // online / offline / idle
    let profileStatus: String   // active / inactive / no_profile
    let hasProfile: Bool
    let profileId: Int?
    let notes: String
    let hiredAt: String?
    let scoreGeneral: Int
    let scoreSpeed: Int
    let scoreBrake: Int
    let scoreFuel: Int
    let scoreSafety: Int
    let totalDistanceKm: Double
    let tripCount: Int
    let overspeedCount: Int
    let alarmCount: Int
    let hasTelemetry: Bool
    let createdAt: String?
    let vehicleStatus: String

    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 { return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased() }
        return String(name.prefix(2)).uppercased()
    }

    /// Sürücüye atanmış aracın durumuna göre renk: araç online/idle ise yeşil/sarı
    var statusColor: SwiftUI.Color {
        if !vehicleStatus.isEmpty {
            switch vehicleStatus {
            case "online": return AppTheme.online
            case "idle": return AppTheme.idle
            default: return AppTheme.offline
            }
        }
        switch status {
        case "online": return AppTheme.online
        case "idle": return AppTheme.idle
        default: return AppTheme.offline
        }
    }

    var scoreColor: SwiftUI.Color {
        if scoreGeneral >= 85 { return AppTheme.online }
        if scoreGeneral >= 70 { return AppTheme.idle }
        return AppTheme.offline
    }

    var avatarColor: SwiftUI.Color {
        let h = color.trimmingCharacters(in: .init(charactersIn: "#"))
        guard h.count == 6, let rgb = UInt64(h, radix: 16) else { return .blue }
        return SwiftUI.Color(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}

struct DriverStats {
    let total: Int
    let active: Int
    let tracked: Int
    let good: Int
    let mid: Int
    let low: Int
}

struct DriversResponse {
    let drivers: [Driver]
    let stats: DriverStats
}

struct CatalogVehicle: Identifiable, Hashable {
    let id: Int
    let imei: String
    let plate: String
    let name: String
}

// MARK: - Fleet Cost (API-backed)
struct FleetCost: Identifiable {
    let id: String
    var imei: String = ""
    var plate: String = ""
    var category: String = ""
    var amount: Double = 0
    var currency: String = "TRY"
    var costDate: String = ""
    var description: String = ""
    var referenceNo: String = ""
    var createdAt: String? = nil
    var updatedAt: String? = nil

    var formattedAmount: String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.locale = Locale(identifier: "tr_TR")
        fmt.maximumFractionDigits = 0
        let symbol = currency == "TRY" ? "₺" : currency
        return "\(symbol)\(fmt.string(from: NSNumber(value: amount)) ?? "0")"
    }

    static func formatAmount(_ value: Double, currency: String = "TRY") -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.locale = Locale(identifier: "tr_TR")
        fmt.maximumFractionDigits = 0
        let symbol = currency == "TRY" ? "₺" : currency
        return "\(symbol)\(fmt.string(from: NSNumber(value: value)) ?? "0")"
    }

    static func fromDict(_ d: [String: Any]) -> FleetCost {
        FleetCost(
            id: "\(d["id"] ?? "0")",
            imei: d["imei"] as? String ?? "",
            plate: d["plate"] as? String ?? "",
            category: d["category"] as? String ?? "",
            amount: (d["amount"] as? Double) ?? Double(d["amount"] as? Int ?? 0),
            currency: d["currency"] as? String ?? "TRY",
            costDate: d["cost_date"] as? String ?? "",
            description: d["description"] as? String ?? "",
            referenceNo: d["reference_no"] as? String ?? "",
            createdAt: d["created_at"] as? String,
            updatedAt: d["updated_at"] as? String
        )
    }
}

// MARK: - Fleet Maintenance
struct FleetMaintenance: Identifiable {
    let id: String
    var imei: String = ""
    var plate: String = ""
    var maintenanceType: String = ""
    var serviceDate: String? = nil
    var nextServiceDate: String? = nil
    var kmAtService: Int? = nil
    var nextServiceKm: Int? = nil
    var cost: Double? = nil
    var workshop: String = ""
    var description: String = ""
    var status: String = "done"
    var createdAt: String? = nil
    var updatedAt: String? = nil

    var statusLabel: String {
        switch status {
        case "done": return "Tamamlandı"
        case "scheduled": return "Planlandı"
        case "overdue": return "Gecikmiş"
        default: return status
        }
    }

    var title: String {
        switch maintenanceType {
        case "oil_change": return "Yağ Değişimi"
        case "tire_change": return "Lastik Değişimi"
        case "brake_service": return "Fren Bakımı"
        case "periodic": return "Periyodik Bakım"
        case "filter_change": return "Filtre Değişimi"
        case "battery": return "Akü Kontrolü"
        default: return maintenanceType.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    var scheduledDate: String {
        nextServiceDate ?? serviceDate ?? "—"
    }

    var currentKm: Int {
        kmAtService ?? 0
    }

    var formattedCost: String {
        guard let cost = cost, cost > 0 else { return "—" }
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.locale = Locale(identifier: "tr_TR")
        fmt.maximumFractionDigits = 0
        return "₺\(fmt.string(from: NSNumber(value: cost)) ?? "0")"
    }

    static func fromDict(_ d: [String: Any]) -> FleetMaintenance {
        FleetMaintenance(
            id: "\(d["id"] ?? "0")",
            imei: d["imei"] as? String ?? "",
            plate: d["plate"] as? String ?? "",
            maintenanceType: d["maintenance_type"] as? String ?? "",
            serviceDate: d["service_date"] as? String,
            nextServiceDate: d["next_service_date"] as? String,
            kmAtService: d["km_at_service"] as? Int,
            nextServiceKm: d["next_service_km"] as? Int,
            cost: d["cost"] as? Double,
            workshop: d["workshop"] as? String ?? "",
            description: d["description"] as? String ?? "",
            status: d["status"] as? String ?? "done",
            createdAt: d["created_at"] as? String,
            updatedAt: d["updated_at"] as? String
        )
    }
}

// MARK: - Fleet Document
struct FleetDocument: Identifiable {
    let id: String
    var imei: String = ""
    var plate: String = ""
    var docType: String = ""
    var title: String = ""
    var issueDate: String? = nil
    var expiryDate: String? = nil
    var reminderDays: Int = 30
    var filePath: String = ""
    var notes: String = ""
    var status: String = "active"
    var daysLeft: Int? = nil
    var createdAt: String? = nil
    var updatedAt: String? = nil

    var statusLabel: String {
        switch status {
        case "active": return "Aktif"
        case "expiring_soon": return "Yaklaşıyor"
        case "expired": return "Süresi Dolmuş"
        default: return status
        }
    }

    var docTypeLabel: String {
        switch docType {
        case "ruhsat": return "Ruhsat"
        case "sigorta": return "Sigorta"
        case "muayene": return "Muayene"
        case "egzoz": return "Egzoz"
        case "fenni_muayene": return "Fenni Muayene"
        case "other": return "Diğer"
        default: return docType.prefix(1).uppercased() + docType.dropFirst()
        }
    }

    var daysUntilExpiry: Int {
        if let dl = daysLeft { return dl }
        guard let expiry = expiryDate else { return 0 }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let date = fmt.date(from: expiry) else { return 0 }
        return max(0, Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0)
    }

    static func fromDict(_ d: [String: Any]) -> FleetDocument {
        FleetDocument(
            id: "\(d["id"] ?? "0")",
            imei: d["imei"] as? String ?? "",
            plate: d["plate"] as? String ?? "",
            docType: d["doc_type"] as? String ?? "",
            title: d["title"] as? String ?? "",
            issueDate: d["issue_date"] as? String,
            expiryDate: d["expiry_date"] as? String,
            reminderDays: d["reminder_days"] as? Int ?? 30,
            filePath: d["file_path"] as? String ?? "",
            notes: d["notes"] as? String ?? "",
            status: d["status"] as? String ?? "active",
            daysLeft: d["days_left"] as? Int,
            createdAt: d["created_at"] as? String,
            updatedAt: d["updated_at"] as? String
        )
    }
}

// MARK: - Fleet Catalog
struct FleetCatalog {
    var vehicles: [FleetCatalogVehicle] = []
    var costCategories: [String] = []
    var maintenanceStatuses: [String] = []
    var documentTypes: [String] = []

    static func fromDict(_ d: [String: Any]) -> FleetCatalog {
        let vehiclesArr = d["vehicles"] as? [[String: Any]] ?? []
        let vehicles = vehiclesArr.map { v in
            FleetCatalogVehicle(
                id: v["id"] as? Int ?? 0,
                imei: v["imei"] as? String ?? "",
                plate: v["plate"] as? String ?? "",
                name: v["name"] as? String ?? "",
                type: v["type"] as? String ?? ""
            )
        }
        return FleetCatalog(
            vehicles: vehicles,
            costCategories: d["cost_categories"] as? [String] ?? [],
            maintenanceStatuses: d["maintenance_statuses"] as? [String] ?? [],
            documentTypes: d["document_types"] as? [String] ?? []
        )
    }
}

struct FleetCatalogVehicle: Identifiable {
    let id: Int
    let imei: String
    let plate: String
    let name: String
    let type: String
}

// MARK: - Fleet Reminder
struct FleetReminder: Identifiable {
    let id: Int
    let imei: String
    let plate: String
    let type: String       // "document" or "maintenance"
    let label: String
    let dueDate: String?
    let daysLeft: Int
}

// MARK: - Fleet Tire
struct FleetTire: Identifiable {
    let id: String
    let imei: String
    let plate: String
    let position: String
    let brand: String
    let model: String
    let size: String
    let dotCode: String
    let installDate: String
    let kmAtInstall: Int
    let kmLimit: Int
    let status: String
    let notes: String

    var statusLabel: String {
        switch status {
        case "active": return "Aktif"
        case "worn": return "Aşınmış"
        case "replaced": return "Değiştirildi"
        case "critical": return "Kritik"
        default: return status.prefix(1).uppercased() + status.dropFirst()
        }
    }

    var statusColor: Color {
        switch status {
        case "active": return .green
        case "worn": return .orange
        case "replaced": return Color(red: 148/255, green: 163/255, blue: 184/255)
        case "critical": return .red
        default: return Color(red: 148/255, green: 163/255, blue: 184/255)
        }
    }

    var positionLabel: String {
        switch position {
        case "sol_on": return "Sol Ön"
        case "sag_on": return "Sağ Ön"
        case "sol_arka": return "Sol Arka"
        case "sag_arka": return "Sağ Arka"
        case "yedek": return "Yedek"
        default: return position
        }
    }

    static func fromDict(_ d: [String: Any]) -> FleetTire? {
        guard let id = d["id"] else { return nil }
        return FleetTire(
            id: "\(id)",
            imei: d["device_imei"] as? String ?? d["imei"] as? String ?? "",
            plate: d["plate"] as? String ?? "",
            position: d["position"] as? String ?? "",
            brand: d["brand"] as? String ?? "",
            model: d["model"] as? String ?? "",
            size: d["size"] as? String ?? "",
            dotCode: d["dot_code"] as? String ?? "",
            installDate: d["install_date"] as? String ?? "",
            kmAtInstall: d["km_at_install"] as? Int ?? 0,
            kmLimit: d["km_limit"] as? Int ?? 0,
            status: d["status"] as? String ?? "active",
            notes: d["notes"] as? String ?? ""
        )
    }
}

// MARK: - Pagination
struct PaginationMeta {
    var total: Int = 0
    var perPage: Int = 20
    var currentPage: Int = 1
    var lastPage: Int = 1

    var hasMore: Bool { currentPage < lastPage }

    static func fromDict(_ d: [String: Any]?) -> PaginationMeta {
        guard let d = d else { return PaginationMeta() }
        return PaginationMeta(
            total: d["total"] as? Int ?? 0,
            perPage: d["per_page"] as? Int ?? 20,
            currentPage: d["current_page"] as? Int ?? 1,
            lastPage: d["last_page"] as? Int ?? 1
        )
    }
}
