import SwiftUI
import Combine

struct VehiclesListView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = VehiclesListViewModel()
    @Binding var showSideMenu: Bool
    @Binding var selectedPage: AppPage
    @Binding var alarmsSearchText: String
    @State private var selectedVehicle: Vehicle?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.bg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
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
                        Text("Araçlarım")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.navy)
                        Text("Filo Yönetimi / Araçlar")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textMuted)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button(action: {}) {
                            Image(systemName: "bell")
                                .font(.system(size: 16))
                                .foregroundColor(AppTheme.textMuted)
                                .overlay(
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 7, height: 7)
                                        .offset(x: 6, y: -6)
                                )
                        }
                        AvatarCircle(
                            initials: authVM.currentUser?.avatar ?? "A",
                            size: 30
                        )
                    }
                }
            }
            .fullScreenCover(item: $selectedVehicle) { vehicle in
                VehicleDetailView(
                    vehicle: vehicle,
                    onNavigateToRouteHistory: { v in
                        selectedVehicle = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            selectedPage = .routeHistory
                        }
                    },
                    onNavigateToAlarms: { plateText in
                        selectedVehicle = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            alarmsSearchText = plateText
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
                    .foregroundColor(isSelected ? color : AppTheme.textSecondary)
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isSelected ? color : AppTheme.textMuted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isSelected ? color.opacity(0.15) : AppTheme.bg)
                    )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? color.opacity(0.12) : AppTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? color.opacity(0.3) : AppTheme.borderSoft, lineWidth: 1)
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
                    .foregroundColor(AppTheme.textMuted)
                TextField("Plaka, araç veya sürücü ara...", text: $vm.searchText)
                    .font(.system(size: 14))
                if !vm.searchText.isEmpty {
                    Button(action: { vm.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.textFaint)
                    }
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(AppTheme.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.borderSoft, lineWidth: 1)
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
                            .foregroundColor(AppTheme.textMuted)
                        Text(vm.groupFilter ?? "Tüm Gruplar")
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundColor(AppTheme.navy)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.surface)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppTheme.borderSoft, lineWidth: 1)
                    )
                }

                Spacer()

                Text("\(vm.filteredVehicles.count) araç listeleniyor")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.textMuted)
            }
        }
    }

    // MARK: - Vehicle Cards
    var vehicleCards: some View {
        VStack(spacing: 12) {
            ForEach(vm.filteredVehicles) { vehicle in
                Button(action: { selectedVehicle = vehicle }) {
                    vehicleCard(vehicle)
                }
                .buttonStyle(.plain)
            }

            if vm.filteredVehicles.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "car.2.fill")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.textFaint.opacity(0.4))
                    Text("Araç bulunamadı")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppTheme.textMuted)
                    Text("Filtre veya arama kriterlerinizi değiştirin")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textFaint)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            }
        }
    }

    // MARK: - Vehicle Card
    func vehicleCard(_ vehicle: Vehicle) -> some View {
        VStack(spacing: 0) {
            // ── Header: Status + Plate + Type + Fleet Badge + Chevron ──
            HStack(spacing: 10) {
                // Status indicator
                Circle()
                    .fill(vehicle.status.color)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(vehicle.status.color.opacity(0.3), lineWidth: 2)
                            .frame(width: 16, height: 16)
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(vehicle.plate)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(AppTheme.navy)

                    if !vehicle.vehicleType.isEmpty && vehicle.vehicleType != "Ticari" {
                        Text(vehicle.vehicleType)
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textMuted)
                            .lineLimit(1)
                    }
                }

                Spacer()

                fleetStatusBadge(vehicle.fleetStatus)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.textFaint)
                    .padding(.leading, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            // ── Stats Grid: 4 columns ──
            HStack(spacing: 0) {
                compactStatItem(
                    icon: "speedometer",
                    value: vehicle.formattedSpeed,
                    label: "Hız",
                    color: vehicle.speed > 0 ? AppTheme.online : AppTheme.textMuted
                )
                compactStatItem(
                    icon: "calendar",
                    value: vehicle.formattedTodayKm,
                    label: "Bugün",
                    color: AppTheme.indigo
                )
                compactStatItem(
                    icon: "road.lanes",
                    value: vehicle.formattedTotalKm,
                    label: "Toplam",
                    color: AppTheme.navy
                )
                compactStatItem(
                    icon: vehicle.kontakOn ? "key.fill" : "key",
                    value: vehicle.kontakOn ? "Açık" : "Kapalı",
                    label: "Kontak",
                    color: vehicle.kontakOn ? AppTheme.online : AppTheme.offline
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppTheme.bg.opacity(0.7))
            .cornerRadius(12)
            .padding(.horizontal, 12)

            Spacer().frame(height: 8)

            // ── Location row (if available) ──
            if !vehicle.locationDisplay.isEmpty && vehicle.locationDisplay != "—" {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.indigo.opacity(0.6))
                    Text(vehicle.locationDisplay)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }

            // ── Footer: Time + Temp/Humidity + Driver ──
            HStack(spacing: 0) {
                // Device time
                if vehicle.deviceTime != nil {
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textFaint)
                        Text(vehicle.formattedDeviceTime)
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textFaint)
                    }
                }

                // Temperature
                if let temp = vehicle.temperatureC {
                    if vehicle.deviceTime != nil {
                        HStack(spacing: 0) {
                            Spacer().frame(width: 8)
                            Circle()
                                .fill(AppTheme.borderSoft)
                                .frame(width: 3, height: 3)
                            Spacer().frame(width: 8)
                        }
                    }
                    Text(String(format: "🌡️%.1f°C", temp))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(temp < 0 ? .blue : temp < 30 ? AppTheme.online : .red)
                }

                // Humidity
                if let hum = vehicle.humidityPct {
                    Spacer().frame(width: 6)
                    Text(String(format: "💧%.0f%%", hum))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppTheme.indigo)
                }

                Spacer()

                // Driver
                let driverText = !vehicle.driverName.isEmpty ? vehicle.driverName : vehicle.driver
                if !driverText.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textFaint)
                        Text(driverText)
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textMuted)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: 120, alignment: .trailing)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(AppTheme.bg.opacity(0.4))
        }
        .background(AppTheme.surface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.borderSoft, lineWidth: 1)
        )
    }

    // MARK: - Compact Stat Item
    func compactStatItem(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 7)
                .fill(color.opacity(0.1))
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundColor(color)
                )

            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.system(size: 9))
                .foregroundColor(AppTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Fleet Status Badge
    func fleetStatusBadge(_ status: FleetVehicleStatus) -> some View {
        Text(status.label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(status.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.1))
            .cornerRadius(20)
    }
}

