import SwiftUI
import Combine

struct VehiclesListView: View {
    enum DisplayMode {
        case standalone
        case embedded
    }

    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var vm = VehiclesListViewModel()
    @Binding var showSideMenu: Bool
    @Binding var selectedPage: AppPage
    @Binding var alarmsSearchText: String
    @Binding var alarmsAutoOpenCreate: Bool
    @Binding var alarmsPrePlate: String
    var displayMode: DisplayMode = .standalone

    @State private var selectedVehicle: Vehicle?
    @State private var routeHistoryVehicle: Vehicle?
    @State private var showRouteHistoryPage = false
    
    private var isDark: Bool { colorScheme == .dark }
    private var pageBackground: Color {
        isDark ? Color(red: 14/255, green: 18/255, blue: 34/255) : Color(UIColor.systemGroupedBackground)
    }
    private var cardSurface: Color {
        isDark ? Color(red: 22/255, green: 28/255, blue: 49/255) : .white
    }
    private var elevatedSurface: Color {
        isDark ? Color(red: 19/255, green: 24/255, blue: 43/255) : Color(UIColor.secondarySystemGroupedBackground)
    }
    private var borderColor: Color {
        isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
    }
    private var primaryText: Color {
        isDark ? AppTheme.darkText : AppTheme.textPrimary
    }
    private var secondaryText: Color {
        isDark ? AppTheme.darkTextSub : AppTheme.textSecondary
    }
    private var mutedText: Color {
        isDark ? AppTheme.darkTextMuted : AppTheme.textMuted
    }
    private var cardShadow: Color {
        isDark ? Color.black.opacity(0.20) : Color.black.opacity(0.06)
    }

    var body: some View {
        Group {
            if displayMode == .standalone {
                NavigationStack {
                    vehiclesContent
                }
            } else {
                vehiclesContent
            }
        }
    }

