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
                        VStack(spacing: 14) {
                            // Search & Filter
                            searchAndFilter

                            // Vehicle Table
                            vehicleTable
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                        .padding(.bottom, 20)
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

    // MARK: - Alert Summary Cards
    var alertSummaryCards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                alertCard(icon: "exclamationmark.circle.fill", value: "\(vm.expiredDocs)", label: "Süresi Dolmuş Belge", iconBg: Color.red.opacity(0.1), iconColor: .red)
                alertCard(icon: "exclamationmark.triangle.fill", value: "\(vm.criticalDocs)", label: "Yaklaşan Belge Süresi", iconBg: Color.orange.opacity(0.1), iconColor: .orange)
                alertCard(icon: "circle.circle.fill", value: "\(vm.wornTires)", label: "Lastik Değişimi", iconBg: Color.red.opacity(0.1), iconColor: .red)
                alertCard(icon: "wrench.and.screwdriver.fill", value: "\(vm.upcomingMaint)", label: "30 Gün Bakım", iconBg: Color.blue.opacity(0.1), iconColor: .blue)
            }
        }
    }

    func alertCard(icon: String, value: String, label: String, iconBg: Color, iconColor: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(iconColor)
                .frame(width: 40, height: 40)
                .background(iconBg)
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppTheme.navy)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppTheme.textMuted)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .background(AppTheme.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.borderSoft, lineWidth: 1)
        )
    }

    // MARK: - Search and Filter
    var searchAndFilter: some View {
        VStack(spacing: 10) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.textMuted)
                TextField("Plaka, araç veya sürücü ara...", text: $vm.searchText)
                    .font(.system(size: 13))
                if !vm.searchText.isEmpty {
                    Button(action: { vm.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.textFaint)
                    }
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(AppTheme.surface)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AppTheme.borderSoft, lineWidth: 1.5)
            )

            // Filter row
            HStack(spacing: 8) {
                // Status filter
                Menu {
                    Button("Tüm Durumlar") { vm.statusFilter = nil }
                    Button("Kontak Açık") { vm.statusFilter = .ignitionOn }
                    Button("Kontak Kapalı") { vm.statusFilter = .ignitionOff }
                    Button("Bilgi Yok") { vm.statusFilter = .noData }
                    Button("Cihaz Uykuda") { vm.statusFilter = .sleeping }
                } label: {
                    HStack(spacing: 5) {
                        Text(vm.statusFilterLabel)
                            .font(.system(size: 11, weight: .medium))
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
                            .stroke(AppTheme.borderSoft, lineWidth: 1.5)
                    )
                }

                // Group filter
                Menu {
                    Button("Tüm Gruplar") { vm.groupFilter = nil }
                    ForEach(vm.groups, id: \.self) { group in
                        Button(group) { vm.groupFilter = group }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(vm.groupFilter ?? "Tüm Gruplar")
                            .font(.system(size: 11, weight: .medium))
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
                            .stroke(AppTheme.borderSoft, lineWidth: 1.5)
                    )
                }

                Spacer()

                Text("\(vm.filteredVehicles.count) / \(vm.vehicles.count) araç")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.textMuted)
            }
        }
    }

    // MARK: - Vehicle Table
    var vehicleTable: some View {
        VStack(spacing: 10) {
            ForEach(vm.filteredVehicles) { vehicle in
                Button(action: { selectedVehicle = vehicle }) {
                    vehicleCard(vehicle)
                }
                .buttonStyle(.plain)
            }

            if vm.filteredVehicles.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "car.2.fill")
                        .font(.system(size: 36))
                        .foregroundColor(AppTheme.textFaint.opacity(0.5))
                    Text("Araç bulunamadı")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
    }

    func vehicleCard(_ vehicle: Vehicle) -> some View {
        VStack(spacing: 0) {
            // Top row: Plate + Status badge + Chevron
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(vehicle.status.color)
                        .frame(width: 10, height: 10)
                    Text(vehicle.plate)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppTheme.navy)
                }

                Spacer()

                fleetStatusBadge(vehicle.fleetStatus)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.textFaint)
                    .padding(.leading, 6)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Info grid: Speed, Kontak, KM, Device Time
            HStack(spacing: 0) {
                // Speed
                vehicleInfoItem(
                    icon: "speedometer",
                    label: "Hız",
                    value: vehicle.formattedSpeed,
                    color: vehicle.speed > 0 ? AppTheme.online : AppTheme.textMuted
                )

                dividerVertical

                // Kontak
                vehicleInfoItem(
                    icon: vehicle.kontakOn ? "key.fill" : "key",
                    label: "Kontak",
                    value: vehicle.kontakOn ? "Açık" : "Kapalı",
                    color: vehicle.kontakOn ? AppTheme.online : AppTheme.offline
                )

                dividerVertical

                // Total KM
                vehicleInfoItem(
                    icon: "road.lanes",
                    label: "Toplam Km",
                    value: vehicle.formattedTotalKm,
                    color: AppTheme.navy
                )
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 10)

            // Bottom: Device Time + Temp (if available)
            HStack(spacing: 6) {
                if vehicle.deviceTime != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                            .foregroundColor(AppTheme.textFaint)
                        Text(vehicle.formattedDeviceTime)
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textFaint)
                    }
                }

                if let temp = vehicle.temperatureC {
                    if vehicle.deviceTime != nil {
                        Text("•")
                            .font(.system(size: 8))
                            .foregroundColor(AppTheme.textFaint)
                    }
                    Text(String(format: "🌡️%.1f°C", temp))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(temp < 0 ? .blue : temp < 30 ? AppTheme.online : .red)
                }

                Spacer()

                if !vehicle.driverName.isEmpty || !vehicle.driver.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 9))
                            .foregroundColor(AppTheme.textFaint)
                        Text(!vehicle.driverName.isEmpty ? vehicle.driverName : vehicle.driver)
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textFaint)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(AppTheme.bg.opacity(0.5))
        }
        .background(AppTheme.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.borderSoft, lineWidth: 1)
        )
    }

    func vehicleInfoItem(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(AppTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    var dividerVertical: some View {
        Rectangle()
            .fill(AppTheme.borderSoft)
            .frame(width: 1, height: 36)
    }

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

        // Also listen for individual events
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