// MARK: - Fleet Vehicle Status (for vehicles list page)
enum FleetVehicleStatus: String {
    case active, passive, maintenance

    var label: String {
        switch self {
        case .active: return "Aktif"
        case .passive: return "Pasif"
        case .maintenance: return "Bakımda"
        }
    }

    var color: Color {
        switch self {
        case .active: return AppTheme.online
        case .passive: return Color(red: 148/255, green: 163/255, blue: 184/255)
        case .maintenance: return AppTheme.idle
        }
    }
}

// MARK: - Vehicle Extensions for Fleet
extension Vehicle {
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
}

// MARK: - Vehicles List ViewModel
@MainActor
class VehiclesListViewModel: ObservableObject {
    @Published var vehicles: [Vehicle] = []
    @Published var searchText = ""
    @Published var statusFilter: VehicleStatus? = nil
    @Published var groupFilter: String? = nil

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
    }

    private func subscribeToWebSocket() {
        wsManager.$vehicleList
            .receive(on: DispatchQueue.main)
            .sink { [weak self] list in
                guard let self = self else { return }
                if !list.isEmpty {
                    self.vehicles = list
                }
            }
            .store(in: &cancellables)

        wsManager.eventSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                switch event {
                case .snapshot(let vehicles, _, _):
                    self.vehicles = vehicles
                case .update(let vehicle, _):
                    if let idx = self.vehicles.firstIndex(where: { $0.id == vehicle.id }) {
                        self.vehicles[idx] = vehicle
                    } else {
                        self.vehicles.append(vehicle)
                    }
                default: break
                }
            }
            .store(in: &cancellables)
    }
}

#Preview {
    VehiclesListView(showSideMenu: .constant(false), selectedPage: Binding.constant(AppPage.vehicles), alarmsSearchText: .constant(""))
        .environmentObject(AuthViewModel())
}