    private var vehiclesContent: some View {
            ZStack {
                pageBackground.ignoresSafeArea()

                if vm.isLoading && vm.vehicles.isEmpty {
                    VehiclesListSkeletonView()
                } else if let error = vm.errorMessage, vm.vehicles.isEmpty {
                    vehicleErrorState(message: error)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            // Status summary chips
                            statusChips

                            // Search & Filter
                            searchAndFilter

                            // Vehicle Cards
                            vehicleCards
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                        .padding(.bottom, 24)
                    }
                    .refreshable {
                        await vm.refresh()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(pageBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(isDark ? .dark : .light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("Araçlarım")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(primaryText)
                        Text("Filo Yönetimi / Araçlar")
                            .font(.system(size: 10))
                            .foregroundColor(mutedText)
                    }
                }

                if displayMode == .standalone {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        AvatarCircle(
                            initials: authVM.currentUser?.avatar ?? "A",
                            size: 30
                        )
                    }
                }
            }
            .navigationDestination(isPresented: $showRouteHistoryPage) {
                RouteHistoryView(
                    showSideMenu: .constant(false),
                    displayMode: .embedded,
                    initialVehicle: routeHistoryVehicle,
                    autoLoadInitialVehicle: routeHistoryVehicle != nil
                )
            }
            .fullScreenCover(item: $selectedVehicle) { vehicle in
                NavigationStack {
                    VehicleDetailFifthView(
                        vehicle: vehicle,
                        presentationMode: .modal,
                        onNavigateToRouteHistory: { v in
                            selectedVehicle = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                routeHistoryVehicle = v
                                showRouteHistoryPage = true
                            }
                        },
                        onNavigateToAlarms: { plateText in
                            selectedVehicle = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                alarmsSearchText = plateText
                                selectedPage = .alarms
                            }
                        },
                        onNavigateToAddAlarm: { plate in
                            selectedVehicle = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                alarmsSearchText = ""
                                alarmsAutoOpenCreate = true
                                alarmsPrePlate = plate
                                selectedPage = .alarms
                            }
                        }
                    )
                }
            }
    }

    // MARK: - Status Summary Chips
    var statusChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                statusChip(label: "Toplam", count: vm.vehicles.count, color: AppTheme.navy, isSelected: vm.statusFilter == nil) {
                    vm.statusFilter = nil
                }
                statusChip(label: "Kontak Açık", count: vm.onlineCount, color: AppTheme.online, isSelected: vm.statusFilter == .ignitionOn) {
                    vm.statusFilter = vm.statusFilter == .ignitionOn ? nil : .ignitionOn
                }
                statusChip(label: "Kontak Kapalı", count: vm.offlineCount, color: AppTheme.offline, isSelected: vm.statusFilter == .ignitionOff) {
                    vm.statusFilter = vm.statusFilter == .ignitionOff ? nil : .ignitionOff
                }
                statusChip(label: "Bilgi Yok", count: vm.noDataCount, color: AppTheme.textMuted, isSelected: vm.statusFilter == .noData) {
                    vm.statusFilter = vm.statusFilter == .noData ? nil : .noData
                }
                statusChip(label: "Uyku", count: vm.sleepingCount, color: AppTheme.idle, isSelected: vm.statusFilter == .sleeping) {
                    vm.statusFilter = vm.statusFilter == .sleeping ? nil : .sleeping
                }
            }
        }
    }

    func statusChip(label: String, count: Int, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? color : secondaryText)
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isSelected ? color : mutedText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isSelected ? color.opacity(isDark ? 0.16 : 0.12) : elevatedSurface)
                    )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? color.opacity(isDark ? 0.12 : 0.08) : cardSurface)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(isSelected ? color.opacity(0.32) : borderColor, lineWidth: 1)
            )
        }
    }

    // MARK: - Search and Filter
    var searchAndFilter: some View {
        VStack(spacing: 8) {
            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundColor(mutedText)
                TextField("Plaka, araç veya sürücü ara...", text: $vm.searchText)
                    .font(.system(size: 14))
                    .foregroundColor(primaryText)
                if !vm.searchText.isEmpty {
                    Button(action: { vm.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(mutedText)
                    }
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(elevatedSurface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 1)
            )

            // Group filter + count
            HStack(spacing: 8) {
                Menu {
                    Button("Tüm Gruplar") { vm.groupFilter = nil }
                    ForEach(vm.groups, id: \.self) { group in
                        Button(group) { vm.groupFilter = group }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                            .font(.system(size: 12))
                            .foregroundColor(mutedText)
                        Text(vm.groupFilter ?? "Tüm Gruplar")
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundColor(primaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(elevatedSurface)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(borderColor, lineWidth: 1)
                    )
                }

                Spacer()

                Text("\(vm.filteredVehicles.count) araç listeleniyor")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(mutedText)
            }
        }
        .padding(12)
        .background(cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .shadow(color: cardShadow, radius: 10, x: 0, y: 5)
    }

    // MARK: - Vehicle Cards
    var vehicleCards: some View {
        VStack(spacing: 10) {
            ForEach(vm.filteredVehicles) { vehicle in
                vehicleCard(vehicle)
                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .gesture(TapGesture().onEnded {
                        selectedVehicle = vehicle
                    }, including: .gesture)
            }

            if vm.filteredVehicles.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "car.2.fill")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.darkTextMuted.opacity(0.4))
                    Text("Araç bulunamadı")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppTheme.darkTextMuted)
                    Text("Filtre veya arama kriterlerinizi değiştirin")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.darkTextMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            }
        }
    }

    // MARK: - Vehicle Card
    func vehicleCard(_ vehicle: Vehicle) -> some View {
        let driverText = vehicle.listDriverName
        let metricSurface = isDark ? Color.white.opacity(0.03) : elevatedSurface
        let secondaryMeta = driverText.isEmpty ? vehicle.group : driverText

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(vehicle.status.color.opacity(isDark ? 0.18 : 0.12))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: vehicle.mapIcon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(vehicle.status.color)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(vehicle.plate)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(primaryText)

                    HStack(spacing: 6) {
                        Text(vehicle.vehicleType)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(secondaryText)
                            .lineLimit(1)
                        Text("•")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(mutedText)
                        Text(vehicle.kontakOn ? "Kontak Açık" : "Kontak Kapalı")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(vehicle.kontakOn ? AppTheme.online : AppTheme.offline)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 12)

                HStack(spacing: 10) {
                    fleetStatusBadge(vehicle.fleetStatus)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(mutedText)
                }
            }

            HStack(spacing: 8) {
                refinedMetricCard(
                    title: "Hız",
                    value: vehicle.formattedSpeed,
                    icon: "speedometer",
                    tint: vehicle.speed > 0 ? AppTheme.online : mutedText,
                    background: metricSurface
                )
                refinedMetricCard(
                    title: "Bugün",
                    value: vehicle.formattedTodayKm,
                    icon: "calendar",
                    tint: AppTheme.indigo,
                    background: metricSurface
                )
                refinedMetricCard(
                    title: "Toplam",
                    value: "\(vehicle.formattedTotalKm) km",
                    icon: "road.lanes",
                    tint: isDark ? AppTheme.lavender : AppTheme.navy,
                    background: metricSurface
                )
            }

            HStack(alignment: .center, spacing: 8) {
                if secondaryMeta != "—" {
                    Text(secondaryMeta)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(mutedText)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if !vehicle.listLastInfoLabel.isEmpty {
                    vehicleMetaLabel(
                        icon: "clock.fill",
                        text: vehicle.listLastInfoLabel,
                        tint: mutedText
                    )
                }

                if let temp = vehicle.temperatureC {
                    vehicleMetaLabel(
                        icon: "thermometer.medium",
                        text: String(format: "%.1f°C", temp),
                        tint: temp < 0 ? .blue : temp < 30 ? AppTheme.online : .red
                    )
                }

                if let hum = vehicle.humidityPct {
                    vehicleMetaLabel(icon: "humidity.fill", text: "%\(Int(hum))", tint: AppTheme.indigo)
                }
            }
        }
        .padding(12)
        .background(cardSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .shadow(color: cardShadow, radius: 8, x: 0, y: 4)
    }

    func refinedMetricCard(title: String, value: String, icon: String, tint: Color, background: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 24, height: 24)
                .background(tint.opacity(isDark ? 0.16 : 0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(mutedText)
                Text(value)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background(background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    func detailPill(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(mutedText)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(elevatedSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    func vehicleMetaLabel(icon: String, text: String, tint: Color? = nil) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(tint ?? mutedText)
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(mutedText)
        }
    }

    // MARK: - Fleet Status Badge
    func fleetStatusBadge(_ status: FleetVehicleStatus) -> some View {
        Text(status.label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(status.color)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(status.color.opacity(isDark ? 0.16 : 0.10))
            .clipShape(Capsule(style: .continuous))
    }

    private func vehicleErrorState(message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(AppTheme.offline)
            Text("Araç verisi alınamadı")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(primaryText)
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(mutedText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Button("Tekrar Dene") {
                Task { await vm.refresh() }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(AppTheme.indigo, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }
}

// MARK: - Fleet Vehicle Status (for vehicles list page)
enum FleetVehicleStatus: String {
    case active, passive, maintenance

    var label: String {
        switch self {
        case .active: return "Aktif"
        case .passive: return "Kapalı"
        case .maintenance: return "Bakımda"
        }
    }

    var color: Color {
        switch self {
        case .active: return AppTheme.online
        case .passive: return AppTheme.offline
        case .maintenance: return AppTheme.idle
        }
    }
}

// MARK: - Vehicle Extensions for Fleet
extension Vehicle {
    var listDriverName: String {
        if !driverName.isEmpty { return driverName }
        if !driver.isEmpty { return driver }
        return ""
    }

    var fleetStatus: FleetVehicleStatus {
        switch status {
        case .ignitionOn: return .active
        case .ignitionOff: return .passive
        case .noData: return .passive
        case .sleeping: return .maintenance
        }
    }

    var group: String {
        if !groupName.isEmpty { return groupName }
        return "—"
    }

    var vehicleType: String {
        if !vehicleBrand.isEmpty && !vehicleModel.isEmpty { return "\(vehicleBrand) \(vehicleModel)" }
        if !vehicleBrand.isEmpty { return vehicleBrand }
        if vehicleCategory == "motorcycle" { return "Motosiklet" }
        if model.contains("Transit") || model.contains("Sprinter") { return "Panelvan" }
        if model.contains("Crafter") || model.contains("Master") { return "Kamyonet" }
        return "Ticari"
    }

    var locationDisplay: String {
        if !address.isEmpty { return address }
        if !city.isEmpty { return city }
        if lat != 0 && lng != 0 { return String(format: "%.4f, %.4f", lat, lng) }
        return "—"
    }

    var totalCost: String { "—" }

    var listLastInfoLabel: String {
        if let lastPacketAt, !lastPacketAt.isEmpty {
            return formattedLastPacketAt
        }
        if let deviceTime, !deviceTime.isEmpty {
            return formattedDeviceTime
        }
        return ""
    }
}

// MARK: - Vehicles List ViewModel
@MainActor
class VehiclesListViewModel: ObservableObject {
    @Published var vehicles: [Vehicle] = []
    @Published var searchText = ""
    @Published var statusFilter: VehicleStatus? = nil
    @Published var groupFilter: String? = nil
    @Published var isLoading = true
    @Published var isRefreshing = false
    @Published var errorMessage: String?

    // Alert counts
    var expiredDocs: Int { 0 }
    var criticalDocs: Int { 0 }
    var wornTires: Int { 0 }
    var upcomingMaint: Int { 0 }

    private var cancellables = Set<AnyCancellable>()
    private let wsManager = WebSocketManager.shared

    var groups: [String] {
        Array(Set(vehicles.map { $0.group })).sorted()
    }

    var statusFilterLabel: String {
        if let f = statusFilter {
            switch f {
            case .ignitionOn: return "Kontak Açık"
            case .ignitionOff: return "Kontak Kapalı"
            case .noData: return "Bilgi Yok"
            case .sleeping: return "Cihaz Uykuda"
            }
        }
        return "Tüm Durumlar"
    }

    // Status counts
    var onlineCount: Int { vehicles.filter { $0.status == .ignitionOn }.count }
    var offlineCount: Int { vehicles.filter { $0.status == .ignitionOff }.count }
    var noDataCount: Int { vehicles.filter { $0.status == .noData }.count }
    var sleepingCount: Int { vehicles.filter { $0.status == .sleeping }.count }

    var filteredVehicles: [Vehicle] {
        var result = vehicles
        if let filter = statusFilter {
            result = result.filter { $0.status == filter }
        }
        if let group = groupFilter {
            result = result.filter { $0.group == group }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.plate.lowercased().contains(q) ||
                $0.model.lowercased().contains(q) ||
                $0.driver.lowercased().contains(q)
            }
        }
        return result
    }

    init() {
        subscribeToWebSocket()
        loadVehiclesFromAPI()
    }

    private func subscribeToWebSocket() {
        wsManager.$vehicleList
            .receive(on: DispatchQueue.main)
            .sink { [weak self] list in
                guard let self = self else { return }
                if !list.isEmpty {
                    let currentMap = Dictionary(uniqueKeysWithValues: self.vehicles.map { ($0.id, $0) })
                    self.vehicles = list.map { incoming in
                        if var existing = currentMap[incoming.id] {
                            existing.mergeUpdate(from: incoming)
                            return existing
                        }
                        return incoming
                    }
                    self.errorMessage = nil
                    self.isLoading = false
                }
            }
            .store(in: &cancellables)

        wsManager.eventSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                switch event {
                case .snapshot(let vehicles, _, _):
                    let currentMap = Dictionary(uniqueKeysWithValues: self.vehicles.map { ($0.id, $0) })
                    self.vehicles = vehicles.map { incoming in
                        if var existing = currentMap[incoming.id] {
                            existing.mergeUpdate(from: incoming)
                            return existing
                        }
                        return incoming
                    }
                    self.errorMessage = nil
                    self.isLoading = false
                case .update(let vehicle, _):
                    if let idx = self.vehicles.firstIndex(where: { $0.id == vehicle.id }) {
                        self.vehicles[idx].mergeUpdate(from: vehicle)
                    } else {
                        self.vehicles.append(vehicle)
                    }
                default: break
                }
            }
            .store(in: &cancellables)
    }

    func refresh() async {
        isRefreshing = true
        wsManager.reconnect()
        await loadVehiclesFromAPI()
        isRefreshing = false
    }

    func loadVehiclesFromAPI() {
        Task {
            await loadVehiclesFromAPI()
        }
    }

    private func loadVehiclesFromAPI() async {
        errorMessage = nil
        do {
            let apiVehicles = try await APIService.shared.fetchVehicles()
            let currentMap = Dictionary(uniqueKeysWithValues: vehicles.map { ($0.id, $0) })
            vehicles = apiVehicles.map { apiVehicle in
                if var existing = currentMap[apiVehicle.id] {
                    existing.mergeUpdate(from: apiVehicle)
                    return existing
                }
                return apiVehicle
            }
            errorMessage = nil
            isLoading = false
        } catch {
            if vehicles.isEmpty {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

#Preview {
    VehiclesListView(showSideMenu: .constant(false), selectedPage: Binding.constant(AppPage.vehicles), alarmsSearchText: .constant(""), alarmsAutoOpenCreate: .constant(false), alarmsPrePlate: .constant(""))
        .environmentObject(AuthViewModel())
}
