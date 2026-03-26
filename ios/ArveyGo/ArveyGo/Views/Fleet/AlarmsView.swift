import SwiftUI

// MARK: - Alarm Model
struct AlarmEvent: Identifiable, Hashable {
    let id: Int
    let imei: String
    let plate: String
    let vehicleName: String
    let type: String
    let code: String
    let lat: Double
    let lng: Double
    let speed: Int
    let createdAt: String

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: AlarmEvent, rhs: AlarmEvent) -> Bool { lhs.id == rhs.id }

    var icon: String {
        switch type.lowercased() {
        case let t where t.contains("overspeed") || t.contains("hız"):
            return "gauge.with.dots.needle.33percent"
        case let t where t.contains("brake") || t.contains("fren"):
            return "exclamationmark.octagon.fill"
        case let t where t.contains("idle") || t.contains("rölanti"):
            return "clock.fill"
        case let t where t.contains("geofence") || t.contains("bölge"):
            return "mappin.and.ellipse"
        case let t where t.contains("disconnect") || t.contains("bağlantı"):
            return "antenna.radiowaves.left.and.right.slash"
        case let t where t.contains("sos") || t.contains("panik"):
            return "sos"
        case let t where t.contains("tow") || t.contains("çekici"):
            return "car.side.rear.and.collision.and.car.side.front"
        default:
            return "bell.fill"
        }
    }

    var color: Color {
        switch type.lowercased() {
        case let t where t.contains("overspeed") || t.contains("hız") || t.contains("sos") || t.contains("panik"):
            return .red
        case let t where t.contains("brake") || t.contains("fren") || t.contains("disconnect"):
            return .orange
        case let t where t.contains("idle") || t.contains("rölanti"):
            return Color(red: 245/255, green: 158/255, blue: 11/255)
        case let t where t.contains("geofence") || t.contains("enter"):
            return .green
        default:
            return AppTheme.indigo
        }
    }

    var typeLabel: String {
        switch type.lowercased() {
        case "overspeed": return "Hız Aşımı"
        case "harsh_brake": return "Sert Fren"
        case "harsh_acceleration": return "Sert Hızlanma"
        case "idle": return "Rölanti"
        case "geofence_enter": return "Bölgeye Giriş"
        case "geofence_exit": return "Bölgeden Çıkış"
        case "disconnect": return "Bağlantı Koptu"
        case "sos": return "SOS / Panik"
        case "tow": return "Çekici Algılandı"
        case "power_cut": return "Güç Kesildi"
        case "low_battery": return "Düşük Batarya"
        case "tampering": return "Cihaz Müdahalesi"
        default: return type.replacingOccurrences(of: "_", with: " ").capitalized
        }
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

    static func from(json: [String: Any]) -> AlarmEvent {
        AlarmEvent(
            id: json["id"] as? Int ?? 0,
            imei: json["imei"] as? String ?? "",
            plate: json["plate"] as? String ?? "",
            vehicleName: json["vehicle_name"] as? String ?? "",
            type: json["type"] as? String ?? "",
            code: json["code"] as? String ?? "",
            lat: json["lat"] as? Double ?? 0,
            lng: json["lng"] as? Double ?? 0,
            speed: json["speed"] as? Int ?? 0,
            createdAt: json["created_at"] as? String ?? ""
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

            let newAlarms = dataArr.map { AlarmEvent.from(json: $0) }

            if append {
                alarms.append(contentsOf: newAlarms)
            } else {
                alarms = newAlarms
            }

            currentPage = pagination["current_page"] as? Int ?? page
            lastPage = pagination["last_page"] as? Int ?? 1
            totalCount = pagination["total"] as? Int ?? alarms.count
        } catch {
            // API henüz hazır değilse dummy veri göster
            if !append {
                alarms = Self.dummyAlarms
                totalCount = alarms.count
                currentPage = 1
                lastPage = 1
            }
            errorMessage = nil
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

    // MARK: - Dummy Data
    private static let dummyAlarms: [AlarmEvent] = [
        AlarmEvent(id: 1, imei: "353742378104285", plate: "06 ATS 001", vehicleName: "Beyaz Sprinter", type: "overspeed", code: "Hız limiti: 120 km/s, Anlık: 138 km/s", lat: 39.9208, lng: 32.8541, speed: 138, createdAt: "2026-03-26 14:22:00"),
        AlarmEvent(id: 2, imei: "353742379713316", plate: "34 ARV 34", vehicleName: "Siyah Vito", type: "harsh_brake", code: "Ani fren algılandı", lat: 41.0082, lng: 28.9784, speed: 67, createdAt: "2026-03-26 13:45:00"),
        AlarmEvent(id: 3, imei: "353742378104285", plate: "06 ATS 001", vehicleName: "Beyaz Sprinter", type: "geofence_exit", code: "Ankara Merkez bölgesinden çıkış", lat: 39.9334, lng: 32.8597, speed: 45, createdAt: "2026-03-26 12:30:00"),
        AlarmEvent(id: 4, imei: "353742379713316", plate: "34 ARV 34", vehicleName: "Siyah Vito", type: "idle", code: "15 dk rölanti - Kontak açık, araç durağan", lat: 41.0136, lng: 28.9550, speed: 0, createdAt: "2026-03-26 11:15:00"),
        AlarmEvent(id: 5, imei: "353742378104285", plate: "06 ATS 001", vehicleName: "Beyaz Sprinter", type: "sos", code: "Panik butonu basıldı", lat: 39.9248, lng: 32.8662, speed: 0, createdAt: "2026-03-26 10:50:00"),
        AlarmEvent(id: 6, imei: "353742379713316", plate: "34 ARV 34", vehicleName: "Siyah Vito", type: "harsh_acceleration", code: "Ani hızlanma algılandı", lat: 41.0210, lng: 28.9390, speed: 82, createdAt: "2026-03-26 10:05:00"),
        AlarmEvent(id: 7, imei: "353742378104285", plate: "06 ATS 001", vehicleName: "Beyaz Sprinter", type: "disconnect", code: "Cihaz bağlantısı kesildi", lat: 39.9180, lng: 32.8450, speed: 0, createdAt: "2026-03-26 09:30:00"),
        AlarmEvent(id: 8, imei: "353742379713316", plate: "34 ARV 34", vehicleName: "Siyah Vito", type: "overspeed", code: "Hız limiti: 50 km/s, Anlık: 73 km/s", lat: 41.0350, lng: 28.9850, speed: 73, createdAt: "2026-03-26 08:45:00"),
        AlarmEvent(id: 9, imei: "353742378104285", plate: "06 ATS 001", vehicleName: "Beyaz Sprinter", type: "geofence_enter", code: "Ankara Merkez bölgesine giriş", lat: 39.9255, lng: 32.8540, speed: 35, createdAt: "2026-03-26 08:00:00"),
        AlarmEvent(id: 10, imei: "353742379713316", plate: "34 ARV 34", vehicleName: "Siyah Vito", type: "power_cut", code: "Harici güç kaynağı kesildi", lat: 41.0082, lng: 28.9784, speed: 0, createdAt: "2026-03-25 23:10:00"),
    ]
}

// MARK: - Alarm Rule Model (Kullanıcının oluşturduğu kurallar)
struct AlarmRule: Identifiable, Hashable {
    let id: Int
    let name: String
    let type: String
    let condition: String
    let vehicles: String // hangi araçlara uygulanıyor
    let isActive: Bool
    let createdAt: String

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: AlarmRule, rhs: AlarmRule) -> Bool { lhs.id == rhs.id }

    var icon: String {
        switch type.lowercased() {
        case "overspeed": return "gauge.with.dots.needle.33percent"
        case "geofence": return "mappin.and.ellipse"
        case "idle": return "clock.fill"
        case "harsh_brake": return "exclamationmark.octagon.fill"
        case "disconnect": return "antenna.radiowaves.left.and.right.slash"
        case "power_cut": return "bolt.slash.fill"
        case "sos": return "sos"
        default: return "bell.badge.fill"
        }
    }

    var color: Color {
        switch type.lowercased() {
        case "overspeed", "sos": return .red
        case "geofence": return .green
        case "idle": return Color(red: 245/255, green: 158/255, blue: 11/255)
        case "harsh_brake", "disconnect": return .orange
        default: return AppTheme.indigo
        }
    }

    var typeLabel: String {
        switch type.lowercased() {
        case "overspeed": return "Hız Aşımı"
        case "geofence": return "Geofence"
        case "idle": return "Rölanti"
        case "harsh_brake": return "Sert Fren"
        case "disconnect": return "Bağlantı Kopma"
        case "power_cut": return "Güç Kesilmesi"
        case "sos": return "SOS / Panik"
        default: return type.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

// MARK: - Dummy Alarm Rules
private let dummyAlarmRules: [AlarmRule] = [
    AlarmRule(id: 1, name: "Şehir İçi Hız Limiti", type: "overspeed", condition: "Hız > 50 km/s", vehicles: "Tüm Araçlar", isActive: true, createdAt: "2026-01-15"),
    AlarmRule(id: 2, name: "Otoban Hız Limiti", type: "overspeed", condition: "Hız > 120 km/s", vehicles: "Tüm Araçlar", isActive: true, createdAt: "2026-01-15"),
    AlarmRule(id: 3, name: "Ankara Merkez Bölgesi", type: "geofence", condition: "Bölgeden çıkışta bildir", vehicles: "06 ATS 001, 06 TUV 222", isActive: true, createdAt: "2026-02-10"),
    AlarmRule(id: 4, name: "İstanbul Depo Bölgesi", type: "geofence", condition: "Bölgeye girişte bildir", vehicles: "34 ARV 34, 34 ABC 123", isActive: false, createdAt: "2026-02-20"),
    AlarmRule(id: 5, name: "Rölanti Uyarısı", type: "idle", condition: "10 dk üzeri rölanti", vehicles: "Tüm Araçlar", isActive: true, createdAt: "2026-03-01"),
    AlarmRule(id: 6, name: "Sert Fren Algılama", type: "harsh_brake", condition: "Ani fren algılandığında", vehicles: "Tüm Araçlar", isActive: true, createdAt: "2026-03-05"),
    AlarmRule(id: 7, name: "Bağlantı Kopma Uyarısı", type: "disconnect", condition: "Cihaz bağlantısı kesildiğinde", vehicles: "06 ATS 001", isActive: false, createdAt: "2026-03-10"),
    AlarmRule(id: 8, name: "SOS Butonu", type: "sos", condition: "Panik butonu basıldığında", vehicles: "Tüm Araçlar", isActive: true, createdAt: "2026-03-12"),
]

// MARK: - Alarms View
struct AlarmsView: View {
    @Binding var showSideMenu: Bool
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = AlarmsViewModel()
    @State private var showFilters = false
    @State private var selectedTab = 0 // 0: Gelen Alarmlar, 1: Alarm Kuralları
    @State private var searchText = ""
    @State private var selectedAlarm: AlarmEvent? = nil
    @State private var selectedRule: AlarmRule? = nil

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
            .sheet(item: $selectedRule) { rule in
                ruleDetailSheet(rule)
            }
            .onChange(of: selectedTab) { _ in
                searchText = ""
            }
        }
        .task {
            await vm.fetchAlarms()
        }
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
    var filteredRules: [AlarmRule] {
        guard !searchText.isEmpty else { return dummyAlarmRules }
        let q = searchText.lowercased()
        return dummyAlarmRules.filter {
            $0.name.lowercased().contains(q) ||
            $0.typeLabel.lowercased().contains(q) ||
            $0.condition.lowercased().contains(q) ||
            $0.vehicles.lowercased().contains(q)
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
        ScrollView {
            LazyVStack(spacing: 8) {
                // Search
                searchBar

                // Yeni Kural Ekle butonu — kart tarzı
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

                ForEach(filteredRules) { rule in
                    alarmRuleCard(rule)
                        .onTapGesture { selectedRule = rule }
                }
            }
            .padding(.bottom, 20)
        }
    }

    // MARK: - New Rule Button (Kart tarzı)
    var newRuleButton: some View {
        Button(action: {}) {
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

    // MARK: - Alarm Rule Card
    func alarmRuleCard(_ rule: AlarmRule) -> some View {
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

                // Aktif/Pasif toggle göstergesi
                HStack(spacing: 4) {
                    Circle()
                        .fill(rule.isActive ? Color.green : Color.gray)
                        .frame(width: 7, height: 7)
                    Text(rule.isActive ? "Aktif" : "Pasif")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(rule.isActive ? .green : .gray)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((rule.isActive ? Color.green : Color.gray).opacity(0.1))
                .cornerRadius(12)
            }

            // Detaylar
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textFaint)
                    Text("Koşul: \(rule.condition)")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textSecondary)
                }
                HStack(spacing: 6) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textFaint)
                    Text("Araçlar: \(rule.vehicles)")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(1)
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
                    if vm.isLoading {
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
                            // Son öğeye gelince daha fazla yükle
                            if alarm.id == vm.alarms.last?.id {
                                Task { await vm.loadMore() }
                            }
                        }
                }

                if vm.currentPage < vm.lastPage {
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

                if !alarm.code.isEmpty {
                    Text(alarm.code)
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textMuted)
                        .lineLimit(1)
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

                        Text(alarm.formattedDate)
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
                        detailRow(icon: "doc.text.fill", title: "Açıklama", value: alarm.code.isEmpty ? "—" : alarm.code)
                        Divider().padding(.leading, 44)
                        detailRow(icon: "mappin.circle.fill", title: "Konum", value: String(format: "%.4f, %.4f", alarm.lat, alarm.lng))
                        Divider().padding(.leading, 44)
                        detailRow(icon: "calendar", title: "Tarih", value: alarm.createdAt)
                    }
                    .padding(.top, 8)
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
    func ruleDetailSheet(_ rule: AlarmRule) -> some View {
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

                        // Aktif/Pasif badge
                        HStack(spacing: 5) {
                            Circle()
                                .fill(rule.isActive ? Color.green : Color.gray)
                                .frame(width: 8, height: 8)
                            Text(rule.isActive ? "Aktif" : "Pasif")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(rule.isActive ? .green : .gray)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background((rule.isActive ? Color.green : Color.gray).opacity(0.1))
                        .cornerRadius(16)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(rule.color.opacity(0.04))

                    // Details
                    VStack(spacing: 0) {
                        detailRow(icon: "tag.fill", title: "Alarm Türü", value: rule.typeLabel)
                        Divider().padding(.leading, 44)
                        detailRow(icon: "exclamationmark.triangle.fill", title: "Koşul", value: rule.condition)
                        Divider().padding(.leading, 44)
                        detailRow(icon: "car.fill", title: "Araçlar", value: rule.vehicles)
                        Divider().padding(.leading, 44)
                        detailRow(icon: "calendar", title: "Oluşturulma", value: rule.createdAt)
                    }
                    .padding(.top, 8)

                    // Actions
                    VStack(spacing: 10) {
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "pencil")
                                Text("Kuralı Düzenle")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppTheme.indigo)
                            .cornerRadius(10)
                        }

                        Button(action: {}) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Kuralı Sil")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.08))
                            .cornerRadius(10)
                        }
                    }
                    .padding(16)
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

#Preview {
    AlarmsView(showSideMenu: .constant(false))
        .environmentObject(AuthViewModel())
}
