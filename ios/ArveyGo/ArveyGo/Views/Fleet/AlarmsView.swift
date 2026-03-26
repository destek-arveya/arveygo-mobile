import SwiftUI

// MARK: - Alarm Model
struct AlarmEvent: Identifiable {
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
            errorMessage = error.localizedDescription
            if !append { alarms = [] }
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

// MARK: - Alarms View
struct AlarmsView: View {
    @Binding var showSideMenu: Bool
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = AlarmsViewModel()
    @State private var showFilters = false

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
                        Button(action: { withAnimation { showFilters.toggle() } }) {
                            Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                .font(.system(size: 18))
                                .foregroundColor(hasActiveFilters ? AppTheme.indigo : AppTheme.textMuted)
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
        }
        .task {
            await vm.fetchAlarms()
        }
    }

    var hasActiveFilters: Bool {
        vm.selectedImei != nil || vm.selectedType != nil || vm.dateFrom != nil || vm.dateTo != nil
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
                    Text("\(vm.totalCount) alarm")
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

                ForEach(vm.alarms) { alarm in
                    alarmCard(alarm)
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
}

#Preview {
    AlarmsView(showSideMenu: .constant(false))
        .environmentObject(AuthViewModel())
}
