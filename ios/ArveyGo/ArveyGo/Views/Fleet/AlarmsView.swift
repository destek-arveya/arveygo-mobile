import SwiftUI
import MapKit

// MARK: - Alarm Model
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

    /// Combined key for matching: code + type + description
    var alarmKey: String { "\(code) \(type) \(description)" }

    var statusLabel: String { isActive ? "Aktif" : "Kapandı" }
    var statusColor: Color { isActive ? .green : .gray }

    var icon: String {
        let key = alarmKey.lowercased()
        if key.contains("overspeed") || key.contains("hız") { return "gauge.with.dots.needle.33percent" }
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
        let key = alarmKey.lowercased()
        if key.contains("overspeed") || key.contains("hız") || key.contains("sos") || key.contains("panik") { return .red }
        if key.contains("t_towing") || key.contains("çekme") || key.contains("taşıma") { return .red }
        if key.contains("brake") || key.contains("fren") || key.contains("disconnect") { return .orange }
        if key.contains("t_movement") || key.contains("hareket") { return .orange }
        if key.contains("idle") || key.contains("rölanti") { return Color(red: 245/255, green: 158/255, blue: 11/255) }
        if key.contains("geofence") || key.contains("gf_") { return .green }
        return AppTheme.indigo
    }

    var typeLabel: String {
        let key = alarmKey.lowercased()
        if key.contains("t_movement") || key.contains("hareket") { return "Hareket Algılandı" }
        if key.contains("t_towing") || key.contains("çekme") || key.contains("taşıma") { return "Çekme/Taşıma Alarmı" }
        if key.contains("gf_exit") { return "Bölgeden Çıkış" }
        if key.contains("gf_enter") { return "Bölgeye Giriş" }
        if key.contains("overspeed") || key.contains("hız") { return "Hız Aşımı" }
        if key.contains("harsh_brake") || key.contains("fren") { return "Sert Fren" }
        if key.contains("idle") || key.contains("rölanti") { return "Rölanti" }
        if key.contains("disconnect") { return "Bağlantı Koptu" }
        if key.contains("sos") || key.contains("panik") { return "SOS / Panik" }
        if key.contains("power_cut") { return "Güç Kesildi" }
        if key.contains("low_battery") { return "Düşük Batarya" }
        // Fallback: use description if available
        if !description.isEmpty { return description }
        return type.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var formattedDate: String {
        // "2026-03-26 14:30:00" → "26 Mar 14:30"
        guard createdAt.count >= 16 else { return createdAt }
        let parts = createdAt.split(separator: " ")
        guard parts.count >= 2 else { return createdAt }
        let dateParts = parts[0].split(separator: "-")
        guard dateParts.count == 3 else { return createdAt }
        let months = ["", "Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"]
        let month = Int(dateParts[1]) ?? 0
        let day = dateParts[2]
        let time = String(parts[1].prefix(5))
        return "\(day) \(months[min(month, 12)]) \(time)"
    }

    var formattedFullDate: String {
        // "2026-03-26 14:30:00" → "26 Mart 2026, 14:30"
        guard createdAt.count >= 16 else { return createdAt }
        let parts = createdAt.split(separator: " ")
        guard parts.count >= 2 else { return createdAt }
        let dateParts = parts[0].split(separator: "-")
        guard dateParts.count == 3 else { return createdAt }
        let monthsFull = ["", "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"]
        let year = dateParts[0]
        let month = Int(dateParts[1]) ?? 0
        let day = dateParts[2]
        let time = String(parts[1].prefix(5))
        return "\(day) \(monthsFull[min(month, 12)]) \(year), \(time)"
    }

    static func from(json: [String: Any], index: Int = 0) -> AlarmEvent {
        let latVal: Double
        if let d = json["lat"] as? Double { latVal = d }
        else if let s = json["lat"] as? String, let d = Double(s) { latVal = d }
        else { latVal = 0 }

        let lngVal: Double
        if let d = json["lng"] as? Double { lngVal = d }
        else if let s = json["lng"] as? String, let d = Double(s) { lngVal = d }
        else { lngVal = 0 }

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
            speed: json["speed"] as? Int ?? 0,
            createdAt: json["created_at"] as? String ?? "",
            isActive: json["is_active"] as? Bool ?? true
        )
    }
}

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

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: AlarmSet, rhs: AlarmSet) -> Bool { lhs.id == rhs.id }

    var icon: String {
        switch alarmType {
        case "speed_violation": return "gauge.with.dots.needle.33percent"
        case "geofence_alarm": return "mappin.and.ellipse"
        case "idle_alarm": return "clock.fill"
        case "movement_detection": return "figure.walk.motion"
        case "off_hours_usage": return "clock.badge.exclamationmark"
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
            createdAt: json["created_at"] as? String ?? ""
        )
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

// MARK: - Alarms View
struct AlarmsView: View {
    @Binding var showSideMenu: Bool
    var initialSearchText: String = ""
    var autoOpenCreate: Bool = false
    var preSelectedPlate: String = ""
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = AlarmsViewModel()
    @State private var showFilters = false
    @State private var selectedTab = 0 // 0: Gelen Alarmlar, 1: Alarm Kuralları
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
                AppTheme.bg.ignoresSafeArea()

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
                                loadingView
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { withAnimation(.spring(response: 0.3)) { showSideMenu.toggle() } }) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(AppTheme.navy)
                    }
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("Alarmlar")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.navy)
                        Text("İzleme / Alarmlar")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textMuted)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        if selectedTab == 0 {
                            Button(action: { withAnimation { showFilters.toggle() } }) {
                                Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                    .font(.system(size: 18))
                                    .foregroundColor(hasActiveFilters ? AppTheme.indigo : AppTheme.textMuted)
                            }
                        }
                        AvatarCircle(
                            initials: authVM.currentUser?.avatar ?? "A",
                            size: 30
                        )
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
            if autoOpenCreate {
                selectedTab = 1
                showCreateSheet = true
            }
            await vm.fetchAlarms()
            await fetchAlarmSets()
            await fetchCatalog()
        }
    }

    // MARK: - Alarm Sets API
    private func fetchAlarmSets() async {
        isLoadingSets = true
        setsError = nil
        do {
            let json = try await APIService.shared.get("/api/mobile/alarm-sets/")
            let dataArr = json["data"] as? [[String: Any]] ?? []
            alarmSets = dataArr.map { AlarmSet.from(json: $0) }
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
        await fetchAlarmSets()
        actionLoadingId = nil
    }

    private func archiveAlarmSet(_ set: AlarmSet) async {
        actionLoadingId = set.id
        _ = try? await APIService.shared.post("/api/mobile/alarm-sets/\(set.id)/archive")
        await fetchAlarmSets()
        actionLoadingId = nil
    }

    // MARK: - Tab Selector
    var tabSelector: some View {
        HStack(spacing: 0) {
            tabButton(title: "Gelen Alarmlar", icon: "bell.fill", index: 0)
            tabButton(title: "Alarm Kuralları", icon: "gearshape.fill", index: 1)
        }
        .padding(4)
        .background(AppTheme.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.borderSoft, lineWidth: 1)
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
            .foregroundColor(selectedTab == index ? .white : AppTheme.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(selectedTab == index ? AppTheme.navy : Color.clear)
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
        guard !searchText.isEmpty else { return alarmSets }
        let q = searchText.lowercased()
        return alarmSets.filter {
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
                .foregroundColor(AppTheme.textMuted)

            TextField(selectedTab == 0 ? "Alarm ara (plaka, tür, açıklama...)" : "Kural ara (isim, tür, araç...)", text: $searchText)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textPrimary)

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.textMuted)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(AppTheme.surface)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppTheme.borderSoft, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    // MARK: - Alarm Rules Tab
    var alarmRulesTab: some View {
        Group {
            if isLoadingSets && alarmSets.isEmpty {
                loadingView
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
                                .foregroundColor(AppTheme.textMuted)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)

                        if filteredRules.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "gearshape")
                                    .font(.system(size: 36))
                                    .foregroundColor(AppTheme.textFaint)
                                Text("Henüz alarm kuralı yok")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(AppTheme.textMuted)
                                Text("Yukarıdaki butona tıklayarak yeni kural ekleyin")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.textFaint)
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
            }
        }
    }

    // MARK: - New Rule Button (Kart tarzı)
    var newRuleButton: some View {
        Button(action: { showCreateSheet = true }) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(AppTheme.indigo.opacity(0.12))
                        .frame(width: 34, height: 34)
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.indigo)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Yeni Alarm Kuralı Ekle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.indigo)
                    Text("Araçlarınız için özel alarm kuralı tanımlayın")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textMuted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.indigo.opacity(0.5))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppTheme.indigo.opacity(0.04))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.indigo.opacity(0.15), lineWidth: 1)
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
                        .foregroundColor(AppTheme.textPrimary)
                    Text(rule.typeLabel)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textMuted)
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
                        .foregroundColor(AppTheme.textFaint)
                    Text("Koşul: \(rule.conditionSummary)")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textFaint)
                    Text("\(rule.targetCount) araç")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textSecondary)

                    Spacer().frame(width: 8)

                    // Channel icons
                    ForEach(rule.channelList, id: \.self) { ch in
                        Image(systemName: ch == "email" ? "envelope.fill" : ch == "sms" ? "message.fill" : "bell.fill")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textFaint)
                    }
                }
            }
            .padding(.leading, 48)
        }
        .padding(12)
        .background(AppTheme.surface)
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
        .background(AppTheme.surface)
    }

    func filterChip(label: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppTheme.indigo)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textMuted)
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
                        .foregroundColor(AppTheme.textMuted)
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
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .padding()
                }
            }
            .padding(.bottom, 20)
        }
        .refreshable {
            await vm.refresh()
        }
    }

    // MARK: - Alarm Card
    func alarmCard(_ alarm: AlarmEvent) -> some View {
        HStack(spacing: 12) {
            // İkon
            ZStack {
                Circle()
                    .fill(alarm.color.opacity(0.12))
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
                        .foregroundColor(AppTheme.textPrimary)
                    Spacer()
                    Text(alarm.formattedDate)
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textFaint)
                }

                HStack(spacing: 6) {
                    // Plaka
                    Text(alarm.plate.isEmpty ? alarm.vehicleName : alarm.plate)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.indigo)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.indigo.opacity(0.08))
                        .cornerRadius(4)

                    if alarm.speed > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "speedometer")
                                .font(.system(size: 9))
                            Text("\(alarm.speed) km/s")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(AppTheme.textMuted)
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
                            .foregroundColor(AppTheme.textMuted)
                            .lineLimit(1)
                    }
                }
            }

            // Ok
            Image(systemName: "chevron.right")
                .font(.system(size: 11))
                .foregroundColor(AppTheme.textFaint)
        }
        .padding(12)
        .background(AppTheme.surface)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 2, y: 1)
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
                                .foregroundColor(AppTheme.textPrimary)
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
                                    .foregroundColor(AppTheme.textPrimary)
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
                .foregroundColor(AppTheme.textMuted)
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
                .foregroundColor(AppTheme.textPrimary)
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(AppTheme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Tekrar Dene") {
                Task { await vm.refresh() }
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

    var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bell.slash")
                .font(.system(size: 44))
                .foregroundColor(AppTheme.textFaint)
            Text("Alarm Bulunamadı")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
            Text("Seçili filtrelere uygun alarm kaydı yok.\nFiltrelerinizi değiştirerek tekrar deneyebilirsiniz.")
                .font(.system(size: 12))
                .foregroundColor(AppTheme.textMuted)
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
                                .fill(alarm.color.opacity(0.12))
                                .frame(width: 60, height: 60)
                            Image(systemName: alarm.icon)
                                .font(.system(size: 26))
                                .foregroundColor(alarm.color)
                        }

                        Text(alarm.typeLabel)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)

                        Text(alarm.formattedFullDate)
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(alarm.color.opacity(0.04))

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
                                    .foregroundColor(AppTheme.textPrimary)
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
            .background(AppTheme.bg)
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
                                .fill(rule.color.opacity(0.12))
                                .frame(width: 60, height: 60)
                            Image(systemName: rule.icon)
                                .font(.system(size: 26))
                                .foregroundColor(rule.color)
                        }

                        Text(rule.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)

                        if let desc = rule.description {
                            Text(desc)
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.textMuted)
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
            .background(AppTheme.bg)
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
                .foregroundColor(AppTheme.textMuted)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textFaint)
                Text(value)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)
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

    var typeOptions: [AlarmTypeOption] {
        catalog?.types ?? [
            AlarmTypeOption(value: "speed_violation", label: "Hız İhlali", description: "Belirlenen hız limitini aşıldığında bildirim alın"),
            AlarmTypeOption(value: "idle_alarm", label: "Rölanti", description: "Araç belirli süreden fazla rölantide kaldığında uyar"),
            AlarmTypeOption(value: "movement_detection", label: "Hareket Algılama", description: "Park halindeki aracın hareket etmesinde uyar"),
            AlarmTypeOption(value: "off_hours_usage", label: "Mesai Dışı Kullanım", description: "Mesai saatleri dışında kullanımda uyar"),
            AlarmTypeOption(value: "geofence_alarm", label: "Bölge Alarmı", description: "Bölgeye giriş/çıkışta bildirim alın")
        ]
    }

    private func iconForType(_ type: String) -> String {
        switch type {
        case "speed_violation": return "speedometer"
        case "idle_alarm": return "hourglass.bottomhalf.filled"
        case "movement_detection": return "car.fill"
        case "off_hours_usage": return "clock.fill"
        case "geofence_alarm": return "location.fill"
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
        default: return AppTheme.indigo
        }
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
                                            .foregroundColor(isActive ? AppTheme.navy : .white.opacity(0.5))
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
            .background(AppTheme.navy)

            // ── Step Content ──
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    switch currentStep {

                    // ═══ STEP 1: İsim & Tür ═══
                    case 1:
                        Text("Alarm Adı")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)

                        TextField("ör. Hız İhlali Alarmı, Depo Kontrolü...", text: $name)
                            .font(.system(size: 14))
                            .padding(12)
                            .background(AppTheme.surface)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.borderSoft, lineWidth: 1))

                        Text("Alarm Türü Seçin")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
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
                                            .foregroundColor(AppTheme.textPrimary)
                                        if !type.description.isEmpty {
                                            Text(type.description)
                                                .font(.system(size: 11))
                                                .foregroundColor(AppTheme.textMuted)
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
                                        .fill(isSelected ? typeColor.opacity(0.06) : AppTheme.surface)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isSelected ? typeColor.opacity(0.3) : AppTheme.borderSoft, lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }

                    // ═══ STEP 2: Araçlar ═══
                    case 2:
                        Text("Hangi araçlar için geçerli olsun?")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)

                        // Search
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.textMuted)
                            TextField("Plaka veya araç ara...", text: $vehicleSearch)
                                .font(.system(size: 13))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(AppTheme.surface)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.borderSoft, lineWidth: 1))

                        // Select All / Clear
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

                        // Vehicle list
                        if let vehicles = catalog?.vehicles {
                            let filtered = vehicleSearch.isEmpty ? vehicles : vehicles.filter {
                                $0.plate.localizedCaseInsensitiveContains(vehicleSearch) || $0.label.localizedCaseInsensitiveContains(vehicleSearch)
                            }
                            ForEach(filtered) { v in
                                let isSelected = selectedVehicles.contains(v.assignmentId)
                                Button(action: {
                                    if isSelected { selectedVehicles.remove(v.assignmentId) }
                                    else { selectedVehicles.insert(v.assignmentId) }
                                }) {
                                    HStack(spacing: 10) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(isSelected ? AppTheme.indigo : .clear)
                                                .frame(width: 20, height: 20)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .stroke(isSelected ? AppTheme.indigo : AppTheme.textMuted, lineWidth: 1.5)
                                                )
                                            if isSelected {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundColor(.white)
                                            }
                                        }

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(v.label)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(AppTheme.textPrimary)
                                            if !v.plate.isEmpty && v.plate != v.label {
                                                Text(v.plate)
                                                    .font(.system(size: 11))
                                                    .foregroundColor(AppTheme.textMuted)
                                            }
                                        }

                                        Spacer()

                                        if isSelected {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 16))
                                                .foregroundColor(AppTheme.indigo)
                                        }
                                    }
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(isSelected ? AppTheme.indigo.opacity(0.06) : AppTheme.surface)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(isSelected ? AppTheme.indigo.opacity(0.2) : AppTheme.borderSoft, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            HStack {
                                ProgressView().scaleEffect(0.8)
                                Text("Araçlar yükleniyor...")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.textMuted)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(20)
                        }

                    // ═══ STEP 3: Koşullar ═══
                    case 3:
                        let typeLabel = typeOptions.first(where: { $0.value == selectedType })?.label ?? selectedType
                        Text("\(typeLabel) Koşulları")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)

                        switch selectedType {
                        case "speed_violation":
                            Text("Araçlarınızın aşmaması gereken hız limitini belirleyin.")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.textMuted)

                            HStack(spacing: 10) {
                                Image(systemName: "speedometer")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color(red: 0.937, green: 0.267, blue: 0.267))
                                TextField("Hız Limiti (km/s)", text: $speedLimit)
                                    .font(.system(size: 14))
                                    .keyboardType(.numberPad)
                            }
                            .padding(12)
                            .background(AppTheme.surface)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.borderSoft, lineWidth: 1))

                            Text("Hızlı Seçim")
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.textMuted)

                            HStack(spacing: 8) {
                                ForEach(["50", "80", "100", "120"], id: \.self) { preset in
                                    let isSel = speedLimit == preset
                                    Button(action: { speedLimit = preset }) {
                                        Text("\(preset) km/s")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(isSel ? .white : AppTheme.textPrimary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(isSel ? AppTheme.indigo : AppTheme.surface)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(isSel ? AppTheme.indigo : AppTheme.borderSoft, lineWidth: 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                        case "idle_alarm":
                            Text("Araçlarınızın rölantide kalabileceği maksimum süreyi belirleyin.")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.textMuted)

                            HStack(spacing: 10) {
                                Image(systemName: "hourglass.bottomhalf.filled")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color(red: 0.961, green: 0.620, blue: 0.043))
                                TextField("Rölanti Süresi (saniye)", text: $idleAfterSec)
                                    .font(.system(size: 14))
                                    .keyboardType(.numberPad)
                            }
                            .padding(12)
                            .background(AppTheme.surface)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.borderSoft, lineWidth: 1))

                            Text("Hızlı Seçim")
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.textMuted)

                            HStack(spacing: 8) {
                                ForEach([("180", "3 dk"), ("300", "5 dk"), ("600", "10 dk"), ("900", "15 dk")], id: \.0) { sec, label in
                                    let isSel = idleAfterSec == sec
                                    Button(action: { idleAfterSec = sec }) {
                                        Text(label)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(isSel ? .white : AppTheme.textPrimary)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(isSel ? AppTheme.indigo : AppTheme.surface)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(isSel ? AppTheme.indigo : AppTheme.borderSoft, lineWidth: 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                        case "geofence_alarm":
                            Text("Alarm tetiklenecek bölgeyi seçin.")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.textMuted)

                            if let geofences = catalog?.geofences {
                                ForEach(geofences) { gf in
                                    let isSel = selectedGeofence == gf.id
                                    Button(action: { selectedGeofence = gf.id }) {
                                        HStack(spacing: 10) {
                                            Image(systemName: "location.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(isSel ? AppTheme.indigo : AppTheme.textMuted)
                                            Text(gf.name)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(AppTheme.textPrimary)
                                            Spacer()
                                            if isSel {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 16))
                                                    .foregroundColor(AppTheme.indigo)
                                            }
                                        }
                                        .padding(12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(isSel ? AppTheme.indigo.opacity(0.06) : AppTheme.surface)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(isSel ? AppTheme.indigo.opacity(0.2) : AppTheme.borderSoft, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            } else {
                                Text("Bölge bulunamadı")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.textMuted)
                            }

                        case "movement_detection":
                            VStack(alignment: .leading, spacing: 8) {
                                Image(systemName: "car.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(Color(red: 0.133, green: 0.773, blue: 0.369))
                                Text("Hareket Algılama")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppTheme.textPrimary)
                                Text("Park halindeki araç sallanma, çekilme veya hareket etme durumunda otomatik uyarı alacaksınız. Ek koşul gerekmez.")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.textMuted)
                                    .lineSpacing(4)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(red: 0.133, green: 0.773, blue: 0.369).opacity(0.06))
                            )

                        case "off_hours_usage":
                            VStack(alignment: .leading, spacing: 8) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(Color(red: 0.659, green: 0.333, blue: 0.969))
                                Text("Mesai Dışı Kullanım")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppTheme.textPrimary)
                                Text("Varsayılan ayarlar: Hafta içi 08:00 - 18:00 arası mesai. Bu saat aralığı dışında araç kullanıldığında bildirim alırsınız.")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.textMuted)
                                    .lineSpacing(4)
                                HStack(spacing: 6) {
                                    ForEach(["Pzt", "Sal", "Çar", "Per", "Cum"], id: \.self) { day in
                                        Text(day)
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(Color(red: 0.659, green: 0.333, blue: 0.969))
                                            .frame(width: 36, height: 36)
                                            .background(
                                                Circle()
                                                    .fill(Color(red: 0.659, green: 0.333, blue: 0.969).opacity(0.15))
                                            )
                                    }
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(red: 0.659, green: 0.333, blue: 0.969).opacity(0.06))
                            )

                        default:
                            EmptyView()
                        }

                    // ═══ STEP 4: Bildirim ═══
                    case 4:
                        // Channels
                        Text("Bildirim Kanalları")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                        Text("Alarm tetiklendiğinde hangi kanallardan bildirim almak istiyorsunuz?")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textMuted)

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
                                            .foregroundColor(AppTheme.textPrimary)
                                        Text(ch.desc)
                                            .font(.system(size: 11))
                                            .foregroundColor(AppTheme.textMuted)
                                    }

                                    Spacer()

                                    ZStack {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(isSel ? ch.color : .clear)
                                            .frame(width: 22, height: 22)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 4)
                                                    .stroke(isSel ? ch.color : AppTheme.textMuted, lineWidth: 1.5)
                                            )
                                        if isSel {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(isSel ? ch.color.opacity(0.06) : AppTheme.surface)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isSel ? ch.color.opacity(0.3) : AppTheme.borderSoft, lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        // Recipients
                        Text("Alıcılar")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                            .padding(.top, 8)
                        Text("Alarm bildirimlerini kimler alsın?")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textMuted)

                        if let recipients = catalog?.recipients {
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
                                                .foregroundColor(AppTheme.textPrimary)
                                            Text(r.email)
                                                .font(.system(size: 11))
                                                .foregroundColor(AppTheme.textMuted)
                                        }

                                        Spacer()

                                        ZStack {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(isSel ? AppTheme.indigo : .clear)
                                                .frame(width: 20, height: 20)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .stroke(isSel ? AppTheme.indigo : AppTheme.textMuted, lineWidth: 1.5)
                                                )
                                            if isSel {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(.white)
                                            }
                                        }
                                    }
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(isSel ? AppTheme.indigo.opacity(0.06) : AppTheme.surface)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(isSel ? AppTheme.indigo.opacity(0.2) : AppTheme.borderSoft, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            HStack {
                                ProgressView().scaleEffect(0.8)
                                Text("Alıcılar yükleniyor...")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.textMuted)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(16)
                        }

                        // Summary card
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Özet")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(AppTheme.navy)

                            HStack(spacing: 4) {
                                Image(systemName: "tag.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.textMuted)
                                Text("Tür: \(typeOptions.first(where: { $0.value == selectedType })?.label ?? selectedType)")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            HStack(spacing: 4) {
                                Image(systemName: "car.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.textMuted)
                                Text("\(selectedVehicles.count) araç seçildi")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            HStack(spacing: 4) {
                                Image(systemName: "bell.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.textMuted)
                                Text("\(selectedChannels.count) kanal, \(selectedRecipients.count) alıcı")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppTheme.navy.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppTheme.navy.opacity(0.1), lineWidth: 1)
                        )
                        .padding(.top, 8)

                    default:
                        EmptyView()
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
                        .foregroundColor(AppTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppTheme.borderSoft, lineWidth: 1)
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
                        currentStep = 4
                    case 4:
                        Task { await save() }
                    default: break
                    }
                }) {
                    HStack(spacing: 6) {
                        if isSaving {
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
                            .fill(currentStep == 4 ? Color(red: 0.133, green: 0.773, blue: 0.369) : AppTheme.navy)
                    )
                }
                .disabled(isSaving)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(AppTheme.surface)
        }
        .background(AppTheme.bg)
        .onAppear {
            // Pre-select vehicle by plate
            if !preSelectedPlate.isEmpty, let vehicles = catalog?.vehicles {
                if let match = vehicles.first(where: { $0.plate.localizedCaseInsensitiveCompare(preSelectedPlate) == .orderedSame || $0.label.localizedCaseInsensitiveContains(preSelectedPlate) }) {
                    selectedVehicles.insert(match.assignmentId)
                }
            }
            // Pre-select first recipient
            if let first = catalog?.recipients?.first {
                selectedRecipients.insert(first.id)
            }
        }
    }

    private func save() async {
        guard !name.isEmpty else { errorMsg = "Kural adı gerekli"; return }
        guard !selectedVehicles.isEmpty else { errorMsg = "En az bir araç seçin"; return }
        guard !selectedChannels.isEmpty else { errorMsg = "En az bir bildirim kanalı seçin"; return }
        guard !selectedRecipients.isEmpty else { errorMsg = "En az bir alıcı seçin"; return }

        isSaving = true
        errorMsg = nil

        var body: [String: Any] = [
            "name": name,
            "alarm_type": selectedType,
            "status": "active",
            "evaluation_mode": "live",
            "source_mode": selectedType == "speed_violation" ? "existing" : "derived",
            "cooldown_sec": 300,
            "is_active": true,
            "condition_require_ignition": true,
            "targets": selectedVehicles.map { ["scope": "assignment", "id": $0] },
            "channels": Array(selectedChannels),
            "recipient_ids": Array(selectedRecipients)
        ]

        switch selectedType {
        case "speed_violation":
            body["condition_speed_limit_kmh"] = Int(speedLimit) ?? 80
            body["condition_speed_duration_sec"] = 5
        case "idle_alarm":
            body["condition_idle_after_sec"] = Int(idleAfterSec) ?? 300
            body["condition_speed_threshold_kmh"] = 0
        case "geofence_alarm":
            if let gf = selectedGeofence { body["condition_geofence_id"] = gf }
            body["condition_geofence_trigger"] = "both"
        case "off_hours_usage":
            body["condition_start_local"] = "08:00"
            body["condition_end_local"] = "18:00"
            body["condition_timezone"] = "Europe/Istanbul"
            body["condition_min_speed_kmh"] = 1
            body["condition_days"] = [1, 2, 3, 4, 5]
        default: break
        }

        do {
            _ = try await APIService.shared.post("/api/mobile/alarm-sets/", body: body)
            onCreated()
        } catch {
            errorMsg = "Kayıt başarısız: \(error.localizedDescription)"
        }

        isSaving = false
    }
}

#Preview {
    AlarmsView(showSideMenu: .constant(false))
        .environmentObject(AuthViewModel())
}
