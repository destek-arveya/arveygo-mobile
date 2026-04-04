import SwiftUI
import MapKit

private let mobilePrivateIgnitionAlarmPrefix = "__mobile_private_ign__"

// MARK: - Alarms ViewModel
@MainActor
class AlarmsViewModel: ObservableObject {
    @Published var alarms: [AlarmEvent] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentPage = 1
    @Published var lastPage = 1
    @Published var totalCount = 0

    // Filtreler
    @Published var selectedImei: String? = nil
    @Published var selectedType: String? = nil
    @Published var dateFrom: Date? = nil
    @Published var dateTo: Date? = nil

    private let api = APIService.shared

    func fetchAlarms(page: Int = 1, append: Bool = false) async {
        if isLoading { return }
        isLoading = true
        errorMessage = nil

        var path = "/api/mobile/alarms?page=\(page)&per_page=20"
        if let imei = selectedImei, !imei.isEmpty { path += "&imei=\(imei)" }
        if let type = selectedType, !type.isEmpty { path += "&type=\(type)" }
        if let from = dateFrom {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            path += "&date_from=\(f.string(from: from))"
        }
        if let to = dateTo {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            path += "&date_to=\(f.string(from: to))"
        }

        do {
            let json = try await api.get(path)
            let dataArr = json["data"] as? [[String: Any]] ?? []
            let pagination = json["pagination"] as? [String: Any] ?? [:]

            let newAlarms = dataArr.enumerated().map { (i, item) in AlarmEvent.from(json: item, index: i) }

            if append {
                alarms.append(contentsOf: newAlarms)
            } else {
                alarms = newAlarms
            }

            currentPage = pagination["current_page"] as? Int ?? page
            lastPage = pagination["last_page"] as? Int ?? 1
            totalCount = pagination["total"] as? Int ?? alarms.count
        } catch {
            if !append {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    func loadMore() async {
        guard currentPage < lastPage else { return }
        await fetchAlarms(page: currentPage + 1, append: true)
    }

    func refresh() async {
        currentPage = 1
        await fetchAlarms(page: 1)
    }

    func applyFilters() async {
        currentPage = 1
        await fetchAlarms(page: 1)
    }

    func clearFilters() async {
        selectedImei = nil
        selectedType = nil
        dateFrom = nil
        dateTo = nil
        await refresh()
    }

}

// MARK: - Alarm Set Model (API: /api/mobile/alarm-sets/)
struct AlarmSet: Identifiable, Hashable {
    let id: Int
    let name: String
    let description: String?
    let alarmType: String
    let status: String
    let evaluationMode: String
    let sourceMode: String
    let cooldownSec: Int
    let isActive: Bool
    let conditionSummary: String
    let channelCodes: String
    let targetCount: Int
    let channelCount: Int
    let recipientCount: Int
    let createdAt: String
    let updatedAt: String

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: AlarmSet, rhs: AlarmSet) -> Bool { lhs.id == rhs.id }

    var icon: String {
        switch alarmType {
        case "speed_violation": return "gauge.with.dots.needle.33percent"
        case "geofence_alarm": return "mappin.and.ellipse"
        case "idle_alarm": return "clock.fill"
        case "movement_detection": return "figure.walk.motion"
        case "off_hours_usage": return "clock.badge.exclamationmark"
        case "ignition_on": return "power.circle.fill"
        case "ignition_off": return "power.circle"
        default: return "bell.badge.fill"
        }
    }

    var color: Color {
        switch alarmType {
        case "speed_violation": return .red
        case "geofence_alarm": return .green
        case "idle_alarm": return Color(red: 245/255, green: 158/255, blue: 11/255)
        case "movement_detection": return .orange
        case "off_hours_usage": return AppTheme.indigo
        case "ignition_on": return .green
        case "ignition_off": return .red
        default: return AppTheme.indigo
        }
    }

    var typeLabel: String {
        switch alarmType {
        case "speed_violation": return "Hız İhlali"
        case "idle_alarm": return "Rölanti"
        case "movement_detection": return "Hareket Algılama"
        case "off_hours_usage": return "Mesai Dışı Kullanım"
        case "geofence_alarm": return "Bölge Alarmı"
        case "ignition_on": return "Kontak Açılma"
        case "ignition_off": return "Kontak Kapanma"
        default: return alarmType.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    var statusLabel: String {
        switch status {
        case "active": return "Aktif"
        case "paused": return "Duraklatıldı"
        case "draft": return "Taslak"
        case "archived": return "Arşiv"
        default: return status.capitalized
        }
    }

    var statusColor: Color {
        switch status {
        case "active": return .green
        case "paused": return Color(red: 245/255, green: 158/255, blue: 11/255)
        case "draft": return .gray
        case "archived": return Color(red: 107/255, green: 114/255, blue: 128/255)
        default: return .gray
        }
    }

    var channelList: [String] {
        channelCodes.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    var formattedDate: String {
        guard createdAt.count >= 10 else { return createdAt }
        let dateParts = createdAt.prefix(10).split(separator: "-")
        guard dateParts.count == 3 else { return createdAt }
        let months = ["", "Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"]
        let month = Int(dateParts[1]) ?? 0
        let day = dateParts[2]
        return "\(day) \(months[min(month, 12)])"
    }

    static func from(json: [String: Any]) -> AlarmSet {
        let desc = json["description"] as? String
        return AlarmSet(
            id: json["id"] as? Int ?? 0,
            name: json["name"] as? String ?? "",
            description: (desc == nil || desc == "null" || desc?.isEmpty == true) ? nil : desc,
            alarmType: json["alarm_type"] as? String ?? "",
            status: json["status"] as? String ?? "draft",
            evaluationMode: json["evaluation_mode"] as? String ?? "live",
            sourceMode: json["source_mode"] as? String ?? "derived",
            cooldownSec: json["cooldown_sec"] as? Int ?? 300,
            isActive: json["is_active"] as? Bool ?? false,
            conditionSummary: json["condition_summary"] as? String ?? "",
            channelCodes: json["channel_codes"] as? String ?? "",
            targetCount: json["target_count"] as? Int ?? 0,
            channelCount: json["channel_count"] as? Int ?? 0,
            recipientCount: json["recipient_count"] as? Int ?? 0,
            createdAt: json["created_at"] as? String ?? "",
            updatedAt: json["updated_at"] as? String ?? ""
        )
    }

    var isHiddenMobileIgnitionRule: Bool {
        name.hasPrefix(mobilePrivateIgnitionAlarmPrefix)
    }
}

// MARK: - Catalog models
struct AlarmCatalogVehicle: Identifiable {
    let id: Int
    let assignmentId: Int
    let label: String
    let plate: String
}

struct AlarmCatalogRecipient: Identifiable {
    let id: Int
    let name: String
    let email: String
}

struct AlarmCatalogGeofence: Identifiable {
    let id: Int
    let name: String
}

struct AlarmTypeOption: Identifiable {
    var id: String { value }
    let value: String
    let label: String
    let description: String
}

struct AlarmCatalog {
    let vehicles: [AlarmCatalogVehicle]
    let recipients: [AlarmCatalogRecipient]
    let geofences: [AlarmCatalogGeofence]
    let types: [AlarmTypeOption]

    static func from(json: [String: Any]) -> AlarmCatalog {
        let catalog = json["catalog"] as? [String: Any] ?? json
        var vehicles: [AlarmCatalogVehicle] = []
        if let assignments = catalog["assignments"] as? [[String: Any]] {
            vehicles = assignments.map { v in
                AlarmCatalogVehicle(
                    id: v["device_id"] as? Int ?? v["id"] as? Int ?? 0,
                    assignmentId: v["id"] as? Int ?? 0,
                    label: v["label"] as? String ?? "",
                    plate: v["plate"] as? String ?? ""
                )
            }
        }
        var recipients: [AlarmCatalogRecipient] = []
        if let recipArr = catalog["recipients"] as? [[String: Any]] {
            recipients = recipArr.map { r in
                AlarmCatalogRecipient(id: r["id"] as? Int ?? 0, name: r["name"] as? String ?? "", email: r["email"] as? String ?? "")
            }
        }
        var geofences: [AlarmCatalogGeofence] = []
        if let geoArr = catalog["geofences"] as? [[String: Any]] {
            geofences = geoArr.map { g in
                AlarmCatalogGeofence(id: g["id"] as? Int ?? 0, name: g["name"] as? String ?? "")
            }
        }
        var types: [AlarmTypeOption] = []
        if let typeArr = catalog["types"] as? [[String: Any]] {
            types = typeArr.map { t in
                AlarmTypeOption(value: t["value"] as? String ?? "", label: t["label"] as? String ?? "", description: t["description"] as? String ?? "")
            }
        }
        return AlarmCatalog(vehicles: vehicles, recipients: recipients, geofences: geofences, types: types)
    }
}

struct AlarmDuplicateMatch: Equatable, Sendable {
    let id: Int
    let name: String
    let status: String

    var statusLabel: String {
        switch status {
        case "active": return "aktif"
        case "paused": return "duraklatilmis"
        case "draft": return "taslak"
        case "archived": return "arsiv"
        default: return status
        }
    }
}

private enum AlarmDuplicateGuardError: Error {
    case timeout
}

private struct AlarmRuleSignature: Hashable, Sendable {
    let description: String?
    let alarmType: String
    let evaluationMode: String
    let sourceMode: String
    let cooldownSec: Int
    let startsAt: String?
    let endsAt: String?
    let conditionsJSON: String
    let targetsJSON: String
    let channelsJSON: String
    let recipientsJSON: String

    var cacheKey: String {
        [
            description ?? "",
            alarmType,
            evaluationMode,
            sourceMode,
            String(cooldownSec),
            startsAt ?? "",
            endsAt ?? "",
            conditionsJSON,
            targetsJSON,
            channelsJSON,
            recipientsJSON,
        ].joined(separator: "|")
    }
}

private struct AlarmRuleSnapshot: Sendable {
    let id: Int
    let name: String
    let status: String
    let updatedAt: String
    let signature: AlarmRuleSignature

    static func fromBody(_ body: [String: Any], nameOverride: String? = nil) -> AlarmRuleSnapshot {
        let alarmType = stringValue(body["alarm_type"])
        return AlarmRuleSnapshot(
            id: intValue(body["id"]),
            name: nameOverride ?? stringValue(body["name"]),
            status: stringValue(body["status"], default: "active"),
            updatedAt: stringValue(body["updated_at"]),
            signature: AlarmRuleSignature(
                description: normalizedOptionalString(body["description"]),
                alarmType: alarmType,
                evaluationMode: stringValue(body["evaluation_mode"], default: "live"),
                sourceMode: stringValue(body["source_mode"], default: "derived"),
                cooldownSec: intValue(body["cooldown_sec"], default: 300),
                startsAt: normalizedOptionalString(body["starts_at"]),
                endsAt: normalizedOptionalString(body["ends_at"]),
                conditionsJSON: canonicalJSONString(normalizedRequestConditions(body, alarmType: alarmType)),
                targetsJSON: canonicalJSONString(normalizedTargets(body["targets"] as? [[String: Any]] ?? [])),
                channelsJSON: canonicalJSONString(normalizedChannels(body["channels"])),
                recipientsJSON: canonicalJSONString(normalizedRecipients(body["recipient_ids"]))
            )
        )
    }

    static func fromDetail(_ json: [String: Any]) -> AlarmRuleSnapshot {
        let alarmType = stringValue(json["alarm_type"])
        return AlarmRuleSnapshot(
            id: intValue(json["id"]),
            name: stringValue(json["name"]),
            status: stringValue(json["status"], default: "draft"),
            updatedAt: stringValue(json["updated_at"]),
            signature: AlarmRuleSignature(
                description: normalizedOptionalString(json["description"]),
                alarmType: alarmType,
                evaluationMode: stringValue(json["evaluation_mode"], default: "live"),
                sourceMode: stringValue(json["source_mode"], default: "derived"),
                cooldownSec: intValue(json["cooldown_sec"], default: 300),
                startsAt: normalizedOptionalString(json["starts_at"]),
                endsAt: normalizedOptionalString(json["ends_at"]),
                conditionsJSON: canonicalJSONString(normalizedExistingConditions(json["conditions"] as? [String: Any] ?? [:], alarmType: alarmType)),
                targetsJSON: canonicalJSONString(normalizedTargets(json["targets"] as? [[String: Any]] ?? [])),
                channelsJSON: canonicalJSONString(normalizedChannels(json["channels"])),
                recipientsJSON: canonicalJSONString(normalizedExistingRecipients(json["recipients"]))
            )
        )
    }
}

@MainActor
final class AlarmDuplicateGuardStore {
    static let shared = AlarmDuplicateGuardStore()

    private struct CachedDetail {
        let updatedAt: String
        let snapshot: AlarmRuleSnapshot
    }

    private var summaries: [AlarmSet] = []
    private var detailCache: [Int: CachedDetail] = [:]
    private var lastSummaryRefreshAt: Date?
    private let summaryTTL: TimeInterval = 90

    private init() {}

    func invalidate() {
        summaries = []
        detailCache.removeAll()
        lastSummaryRefreshAt = nil
    }

    func duplicateMatch(
        for body: [String: Any],
        ignoreId: Int? = nil,
        forceRefresh: Bool = false
    ) async throws -> AlarmDuplicateMatch? {
        try await duplicateMatch(
            for: AlarmRuleSnapshot.fromBody(body),
            ignoreId: ignoreId,
            forceRefresh: forceRefresh
        )
    }

    fileprivate func duplicateMatch(
        for snapshot: AlarmRuleSnapshot,
        ignoreId: Int? = nil,
        forceRefresh: Bool = false
    ) async throws -> AlarmDuplicateMatch? {
        let signature = snapshot.signature
        let currentSummaries = try await loadSummaries(forceRefresh: forceRefresh)

        for summary in currentSummaries {
            if let ignoreId, summary.id == ignoreId {
                continue
            }

            let snapshot = try await loadSnapshot(for: summary)
            if snapshot.signature == signature {
                return AlarmDuplicateMatch(id: snapshot.id, name: snapshot.name, status: snapshot.status)
            }
        }

        return nil
    }

    private func loadSummaries(forceRefresh: Bool) async throws -> [AlarmSet] {
        if !forceRefresh,
           let lastSummaryRefreshAt,
           Date().timeIntervalSince(lastSummaryRefreshAt) < summaryTTL,
           !summaries.isEmpty {
            return summaries
        }

        var loaded: [AlarmSet] = []
        var page = 1
        var lastPage = 1

        repeat {
            let json = try await APIService.shared.get("/api/mobile/alarm-sets/?page=\(page)")
            let data = json["data"] as? [[String: Any]] ?? []
            let pagination = json["pagination"] as? [String: Any] ?? [:]
            loaded.append(contentsOf: data.map(AlarmSet.from(json:)))
            lastPage = pagination["last_page"] as? Int ?? 1
            page += 1
        } while page <= lastPage

        summaries = loaded
        lastSummaryRefreshAt = Date()
        return loaded
    }

    private func loadSnapshot(for summary: AlarmSet) async throws -> AlarmRuleSnapshot {
        if let cached = detailCache[summary.id],
           cached.updatedAt == summary.updatedAt {
            return cached.snapshot
        }

        let json = try await APIService.shared.get("/api/mobile/alarm-sets/\(summary.id)")
        let detail = json["data"] as? [String: Any] ?? [:]
        let snapshot = AlarmRuleSnapshot.fromDetail(detail)
        detailCache[summary.id] = CachedDetail(updatedAt: summary.updatedAt, snapshot: snapshot)
        return snapshot
    }
}

private func stringValue(_ value: Any?, default defaultValue: String = "") -> String {
    if let value = value as? String {
        return value
    }
    if let value = value {
        return String(describing: value)
    }
    return defaultValue
}

private func normalizedOptionalString(_ value: Any?) -> String? {
    let string = stringValue(value).trimmingCharacters(in: .whitespacesAndNewlines)
    return string.isEmpty ? nil : string
}

private func intValue(_ value: Any?, default defaultValue: Int = 0) -> Int {
    switch value {
    case let value as Int:
        return value
    case let value as Double:
        return Int(value)
    case let value as NSNumber:
        return value.intValue
    case let value as String:
        return Int(value) ?? defaultValue
    default:
        return defaultValue
    }
}

private func boolValue(_ value: Any?, default defaultValue: Bool = false) -> Bool {
    switch value {
    case let value as Bool:
        return value
    case let value as NSNumber:
        return value.boolValue
    case let value as String:
        return ["1", "true", "yes"].contains(value.lowercased())
    default:
        return defaultValue
    }
}

private func csvValues(_ value: Any?) -> [String] {
    if let values = value as? [String] {
        return values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.sorted()
    }
    if let values = value as? [Any] {
        return values.map { stringValue($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.sorted()
    }

    let raw = stringValue(value)
    if raw.isEmpty {
        return []
    }

    return raw
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .sorted()
}

private func normalizedTargets(_ targets: [[String: Any]]) -> [[String: Any]] {
    targets
        .map {
            [
                "scope": stringValue($0["scope"]),
                "id": intValue($0["id"])
            ]
        }
        .filter { !stringValue($0["scope"]).isEmpty && intValue($0["id"]) > 0 }
        .sorted {
            let leftScope = stringValue($0["scope"])
            let rightScope = stringValue($1["scope"])
            if leftScope == rightScope {
                return intValue($0["id"]) < intValue($1["id"])
            }
            return leftScope < rightScope
        }
}

private func normalizedChannels(_ channels: Any?) -> [String] {
    let values: [String]
    if let valuesArray = channels as? [String] {
        values = valuesArray
    } else if let valuesArray = channels as? [Any] {
        values = valuesArray.map { stringValue($0) }
    } else {
        values = csvValues(channels)
    }

    return Array(Set(values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })).sorted()
}

private func normalizedRecipients(_ recipients: Any?) -> [Int] {
    let values: [Int]
    if let recipientIds = recipients as? [Int] {
        values = recipientIds
    } else if let recipientIds = recipients as? [Any] {
        values = recipientIds.map { intValue($0) }
    } else {
        values = []
    }

    return Array(Set(values.filter { $0 > 0 })).sorted()
}

private func normalizedExistingRecipients(_ recipients: Any?) -> [Int] {
    guard let recipientList = recipients as? [[String: Any]] else {
        return normalizedRecipients(recipients)
    }

    return Array(
        Set(
            recipientList
                .filter { boolValue($0["is_active"], default: true) }
                .map { intValue($0["id"] ?? $0["user_id"]) }
                .filter { $0 > 0 }
        )
    ).sorted()
}

private func normalizedRequestConditions(_ validated: [String: Any], alarmType: String) -> [String: Any] {
    switch alarmType {
    case "speed_violation":
        return [
            "native_alarm_codes": csvValues(validated["condition_native_alarm_codes"]),
            "native_alarm_categories": csvValues(validated["condition_native_alarm_categories"]),
            "speed_limit_kmh": intValue(validated["condition_speed_limit_kmh"] ?? validated["condition_speed_threshold_kmh"], default: 120),
            "speed_duration_sec": intValue(validated["condition_speed_duration_sec"], default: 30)
        ]
    case "movement_detection":
        return [
            "native_alarm_codes": csvValues(validated["condition_native_alarm_codes"]),
            "native_alarm_categories": csvValues(validated["condition_native_alarm_categories"]),
            "motion_sensitivity": stringValue(validated["condition_motion_sensitivity"], default: "medium"),
            "motion_duration_sec": intValue(validated["condition_motion_duration_sec"], default: 5)
        ]
    case "idle_alarm":
        return [
            "idle_after_sec": intValue(validated["condition_idle_after_sec"], default: 300),
            "speed_threshold_kmh": intValue(validated["condition_speed_threshold_kmh"], default: 0),
            "require_ignition": boolValue(validated["condition_require_ignition"], default: true)
        ]
    case "off_hours_usage":
        let days = normalizedRecipients(validated["condition_days"])
            .filter { (1...7).contains($0) }
        return [
            "timezone": stringValue(validated["condition_timezone"], default: "Europe/Istanbul"),
            "days": Array(Set(days)).sorted(),
            "start_local": stringValue(validated["condition_start_local"], default: "08:00"),
            "end_local": stringValue(validated["condition_end_local"], default: "18:00"),
            "require_ignition": boolValue(validated["condition_require_ignition"], default: true),
            "min_speed_kmh": intValue(validated["condition_min_speed_kmh"], default: 1)
        ]
    case "geofence_alarm":
        return [
            "geofence_id": intValue(validated["condition_geofence_id"], default: 0),
            "geofence_trigger": stringValue(validated["condition_geofence_trigger"], default: "both")
        ]
    case "ignition_on", "ignition_off":
        return [:]
    default:
        return [:]
    }
}

private func normalizedExistingConditions(_ conditions: [String: Any], alarmType: String) -> [String: Any] {
    switch alarmType {
    case "speed_violation":
        return [
            "native_alarm_codes": csvValues(conditions["native_alarm_codes"]),
            "native_alarm_categories": csvValues(conditions["native_alarm_categories"]),
            "speed_limit_kmh": intValue(conditions["speed_limit_kmh"], default: 120),
            "speed_duration_sec": intValue(conditions["speed_duration_sec"], default: 30)
        ]
    case "movement_detection":
        return [
            "native_alarm_codes": csvValues(conditions["native_alarm_codes"]),
            "native_alarm_categories": csvValues(conditions["native_alarm_categories"]),
            "motion_sensitivity": stringValue(conditions["motion_sensitivity"], default: "medium"),
            "motion_duration_sec": intValue(conditions["motion_duration_sec"], default: 5)
        ]
    case "idle_alarm":
        return [
            "idle_after_sec": intValue(conditions["idle_after_sec"], default: 300),
            "speed_threshold_kmh": intValue(conditions["speed_threshold_kmh"], default: 0),
            "require_ignition": boolValue(conditions["require_ignition"], default: true)
        ]
    case "off_hours_usage":
        let days = normalizedRecipients(conditions["days"])
            .filter { (1...7).contains($0) }
        return [
            "timezone": stringValue(conditions["timezone"], default: "Europe/Istanbul"),
            "days": Array(Set(days)).sorted(),
            "start_local": stringValue(conditions["start_local"], default: "08:00"),
            "end_local": stringValue(conditions["end_local"], default: "18:00"),
            "require_ignition": boolValue(conditions["require_ignition"], default: true),
            "min_speed_kmh": intValue(conditions["min_speed_kmh"], default: 1)
        ]
    case "geofence_alarm":
        return [
            "geofence_id": intValue(conditions["geofence_id"], default: 0),
            "geofence_trigger": stringValue(conditions["geofence_trigger"], default: "both")
        ]
    case "ignition_on", "ignition_off":
        return [:]
    default:
        return conditions
    }
}

private func canonicalJSONString(_ value: Any) -> String {
    if let dictionary = value as? [String: Any] {
        let orderedKeys = dictionary.keys.sorted()
        let parts = orderedKeys.map { key in
            "\"\(key)\":\(canonicalJSONString(dictionary[key] ?? NSNull()))"
        }
        return "{\(parts.joined(separator: ","))}"
    }

    if let array = value as? [Any] {
        return "[\(array.map(canonicalJSONString).joined(separator: ","))]"
    }

    if let string = value as? String {
        let escaped = string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    if value is NSNull {
        return "null"
    }

    return String(describing: value)
}

// MARK: - Alarms View
struct AlarmsView: View {
    @Binding var showSideMenu: Bool
    var initialSearchText: String = ""
    var autoOpenCreate: Bool = false
    var preSelectedPlate: String = ""
    var initialAlarmEvent: AlarmEvent? = nil
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = AlarmsViewModel()
    @State private var showFilters = false
    @State private var selectedTab = 0 // 0: Gelen Alarmlar, 1: Alarm Kuralları
    @Environment(\.colorScheme) private var colorScheme

    private var ds: DS { DS(isDark: colorScheme == .dark) }
    private var isDark: Bool { colorScheme == .dark }
    @State private var searchText = ""
    @State private var selectedAlarm: AlarmEvent? = nil
    @State private var selectedRule: AlarmSet? = nil

    @State private var showCreateSheet = false
    @State private var alarmSets: [AlarmSet] = []
    @State private var isLoadingSets = false
    @State private var setsError: String? = nil
    @State private var catalog: AlarmCatalog? = nil
    @State private var actionLoadingId: Int? = nil

    let alarmTypes = [
        ("overspeed", "Hız Aşımı"),
        ("harsh_brake", "Sert Fren"),
        ("harsh_acceleration", "Sert Hızlanma"),
        ("idle", "Rölanti"),
        ("geofence_enter", "Bölgeye Giriş"),
        ("geofence_exit", "Bölgeden Çıkış"),
        ("disconnect", "Bağlantı Koptu"),
        ("sos", "SOS / Panik"),
        ("tow", "Çekici"),
        ("power_cut", "Güç Kesildi"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                ds.pageBg.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Tab Selector
                    tabSelector

                    if selectedTab == 0 {
                        // MARK: Gelen Alarmlar Tab
                        VStack(spacing: 0) {
                            // Search bar
                            searchBar

                            // Aktif filtre özeti
                            if hasActiveFilters {
                                activeFiltersBar
                            }

                            if vm.isLoading && vm.alarms.isEmpty {
                                AlarmEventsSkeletonView()
                            } else if let error = vm.errorMessage, vm.alarms.isEmpty {
                                errorView(error)
                            } else if vm.alarms.isEmpty {
                                emptyView
                            } else {
                                alarmList
                            }
                        }
                    } else {
                        // MARK: Alarm Kuralları Tab
                        alarmRulesTab
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {

                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("Alarmlar")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(ds.text1)
                        Text("İzleme / Alarmlar")
                            .font(.system(size: 10))
                            .foregroundColor(ds.text3)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedTab == 0 {
                        Button(action: { withAnimation { showFilters.toggle() } }) {
                            Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                .font(.system(size: 18))
                                .foregroundColor(hasActiveFilters ? AppTheme.indigo : ds.text3)
                        }
                    }
                }
            }
            .sheet(isPresented: $showFilters) {
                filterSheet
            }
            .sheet(item: $selectedAlarm) { alarm in
                alarmDetailSheet(alarm)
            }
            .sheet(item: $selectedRule) { (rule: AlarmSet) in
                ruleDetailSheet(rule)
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateAlarmSetView(catalog: catalog, preSelectedPlate: preSelectedPlate, onCreated: {
                    showCreateSheet = false
                    Task { await fetchAlarmSets() }
                })
            }
            .onChange(of: selectedTab) { _ in
                searchText = ""
            }
        }
        .task {
            if !initialSearchText.isEmpty {
                searchText = initialSearchText
            }
            await vm.fetchAlarms()
            if let initialAlarmEvent, !autoOpenCreate {
                selectedTab = 0
                openInitialAlarm(initialAlarmEvent)
            }
            if autoOpenCreate {
                selectedTab = 1
                showCreateSheet = true
            }
            await fetchAlarmSets()
            await fetchCatalog()
        }
        .onChange(of: vm.alarms) { _, alarms in
            guard let initialAlarmEvent, selectedAlarm == nil, !autoOpenCreate else { return }
            if let match = alarms.first(where: { $0.id == initialAlarmEvent.id }) {
                selectedAlarm = match
            }
        }
    }

    // MARK: - Alarm Sets API
    private func fetchAlarmSets() async {
        isLoadingSets = true
        setsError = nil
        do {
            var loadedSets: [AlarmSet] = []
            var page = 1
            var lastPage = 1

            repeat {
                let json = try await APIService.shared.get("/api/mobile/alarm-sets/?page=\(page)")
                let dataArr = json["data"] as? [[String: Any]] ?? []
                let pagination = json["pagination"] as? [String: Any] ?? [:]
                loadedSets.append(contentsOf: dataArr.map { AlarmSet.from(json: $0) })
                lastPage = pagination["last_page"] as? Int ?? 1
                page += 1
            } while page <= lastPage

            alarmSets = loadedSets
        } catch {
            setsError = "Alarm kuralları yüklenemedi"
        }
        isLoadingSets = false
    }

    private func fetchCatalog() async {
        do {
            let json = try await APIService.shared.get("/api/mobile/alarm-sets/catalog")
            catalog = AlarmCatalog.from(json: json)
        } catch { }
    }

    private func toggleAlarmSet(_ set: AlarmSet) async {
        actionLoadingId = set.id
        let action = set.status == "active" ? "pause" : "activate"
        _ = try? await APIService.shared.post("/api/mobile/alarm-sets/\(set.id)/\(action)")
        AlarmDuplicateGuardStore.shared.invalidate()
        await fetchAlarmSets()
        actionLoadingId = nil
    }

    private func archiveAlarmSet(_ set: AlarmSet) async {
        actionLoadingId = set.id
        _ = try? await APIService.shared.post("/api/mobile/alarm-sets/\(set.id)/archive")
        AlarmDuplicateGuardStore.shared.invalidate()
        await fetchAlarmSets()
        actionLoadingId = nil
    }

    private func openInitialAlarm(_ initialAlarmEvent: AlarmEvent) {
        if let match = vm.alarms.first(where: { $0.id == initialAlarmEvent.id }) {
            selectedAlarm = match
        } else {
            selectedAlarm = nil
        }
    }

    // MARK: - Tab Selector
    var tabSelector: some View {
        HStack(spacing: 0) {
            tabButton(title: "Gelen Alarmlar", icon: "bell.fill", index: 0)
            tabButton(title: "Alarm Kuralları", icon: "gearshape.fill", index: 1)
        }
        .padding(4)
        .background(ds.cardBg)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ds.divider, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    func tabButton(title: String, icon: String, index: Int) -> some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { selectedTab = index } }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(selectedTab == index ? .white : ds.text3)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(selectedTab == index ? ds.primary : Color.clear)
            .cornerRadius(10)
        }
    }

    var hasActiveFilters: Bool {
        vm.selectedImei != nil || vm.selectedType != nil || vm.dateFrom != nil || vm.dateTo != nil
    }

    // Filtered alarms based on search
    var filteredAlarms: [AlarmEvent] {
        guard !searchText.isEmpty else { return vm.alarms }
        let q = searchText.lowercased()
        return vm.alarms.filter {
            $0.typeLabel.lowercased().contains(q) ||
            $0.plate.lowercased().contains(q) ||
            $0.vehicleName.lowercased().contains(q) ||
            $0.code.lowercased().contains(q)
        }
    }

    // Filtered rules based on search
    var filteredRules: [AlarmSet] {
        let visibleRules = alarmSets.filter { !$0.isHiddenMobileIgnitionRule }
        guard !searchText.isEmpty else { return visibleRules }
        let q = searchText.lowercased()
        return visibleRules.filter {
            $0.name.lowercased().contains(q) ||
            $0.typeLabel.lowercased().contains(q) ||
            $0.conditionSummary.lowercased().contains(q)
        }
    }

    // MARK: - Search Bar
    var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(ds.text3)

            TextField(selectedTab == 0 ? "Alarm ara (plaka, tür, açıklama...)" : "Kural ara (isim, tür, araç...)", text: $searchText)
                .font(.system(size: 13))
                .foregroundColor(ds.text1)

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(ds.text3)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(ds.cardBg)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(ds.divider, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    // MARK: - Alarm Rules Tab
    var alarmRulesTab: some View {
        Group {
            if isLoadingSets && alarmSets.isEmpty {
                AlarmRulesSkeletonView()
            } else if let error = setsError, alarmSets.isEmpty {
                errorView(error)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        // Search
                        searchBar

                        // Yeni Kural Ekle butonu
                        newRuleButton

                        // Başlık
                        HStack {
                            Text("\(filteredRules.count) kural tanımlı")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(ds.text3)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)

                        if filteredRules.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "gearshape")
                                    .font(.system(size: 36))
                                    .foregroundColor(ds.text3)
                                Text("Henüz alarm kuralı yok")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(ds.text3)
                                Text("Yukarıdaki butona tıklayarak yeni kural ekleyin")
                                    .font(.system(size: 12))
                                    .foregroundColor(ds.text3)
                            }
                            .padding(.vertical, 40)
                        }

                        ForEach(filteredRules) { rule in
                            alarmSetCard(rule)
                                .onTapGesture { selectedRule = rule }
                        }
                    }
                    .padding(.bottom, 20)
                }
                .refreshable {
                    await refreshCurrentTab()
                }
            }
        }
    }

    // MARK: - New Rule Button (Kart tarzı)
    var newRuleButton: some View {
        Button(action: { showCreateSheet = true }) {
            let accentForeground = isDark ? Color.white : AppTheme.indigo
            let accentFill = isDark ? AppTheme.indigo.opacity(0.92) : AppTheme.indigo.opacity(0.04)
            let accentStroke = isDark ? Color.white.opacity(0.10) : AppTheme.indigo.opacity(0.15)
            let iconBubble = isDark ? Color.white.opacity(0.14) : AppTheme.indigo.opacity(0.12)

            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(iconBubble)
                        .frame(width: 34, height: 34)
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(accentForeground)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Yeni Alarm Kuralı Ekle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(accentForeground)
                    Text("Araçlarınız için özel alarm kuralı tanımlayın")
                        .font(.system(size: 10))
                        .foregroundColor(isDark ? Color.white.opacity(0.76) : ds.text3)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isDark ? Color.white.opacity(0.72) : AppTheme.indigo.opacity(0.5))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(accentFill)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(accentStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    // MARK: - Alarm Set Card
    func alarmSetCard(_ rule: AlarmSet) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                // İkon
                ZStack {
                    Circle()
                        .fill(rule.color.opacity(0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: rule.icon)
                        .font(.system(size: 15))
                        .foregroundColor(rule.color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(rule.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ds.text1)
                    Text(rule.typeLabel)
                        .font(.system(size: 11))
                        .foregroundColor(ds.text3)
                }

                Spacer()

                // Status badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(rule.statusColor)
                        .frame(width: 7, height: 7)
                    Text(rule.statusLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(rule.statusColor)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(rule.statusColor.opacity(0.1))
                .cornerRadius(12)
            }

            // Detaylar
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(ds.text3)
                    Text("Koşul: \(rule.conditionSummary)")
                        .font(.system(size: 11))
                        .foregroundColor(ds.text2)
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 10))
                        .foregroundColor(ds.text3)
                    Text("\(rule.targetCount) araç")
                        .font(.system(size: 11))
                        .foregroundColor(ds.text2)

                    Spacer().frame(width: 8)

                    // Channel icons
                    ForEach(rule.channelList, id: \.self) { ch in
                        Image(systemName: ch == "email" ? "envelope.fill" : ch == "sms" ? "message.fill" : "bell.fill")
                            .font(.system(size: 10))
                            .foregroundColor(ds.text3)
                    }
                }
            }
            .padding(.leading, 48)
        }
        .padding(12)
        .background(ds.cardBg)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 2, y: 1)
        .padding(.horizontal, 16)
    }

    // MARK: - Active Filters Bar
    var activeFiltersBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if let type = vm.selectedType {
                    filterChip(label: alarmTypes.first(where: { $0.0 == type })?.1 ?? type) {
                        vm.selectedType = nil
                        Task { await vm.applyFilters() }
                    }
                }
                if vm.selectedImei != nil {
                    filterChip(label: "Araç Filtreli") {
                        vm.selectedImei = nil
                        Task { await vm.applyFilters() }
                    }
                }
                if vm.dateFrom != nil || vm.dateTo != nil {
                    filterChip(label: "Tarih Filtreli") {
                        vm.dateFrom = nil
                        vm.dateTo = nil
                        Task { await vm.applyFilters() }
                    }
                }

                Button(action: { Task { await vm.clearFilters() } }) {
                    Text("Temizle")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(ds.cardBg)
    }

    func filterChip(label: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppTheme.indigo)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(ds.text3)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(AppTheme.indigo.opacity(0.08))
        .cornerRadius(12)
    }

    // MARK: - Alarm List
    var alarmList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                // Sonuç sayısı
                HStack {
                    Text("\(filteredAlarms.count) alarm")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ds.text3)
                    Spacer()
                    if vm.isLoading && searchText.isEmpty {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                ForEach(filteredAlarms) { alarm in
                    alarmCard(alarm)
                        .onTapGesture { selectedAlarm = alarm }
                        .onAppear {
                            // Son öğeye gelince daha fazla yükle — sadece arama yokken
                            if searchText.isEmpty, alarm.id == vm.alarms.last?.id {
                                Task { await vm.loadMore() }
                            }
                        }
                }

                if vm.currentPage < vm.lastPage && searchText.isEmpty {
                    HStack {
                        ProgressView()
                        Text("Yükleniyor...")
                            .font(.system(size: 12))
                            .foregroundColor(ds.text3)
                    }
                    .padding()
                }
            }
            .padding(.bottom, 20)
        }
        .refreshable {
            await refreshCurrentTab()
        }
    }

    // MARK: - Alarm Card
    func alarmCard(_ alarm: AlarmEvent) -> some View {
        HStack(spacing: 12) {
            // İkon
            ZStack {
                Circle()
                    .fill(alarm.color.opacity(isDark ? 0.2 : 0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: alarm.icon)
                    .font(.system(size: 16))
                    .foregroundColor(alarm.color)
            }

            // Bilgi
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(alarm.typeLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isDark ? Color.white.opacity(0.96) : ds.text1)
                    Spacer()
                    Text(alarm.formattedDate)
                        .font(.system(size: 10))
                        .foregroundColor(isDark ? ds.text2 : ds.text3)
                }

                HStack(spacing: 6) {
                    // Plaka
                    Text(alarm.plate.isEmpty ? alarm.vehicleName : alarm.plate)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isDark ? .white : AppTheme.indigo)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isDark ? Color.white.opacity(0.12) : AppTheme.indigo.opacity(0.08))
                        .cornerRadius(4)

                    if alarm.speed > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "speedometer")
                                .font(.system(size: 9))
                            Text("\(alarm.speed) km/s")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(isDark ? ds.text2 : ds.text3)
                    }
                }

                if !alarm.code.isEmpty || !alarm.description.isEmpty {
                    HStack(spacing: 6) {
                        // Status badge
                        Text(alarm.statusLabel)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(alarm.statusColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(alarm.statusColor.opacity(0.10))
                            .cornerRadius(4)

                        Text(alarm.description.isEmpty ? alarm.code : alarm.description)
                            .font(.system(size: 10))
                            .foregroundColor(ds.text3)
                            .lineLimit(1)
                    }
                }
            }

            // Ok
            Image(systemName: "chevron.right")
                .font(.system(size: 11))
                .foregroundColor(ds.text3)
        }
        .padding(12)
        .background(ds.cardBg)
        .cornerRadius(12)
        .shadow(color: isDark ? Color.clear : Color.black.opacity(0.03), radius: 2, y: 1)
        .padding(.horizontal, 16)
    }

    // MARK: - Filter Sheet
    var filterSheet: some View {
        NavigationStack {
            List {
                // Alarm Türü
                Section("Alarm Türü") {
                    Button(action: {
                        vm.selectedType = nil
                    }) {
                        HStack {
                            Text("Tümü")
                                .foregroundColor(ds.text1)
                            Spacer()
                            if vm.selectedType == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(AppTheme.indigo)
                            }
                        }
                    }
                    ForEach(alarmTypes, id: \.0) { (key, label) in
                        Button(action: {
                            vm.selectedType = key
                        }) {
                            HStack {
                                Text(label)
                                    .foregroundColor(ds.text1)
                                Spacer()
                                if vm.selectedType == key {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(AppTheme.indigo)
                                }
                            }
                        }
                    }
                }

                // Tarih
                Section("Tarih Aralığı") {
                    DatePicker("Başlangıç", selection: Binding(
                        get: { vm.dateFrom ?? Date() },
                        set: { vm.dateFrom = $0 }
                    ), displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "tr"))

                    DatePicker("Bitiş", selection: Binding(
                        get: { vm.dateTo ?? Date() },
                        set: { vm.dateTo = $0 }
                    ), displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "tr"))

                    if vm.dateFrom != nil || vm.dateTo != nil {
                        Button("Tarih Filtresini Kaldır", role: .destructive) {
                            vm.dateFrom = nil
                            vm.dateTo = nil
                        }
                    }
                }
            }
            .navigationTitle("Filtreler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") {
                        showFilters = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Uygula") {
                        showFilters = false
                        Task { await vm.applyFilters() }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Loading / Error / Empty
    var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Alarmlar yükleniyor...")
                .font(.system(size: 13))
                .foregroundColor(ds.text3)
            Spacer()
        }
    }

    func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            Text("Bir hata oluştu")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(ds.text1)
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(ds.text3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Tekrar Dene") {
                Task { await refreshCurrentTab() }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(AppTheme.indigo)
            .cornerRadius(8)
            Spacer()
        }
    }

    @MainActor
    private func refreshCurrentTab() async {
        if selectedTab == 0 {
            await vm.refresh()
        } else {
            await fetchAlarmSets()
            await fetchCatalog()
        }
    }

    var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bell.slash")
                .font(.system(size: 44))
                .foregroundColor(ds.text3)
            Text("Alarm Bulunamadı")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ds.text1)
            Text("Seçili filtrelere uygun alarm kaydı yok.\nFiltrelerinizi değiştirerek tekrar deneyebilirsiniz.")
                .font(.system(size: 12))
                .foregroundColor(ds.text3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            if hasActiveFilters {
                Button("Filtreleri Temizle") {
                    Task { await vm.clearFilters() }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.indigo)
            }
            Spacer()
        }
    }

    // MARK: - Alarm Detail Sheet
    func alarmDetailSheet(_ alarm: AlarmEvent) -> some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(alarm.color.opacity(isDark ? 0.2 : 0.12))
                                .frame(width: 60, height: 60)
                            Image(systemName: alarm.icon)
                                .font(.system(size: 26))
                                .foregroundColor(alarm.color)
                        }

                        Text(alarm.typeLabel)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(ds.text1)

                        Text(alarm.formattedFullDate)
                            .font(.system(size: 12))
                            .foregroundColor(ds.text3)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(alarm.color.opacity(isDark ? 0.08 : 0.04))

                    // Details
                    VStack(spacing: 0) {
                        detailRow(icon: "car.fill", title: "Araç", value: alarm.plate.isEmpty ? alarm.vehicleName : "\(alarm.plate) — \(alarm.vehicleName)")
                        Divider().padding(.leading, 44)
                        detailRow(icon: "number", title: "IMEI", value: alarm.imei)
                        Divider().padding(.leading, 44)
                        detailRow(icon: "speedometer", title: "Hız", value: alarm.speed > 0 ? "\(alarm.speed) km/s" : "—")
                        Divider().padding(.leading, 44)
                        detailRow(icon: "doc.text.fill", title: "Açıklama", value: { let t = alarm.description.isEmpty ? alarm.code : alarm.description; return t.isEmpty ? "—" : t }())
                        Divider().padding(.leading, 52)
                        detailRow(icon: "circle.fill", title: "Durum", value: alarm.statusLabel)
                        Divider().padding(.leading, 44)
                        detailRow(icon: "mappin.circle.fill", title: "Konum", value: String(format: "%.4f, %.4f", alarm.lat, alarm.lng))
                        Divider().padding(.leading, 44)
                        detailRow(icon: "calendar", title: "Tarih", value: alarm.formattedFullDate)
                    }
                    .padding(.top, 8)

                    // Harita - Alarm konumu
                    if alarm.lat != 0 && alarm.lng != 0 {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "map.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.indigo)
                                Text("Alarm Konumu")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(ds.text1)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)

                            Map(initialPosition: .camera(MapCamera(
                                centerCoordinate: CLLocationCoordinate2D(latitude: alarm.lat, longitude: alarm.lng),
                                distance: 2000,
                                heading: 0,
                                pitch: 0
                            ))) {
                                Annotation(alarm.typeLabel, coordinate: CLLocationCoordinate2D(latitude: alarm.lat, longitude: alarm.lng)) {
                                    ZStack {
                                        Circle()
                                            .fill(alarm.color)
                                            .frame(width: 36, height: 36)
                                        Circle()
                                            .stroke(Color.white, lineWidth: 2.5)
                                            .frame(width: 36, height: 36)
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .mapStyle(.standard(elevation: .flat))
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 16)

                            // Konuma Git button
                            Button(action: {
                                openMapsDirectionsAlarm(lat: alarm.lat, lng: alarm.lng, label: alarm.plate.isEmpty ? alarm.vehicleName : alarm.plate)
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Konuma Git")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(AppTheme.indigo)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                        }
                        .padding(.bottom, 8)
                    }
                }
            }
            .background(ds.pageBg)
            .navigationTitle("Alarm Detayı")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { selectedAlarm = nil }
                        .fontWeight(.medium)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Rule Detail Sheet
    func ruleDetailSheet(_ rule: AlarmSet) -> some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(rule.color.opacity(isDark ? 0.2 : 0.12))
                                .frame(width: 60, height: 60)
                            Image(systemName: rule.icon)
                                .font(.system(size: 26))
                                .foregroundColor(rule.color)
                        }

                        Text(rule.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(ds.text1)

                        if let desc = rule.description {
                            Text(desc)
                                .font(.system(size: 12))
                                .foregroundColor(ds.text3)
                        }

                        // Status badge
                        HStack(spacing: 5) {
                            Circle()
                                .fill(rule.statusColor)
                                .frame(width: 8, height: 8)
                            Text(rule.statusLabel)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(rule.statusColor)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(rule.statusColor.opacity(0.1))
                        .cornerRadius(16)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(rule.color.opacity(0.04))

                    // Details
                    VStack(spacing: 0) {
                        detailRow(icon: "tag.fill", title: "Alarm Türü", value: rule.typeLabel)
                        Divider().padding(.leading, 44)
                        detailRow(icon: "exclamationmark.triangle.fill", title: "Koşul", value: rule.conditionSummary.isEmpty ? "—" : rule.conditionSummary)
                        Divider().padding(.leading, 44)
                        detailRow(icon: "car.fill", title: "Hedef Araçlar", value: "\(rule.targetCount) araç")
                        Divider().padding(.leading, 44)
                        detailRow(icon: "bell.fill", title: "Bildirim Kanalları", value: rule.channelList.map { ch in
                            switch ch { case "email": return "E-posta"; case "sms": return "SMS"; case "push": return "Mobil Bildirim"; default: return ch }
                        }.joined(separator: ", "))
                        Divider().padding(.leading, 44)
                        detailRow(icon: "person.2.fill", title: "Alıcılar", value: "\(rule.recipientCount) kişi")
                        Divider().padding(.leading, 44)
                        detailRow(icon: "timer", title: "Bekleme Süresi", value: "\(rule.cooldownSec / 60) dk")
                        Divider().padding(.leading, 44)
                        detailRow(icon: "eye.fill", title: "Değerlendirme", value: rule.evaluationMode == "live" ? "Canlı Alarm" : "İzleme Modu")
                        Divider().padding(.leading, 44)
                        detailRow(icon: "calendar", title: "Oluşturulma", value: rule.formattedDate)
                    }
                    .padding(.top, 8)

                    // Actions
                    if rule.status != "archived" {
                        VStack(spacing: 10) {
                            // Activate/Pause toggle
                            Button(action: {
                                Task {
                                    await toggleAlarmSet(rule)
                                    selectedRule = nil
                                }
                            }) {
                                HStack {
                                    if actionLoadingId == rule.id {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .tint(.white)
                                    } else {
                                        Image(systemName: rule.status == "active" ? "pause.fill" : "play.fill")
                                        Text(rule.status == "active" ? "Duraklatır" : "Aktifleştir")
                                    }
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(rule.status == "active" ? Color(red: 245/255, green: 158/255, blue: 11/255) : .green)
                                .cornerRadius(10)
                            }
                            .disabled(actionLoadingId == rule.id)

                            // Archive
                            Button(action: {
                                Task {
                                    await archiveAlarmSet(rule)
                                    selectedRule = nil
                                }
                            }) {
                                HStack {
                                    Image(systemName: "archivebox")
                                    Text("Arşivle")
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.red.opacity(0.08))
                                .cornerRadius(10)
                            }
                            .disabled(actionLoadingId == rule.id)
                        }
                        .padding(16)
                    }
                }
            }
            .background(ds.pageBg)
            .navigationTitle("Kural Detayı")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { selectedRule = nil }
                        .fontWeight(.medium)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Open Maps Directions
    private func openMapsDirectionsAlarm(lat: Double, lng: Double, label: String) {
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = label
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    // MARK: - Detail Row Helper
    func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(ds.text3)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(ds.text3)
                Text(value)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(ds.text1)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Create Alarm Set View (Modern Step Wizard)
struct CreateAlarmSetView: View {
    let catalog: AlarmCatalog?
    var preSelectedPlate: String = ""
    let onCreated: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var ds: DS { DS(isDark: colorScheme == .dark) }
    private var isDark: Bool { colorScheme == .dark }

    // Step state (1=İsim&Tür, 2=Araçlar, 3=Koşullar, 4=Bildirim)
    @State private var currentStep = 1
    let stepLabels = ["İsim & Tür", "Araçlar", "Koşullar", "Bildirim"]

    // Form state
    @State private var name = ""
    @State private var selectedType = "speed_violation"
    @State private var selectedVehicles = Set<Int>()
    @State private var selectedChannels: Set<String> = ["push"]
    @State private var selectedRecipients = Set<Int>()
    @State private var selectedGeofence: Int? = nil
    @State private var speedLimit = "80"
    @State private var idleAfterSec = "300"
    @State private var isSaving = false
    @State private var errorMsg: String? = nil
    @State private var vehicleSearch = ""
    @State private var duplicateMatch: AlarmDuplicateMatch? = nil
    @State private var duplicateWarning: String? = nil
    @State private var isCheckingDuplicate = false

    var typeOptions: [AlarmTypeOption] {
        catalog?.types ?? [
            AlarmTypeOption(value: "speed_violation", label: "Hız İhlali", description: "Belirlenen hız limitini aşıldığında bildirim alın"),
            AlarmTypeOption(value: "idle_alarm", label: "Rölanti", description: "Araç belirli süreden fazla rölantide kaldığında uyar"),
            AlarmTypeOption(value: "movement_detection", label: "Hareket Algılama", description: "Park halindeki aracın hareket etmesinde uyar"),
            AlarmTypeOption(value: "off_hours_usage", label: "Mesai Dışı Kullanım", description: "Mesai saatleri dışında kullanımda uyar"),
            AlarmTypeOption(value: "geofence_alarm", label: "Bölge Alarmı", description: "Bölgeye giriş/çıkışta bildirim alın"),
            AlarmTypeOption(value: "ignition_on", label: "Kontak Açılma", description: "Araç kontağı açıldığında bildirim alın"),
            AlarmTypeOption(value: "ignition_off", label: "Kontak Kapanma", description: "Araç kontağı kapandığında bildirim alın")
        ]
    }

    private func iconForType(_ type: String) -> String {
        switch type {
        case "speed_violation": return "speedometer"
        case "idle_alarm": return "hourglass.bottomhalf.filled"
        case "movement_detection": return "car.fill"
        case "off_hours_usage": return "clock.fill"
        case "geofence_alarm": return "location.fill"
        case "ignition_on": return "power.circle.fill"
        case "ignition_off": return "power.circle"
        default: return "bell.fill"
        }
    }

    private func colorForType(_ type: String) -> Color {
        switch type {
        case "speed_violation": return Color(red: 0.937, green: 0.267, blue: 0.267) // EF4444
        case "idle_alarm": return Color(red: 0.961, green: 0.620, blue: 0.043) // F59E0B
        case "movement_detection": return Color(red: 0.133, green: 0.773, blue: 0.369) // 22C55E
        case "off_hours_usage": return Color(red: 0.659, green: 0.333, blue: 0.969) // A855F7
        case "geofence_alarm": return AppTheme.indigo
        case "ignition_on": return Color(red: 0.133, green: 0.773, blue: 0.369)
        case "ignition_off": return Color(red: 0.937, green: 0.267, blue: 0.267)
        default: return AppTheme.indigo
        }
    }

    private var duplicateValidationBody: [String: Any]? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !selectedVehicles.isEmpty, !selectedChannels.isEmpty, !selectedRecipients.isEmpty else {
            return nil
        }

        if selectedType == "geofence_alarm", selectedGeofence == nil {
            return nil
        }

        var body: [String: Any] = [
            "name": trimmedName,
            "alarm_type": selectedType,
            "status": "active",
            "evaluation_mode": "live",
            "source_mode": selectedType == "speed_violation" ? "existing" : "derived",
            "cooldown_sec": 300,
            "is_active": true,
            "condition_require_ignition": true,
            "targets": selectedVehicles.sorted().map { ["scope": "assignment", "id": $0] },
            "channels": Array(selectedChannels).sorted(),
            "recipient_ids": Array(selectedRecipients).sorted(),
        ]

        switch selectedType {
        case "speed_violation":
            body["condition_speed_limit_kmh"] = Int(speedLimit) ?? 80
            body["condition_speed_duration_sec"] = 5
        case "idle_alarm":
            body["condition_idle_after_sec"] = Int(idleAfterSec) ?? 300
            body["condition_speed_threshold_kmh"] = 0
        case "geofence_alarm":
            body["condition_geofence_id"] = selectedGeofence
            body["condition_geofence_trigger"] = "both"
        case "off_hours_usage":
            body["condition_start_local"] = "08:00"
            body["condition_end_local"] = "18:00"
            body["condition_timezone"] = "Europe/Istanbul"
            body["condition_min_speed_kmh"] = 1
            body["condition_days"] = [1, 2, 3, 4, 5]
        default:
            break
        }

        return body
    }

    private var duplicateCheckToken: String {
        guard currentStep == 4, let body = duplicateValidationBody else {
            return "inactive-\(currentStep)"
        }
        return AlarmRuleSnapshot.fromBody(body).signature.cacheKey
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Navy Header ──
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Yeni Alarm Oluştur")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        Text("Adım adım alarm kurun — çok kolay!")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 32, height: 32)
                            .background(.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                }

                // ── Step Indicator ──
                HStack(spacing: 4) {
                    ForEach(Array(stepLabels.enumerated()), id: \.offset) { index, label in
                        let stepNum = index + 1
                        let isActive = stepNum == currentStep
                        let isDone = stepNum < currentStep

                        Button(action: { if isDone { currentStep = stepNum } }) {
                            HStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(isDone ? Color(red: 0.133, green: 0.773, blue: 0.369) : (isActive ? .white : .white.opacity(0.2)))
                                        .frame(width: 22, height: 22)
                                    if isDone {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                    } else {
                                        Text("\(stepNum)")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(isActive ? ds.text1 : .white.opacity(0.5))
                                    }
                                }
                                Text(label)
                                    .font(.system(size: 10, weight: isActive ? .semibold : .regular))
                                    .foregroundColor(isActive || isDone ? .white : .white.opacity(0.4))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isActive ? .white.opacity(0.15) : (isDone ? .white.opacity(0.08) : .clear))
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(!isDone)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(ds.text1)

            // ── Step Content ──
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    switch currentStep {
                    case 1: stepNameAndType
                    case 2: stepVehicles
                    case 3: stepConditions
                    case 4: stepNotifications
                    default: EmptyView()
                    }
                }
                .padding(20)
            }

            // ── Error Message ──
            if let error = errorMsg {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
            }

            // ── Bottom Navigation Buttons ──
            HStack(spacing: 10) {
                if currentStep > 1 {
                    Button(action: { currentStep -= 1; errorMsg = nil }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Geri")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(ds.text1)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(ds.divider, lineWidth: 1)
                        )
                    }
                }

                Button(action: {
                    errorMsg = nil
                    switch currentStep {
                    case 1:
                        if name.trimmingCharacters(in: .whitespaces).isEmpty { errorMsg = "Alarm adı gerekli"; return }
                        currentStep = 2
                    case 2:
                        if selectedVehicles.isEmpty { errorMsg = "En az bir araç seçin"; return }
                        currentStep = 3
                    case 3:
                        if selectedType == "geofence_alarm", selectedGeofence == nil {
                            errorMsg = "Lütfen bir bölge seçin"
                            return
                        }
                        currentStep = 4
                    case 4:
                        Task { await save() }
                    default: break
                    }
                }) {
                    HStack(spacing: 6) {
                        if isSaving || (currentStep == 4 && isCheckingDuplicate) {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Text(currentStep == 4 ? "Alarm Oluştur" : "Devam Et")
                                .font(.system(size: 14, weight: .semibold))
                            Image(systemName: currentStep == 4 ? "checkmark" : "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(currentStep == 4 ? (duplicateMatch == nil ? Color(red: 0.133, green: 0.773, blue: 0.369) : Color(red: 148/255, green: 163/255, blue: 184/255)) : ds.text1)
                    )
                }
                .disabled(isSaving || (currentStep == 4 && (isCheckingDuplicate || duplicateMatch != nil)))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(ds.cardBg)
        }
        .background(ds.pageBg)
        .task(id: duplicateCheckToken) {
            guard currentStep == 4 else {
                duplicateMatch = nil
                duplicateWarning = nil
                isCheckingDuplicate = false
                return
            }
            await validateDuplicate(debounced: true, forceRefresh: false)
        }
        .onAppear {
            // Pre-select vehicle by plate
            if !preSelectedPlate.isEmpty, let vehicles = catalog?.vehicles {
                if let match = vehicles.first(where: { $0.plate.localizedCaseInsensitiveCompare(preSelectedPlate) == .orderedSame || $0.label.localizedCaseInsensitiveContains(preSelectedPlate) }) {
                    selectedVehicles.insert(match.assignmentId)
                }
            }
            // Pre-select first recipient
            if let first = catalog?.recipients.first {
                selectedRecipients.insert(first.id)
            }
        }
    }

    // MARK: - Step 1: İsim & Tür
    @ViewBuilder
    private var stepNameAndType: some View {
        Text("Alarm Adı")
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(ds.text1)

        TextField("ör. Hız İhlali Alarmı, Depo Kontrolü...", text: $name)
            .font(.system(size: 14))
            .padding(12)
            .background(ds.cardBg)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(ds.divider, lineWidth: 1))

        Text("Alarm Türü Seçin")
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(ds.text1)
            .padding(.top, 4)

        ForEach(typeOptions) { type in
            let isSelected = selectedType == type.value
            let typeColor = colorForType(type.value)

            Button(action: { selectedType = type.value }) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(typeColor.opacity(0.1))
                            .frame(width: 40, height: 40)
                        Image(systemName: iconForType(type.value))
                            .font(.system(size: 16))
                            .foregroundColor(typeColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(type.label)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(ds.text1)
                        if !type.description.isEmpty {
                            Text(type.description)
                                .font(.system(size: 11))
                                .foregroundColor(ds.text3)
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    if isSelected {
                        ZStack {
                            Circle()
                                .fill(typeColor)
                                .frame(width: 22, height: 22)
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? typeColor.opacity(0.06) : ds.cardBg)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? typeColor.opacity(0.3) : ds.divider, lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Step 2: Araçlar
    @ViewBuilder
    private var stepVehicles: some View {
        Text("Hangi araçlar için geçerli olsun?")
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(ds.text1)

        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(ds.text3)
            TextField("Plaka veya araç ara...", text: $vehicleSearch)
                .font(.system(size: 13))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(ds.cardBg)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(ds.divider, lineWidth: 1))

        HStack(spacing: 12) {
            Button(action: {
                if let vehicles = catalog?.vehicles {
                    selectedVehicles = Set(vehicles.map { $0.assignmentId })
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "checklist")
                        .font(.system(size: 12))
                    Text("Tümünü Seç")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(AppTheme.indigo)
            }
            if !selectedVehicles.isEmpty {
                Button(action: { selectedVehicles.removeAll() }) {
                    Text("Temizle (\(selectedVehicles.count))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.red)
                }
            }
            Spacer()
        }

        if let vehicles = catalog?.vehicles {
            let filtered = vehicleSearch.isEmpty ? vehicles : vehicles.filter {
                $0.plate.localizedCaseInsensitiveContains(vehicleSearch) || $0.label.localizedCaseInsensitiveContains(vehicleSearch)
            }
            LazyVStack(spacing: 8) {
                ForEach(filtered) { v in
                    let isVSel = selectedVehicles.contains(v.assignmentId)
                    Button(action: {
                        if isVSel { selectedVehicles.remove(v.assignmentId) }
                        else { selectedVehicles.insert(v.assignmentId) }
                    }) {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(isVSel ? AppTheme.indigo : .clear)
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(isVSel ? AppTheme.indigo : ds.text3, lineWidth: 1.5)
                                    )
                                if isVSel {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(v.label)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(ds.text1)
                                if !v.plate.isEmpty && v.plate != v.label {
                                    Text(v.plate)
                                        .font(.system(size: 11))
                                        .foregroundColor(ds.text3)
                                }
                            }

                            Spacer()

                            if isVSel {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(AppTheme.indigo)
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isVSel ? AppTheme.indigo.opacity(0.06) : ds.cardBg)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isVSel ? AppTheme.indigo.opacity(0.2) : ds.divider, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            HStack {
                ProgressView().scaleEffect(0.8)
                Text("Araçlar yükleniyor...")
                    .font(.system(size: 12))
                    .foregroundColor(ds.text3)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
        }
    }

    // MARK: - Step 3: Koşullar
    @ViewBuilder
    private var stepConditions: some View {
        let typeLabel = typeOptions.first(where: { $0.value == selectedType })?.label ?? selectedType
        Text("\(typeLabel) Koşulları")
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(ds.text1)

        switch selectedType {
        case "speed_violation":
            conditionSpeedView
        case "idle_alarm":
            conditionIdleView
        case "geofence_alarm":
            conditionGeofenceView
        case "movement_detection":
            conditionMovementView
        case "off_hours_usage":
            conditionOffHoursView
        case "ignition_on":
            conditionIgnitionView(
                title: "Kontak Açılma",
                icon: "power.circle.fill",
                accent: Color(red: 0.133, green: 0.773, blue: 0.369),
                description: "Araç kontağı açıldığı anda otomatik bildirim alırsınız. Bu alarm tipi için ek koşul tanımlamanıza gerek yoktur."
            )
        case "ignition_off":
            conditionIgnitionView(
                title: "Kontak Kapanma",
                icon: "power.circle",
                accent: Color(red: 0.937, green: 0.267, blue: 0.267),
                description: "Araç kontağı kapandığı anda otomatik bildirim alırsınız. Bu alarm tipi için ek koşul tanımlamanıza gerek yoktur."
            )
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var conditionSpeedView: some View {
        Text("Araçlarınızın aşmaması gereken hız limitini belirleyin.")
            .font(.system(size: 12))
            .foregroundColor(ds.text3)

        HStack(spacing: 10) {
            Image(systemName: "speedometer")
                .font(.system(size: 18))
                .foregroundColor(Color(red: 0.937, green: 0.267, blue: 0.267))
            TextField("Hız Limiti (km/s)", text: $speedLimit)
                .font(.system(size: 14))
                .keyboardType(.numberPad)
        }
        .padding(12)
        .background(ds.cardBg)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(ds.divider, lineWidth: 1))

        Text("Hızlı Seçim")
            .font(.system(size: 11))
            .foregroundColor(ds.text3)

        HStack(spacing: 8) {
            ForEach(["50", "80", "100", "120"], id: \.self) { preset in
                let isSel = speedLimit == preset
                Button(action: { speedLimit = preset }) {
                    Text("\(preset) km/s")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isSel ? .white : ds.text1)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(isSel ? AppTheme.indigo : ds.cardBg))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSel ? AppTheme.indigo : ds.divider, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var conditionIdleView: some View {
        Text("Araçlarınızın rölantide kalabileceği maksimum süreyi belirleyin.")
            .font(.system(size: 12))
            .foregroundColor(ds.text3)

        HStack(spacing: 10) {
            Image(systemName: "hourglass.bottomhalf.filled")
                .font(.system(size: 18))
                .foregroundColor(Color(red: 0.961, green: 0.620, blue: 0.043))
            TextField("Rölanti Süresi (saniye)", text: $idleAfterSec)
                .font(.system(size: 14))
                .keyboardType(.numberPad)
        }
        .padding(12)
        .background(ds.cardBg)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(ds.divider, lineWidth: 1))

        Text("Hızlı Seçim")
            .font(.system(size: 11))
            .foregroundColor(ds.text3)

        HStack(spacing: 8) {
            ForEach([("180", "3 dk"), ("300", "5 dk"), ("600", "10 dk"), ("900", "15 dk")], id: \.0) { sec, label in
                let isSel = idleAfterSec == sec
                Button(action: { idleAfterSec = sec }) {
                    Text(label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isSel ? .white : ds.text1)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(isSel ? AppTheme.indigo : ds.cardBg))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSel ? AppTheme.indigo : ds.divider, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var conditionGeofenceView: some View {
        Text("Alarm tetiklenecek bölgeyi seçin.")
            .font(.system(size: 12))
            .foregroundColor(ds.text3)

        if let geofences = catalog?.geofences {
            ForEach(geofences) { gf in
                let isSel = selectedGeofence == gf.id
                Button(action: { selectedGeofence = gf.id }) {
                    HStack(spacing: 10) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 14))
                            .foregroundColor(isSel ? AppTheme.indigo : ds.text3)
                        Text(gf.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(ds.text1)
                        Spacer()
                        if isSel {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(AppTheme.indigo)
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(isSel ? AppTheme.indigo.opacity(0.06) : ds.cardBg))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSel ? AppTheme.indigo.opacity(0.2) : ds.divider, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        } else {
            Text("Bölge bulunamadı")
                .font(.system(size: 12))
                .foregroundColor(ds.text3)
        }
    }

    @ViewBuilder
    private var conditionMovementView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "car.fill")
                .font(.system(size: 28))
                .foregroundColor(Color(red: 0.133, green: 0.773, blue: 0.369))
            Text("Hareket Algılama")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ds.text1)
            Text("Park halindeki araç sallanma, çekilme veya hareket etme durumunda otomatik uyarı alacaksınız. Ek koşul gerekmez.")
                .font(.system(size: 12))
                .foregroundColor(ds.text3)
                .lineSpacing(4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.133, green: 0.773, blue: 0.369).opacity(0.06)))
    }

    @ViewBuilder
    private var conditionOffHoursView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "clock.fill")
                .font(.system(size: 28))
                .foregroundColor(Color(red: 0.659, green: 0.333, blue: 0.969))
            Text("Mesai Dışı Kullanım")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ds.text1)
            Text("Varsayılan ayarlar: Hafta içi 08:00 - 18:00 arası mesai. Bu saat aralığı dışında araç kullanıldığında bildirim alırsınız.")
                .font(.system(size: 12))
                .foregroundColor(ds.text3)
                .lineSpacing(4)
            HStack(spacing: 6) {
                ForEach(["Pzt", "Sal", "Çar", "Per", "Cum"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(red: 0.659, green: 0.333, blue: 0.969))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color(red: 0.659, green: 0.333, blue: 0.969).opacity(0.15)))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.659, green: 0.333, blue: 0.969).opacity(0.06)))
    }

    // MARK: - Step 4: Bildirim
    @ViewBuilder
    private var stepNotifications: some View {
        Text("Bildirim Kanalları")
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(ds.text1)
        Text("Alarm tetiklendiğinde hangi kanallardan bildirim almak istiyorsunuz?")
            .font(.system(size: 12))
            .foregroundColor(ds.text3)

        channelsList
        recipientsList
        summaryCard
        duplicateStatusCard
    }

    @ViewBuilder
    private var channelsList: some View {
        let channels: [(key: String, label: String, desc: String, icon: String, color: Color)] = [
            ("push", "Mobil Bildirim", "Telefonunuza anlık bildirim", "iphone", AppTheme.indigo),
            ("email", "E-posta", "Detaylı alarm raporu e-posta ile", "envelope.fill", Color(red: 0.231, green: 0.510, blue: 0.965)),
            ("sms", "SMS", "Kısa mesaj ile uyarı", "message.fill", Color(red: 0.133, green: 0.773, blue: 0.369))
        ]

        ForEach(channels, id: \.key) { ch in
            let isSel = selectedChannels.contains(ch.key)
            Button(action: {
                if isSel { selectedChannels.remove(ch.key) }
                else { selectedChannels.insert(ch.key) }
            }) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(ch.color.opacity(0.1))
                            .frame(width: 38, height: 38)
                        Image(systemName: ch.icon)
                            .font(.system(size: 16))
                            .foregroundColor(ch.color)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(ch.label)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(ds.text1)
                        Text(ch.desc)
                            .font(.system(size: 11))
                            .foregroundColor(ds.text3)
                    }

                    Spacer()

                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isSel ? ch.color : .clear)
                            .frame(width: 22, height: 22)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(isSel ? ch.color : ds.text3, lineWidth: 1.5)
                            )
                        if isSel {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill(isSel ? ch.color.opacity(0.06) : ds.cardBg))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSel ? ch.color.opacity(0.3) : ds.divider, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func conditionIgnitionView(title: String, icon: String, accent: Color, description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(accent)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ds.text1)
            Text(description)
                .font(.system(size: 12))
                .foregroundColor(ds.text3)
                .lineSpacing(4)
        }
        .padding(16)
        .background(accent.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var recipientsList: some View {
        Text("Alıcılar")
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(ds.text1)
            .padding(.top, 8)
        Text("Alarm bildirimlerini kimler alsın?")
            .font(.system(size: 12))
            .foregroundColor(ds.text3)

        if let recipients = catalog?.recipients {
            LazyVStack(spacing: 8) {
                ForEach(recipients) { r in
                    let isSel = selectedRecipients.contains(r.id)
                    Button(action: {
                        if isSel { selectedRecipients.remove(r.id) }
                        else { selectedRecipients.insert(r.id) }
                    }) {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.indigo.opacity(0.1))
                                    .frame(width: 36, height: 36)
                                Text(String(r.name.prefix(2)).uppercased())
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(AppTheme.indigo)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(ds.text1)
                                Text(r.email)
                                    .font(.system(size: 11))
                                    .foregroundColor(ds.text3)
                            }

                            Spacer()

                            ZStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(isSel ? AppTheme.indigo : .clear)
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(isSel ? AppTheme.indigo : ds.text3, lineWidth: 1.5)
                                    )
                                if isSel {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(isSel ? AppTheme.indigo.opacity(0.06) : ds.cardBg))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSel ? AppTheme.indigo.opacity(0.2) : ds.divider, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            HStack {
                ProgressView().scaleEffect(0.8)
                Text("Alıcılar yükleniyor...")
                    .font(.system(size: 12))
                    .foregroundColor(ds.text3)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
        }
    }

    @ViewBuilder
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Özet")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(ds.text1)

            HStack(spacing: 4) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 12))
                    .foregroundColor(ds.text3)
                Text("Tür: \(typeOptions.first(where: { $0.value == selectedType })?.label ?? selectedType)")
                    .font(.system(size: 11))
                    .foregroundColor(ds.text2)
            }
            HStack(spacing: 4) {
                Image(systemName: "car.fill")
                    .font(.system(size: 12))
                    .foregroundColor(ds.text3)
                Text("\(selectedVehicles.count) araç seçildi")
                    .font(.system(size: 11))
                    .foregroundColor(ds.text2)
            }
            HStack(spacing: 4) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 12))
                    .foregroundColor(ds.text3)
                Text("\(selectedChannels.count) kanal, \(selectedRecipients.count) alıcı")
                    .font(.system(size: 11))
                    .foregroundColor(ds.text2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(ds.text1.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(ds.text1.opacity(0.1), lineWidth: 1))
        .padding(.top, 8)
    }

    @ViewBuilder
    private var duplicateStatusCard: some View {
        if let duplicateMatch {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color(red: 0.924, green: 0.592, blue: 0.074))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Aynı alarm zaten mevcut")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(ds.text1)
                    Text("'\(duplicateMatch.name)' kuralı \(duplicateMatch.statusLabel) durumda bulundu. Kaydetme kapatıldı.")
                        .font(.system(size: 11))
                        .foregroundColor(ds.text2)
                }
                Spacer()
            }
            .padding(14)
            .background(Color(red: 0.924, green: 0.592, blue: 0.074).opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(red: 0.924, green: 0.592, blue: 0.074).opacity(0.28), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else if let duplicateWarning {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 14))
                    .foregroundColor(Color(red: 0.886, green: 0.494, blue: 0.078))
                Text(duplicateWarning)
                    .font(.system(size: 11))
                    .foregroundColor(ds.text2)
                Spacer()
            }
            .padding(14)
            .background(Color(red: 0.886, green: 0.494, blue: 0.078).opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(red: 0.886, green: 0.494, blue: 0.078).opacity(0.24), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func save() async {
        guard !name.isEmpty else { errorMsg = "Kural adı gerekli"; return }
        guard !selectedVehicles.isEmpty else { errorMsg = "En az bir araç seçin"; return }
        guard !selectedChannels.isEmpty else { errorMsg = "En az bir bildirim kanalı seçin"; return }
        guard !selectedRecipients.isEmpty else { errorMsg = "En az bir alıcı seçin"; return }
        guard selectedType != "geofence_alarm" || selectedGeofence != nil else {
            errorMsg = "Lütfen bir bölge seçin"
            return
        }

        guard let body = duplicateValidationBody else {
            errorMsg = "Alarm bilgileri tamamlanamadı"
            return
        }

        isSaving = true
        errorMsg = nil

        do {
            await validateDuplicate(debounced: false, forceRefresh: true)
            if duplicateMatch != nil {
                isSaving = false
                return
            }
            _ = try await APIService.shared.post("/api/mobile/alarm-sets/", body: body)
            AlarmDuplicateGuardStore.shared.invalidate()
            onCreated()
        } catch {
            errorMsg = "Kayıt başarısız: \(error.localizedDescription)"
        }

        isSaving = false
    }

    private func validateDuplicate(debounced: Bool, forceRefresh: Bool) async {
        guard let body = duplicateValidationBody else {
            duplicateMatch = nil
            duplicateWarning = nil
            isCheckingDuplicate = false
            return
        }
        let snapshot = AlarmRuleSnapshot.fromBody(body)

        if debounced {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
        }

        isCheckingDuplicate = true
        duplicateWarning = nil

        do {
            let match = try await withThrowingTaskGroup(of: AlarmDuplicateMatch?.self) { group in
                group.addTask {
                    try await AlarmDuplicateGuardStore.shared.duplicateMatch(for: snapshot, forceRefresh: forceRefresh)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                    throw AlarmDuplicateGuardError.timeout
                }

                let result = try await group.next() ?? nil
                group.cancelAll()
                return result
            }

            duplicateMatch = match
            duplicateWarning = nil
        } catch {
            duplicateMatch = nil
            duplicateWarning = "Mevcut alarmlar zamanında doğrulanamadı. Kaydetmeye devam edebilirsiniz."
        }

        isCheckingDuplicate = false
    }
}

#Preview {
    AlarmsView(showSideMenu: .constant(false))
        .environmentObject(AuthViewModel())
}
