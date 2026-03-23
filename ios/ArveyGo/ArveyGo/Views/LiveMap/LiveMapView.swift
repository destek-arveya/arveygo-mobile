import SwiftUI
import MapKit

struct LiveMapView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = LiveMapViewModel()
    @Binding var showSideMenu: Bool
    @State private var showVehicleList = true
    @State private var selectedVehicle: Vehicle?
    @State private var showVehicleDetail = false
    @State private var detailVehicle: Vehicle?
    @State private var mapCameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 39.9, longitude: 32.8),
            span: MKCoordinateSpan(latitudeDelta: 6, longitudeDelta: 6)
        )
    )

    var body: some View {
        NavigationStack {
                ZStack {
                    // Map
                    mapContent

                    // Top overlay chips
                    VStack {
                        topOverlay
                        Spacer()
                    }

                    // Bottom status filter bar
                    VStack {
                        Spacer()
                        if selectedVehicle == nil {
                            statusFilterBar
                                .padding(.bottom, 8)
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
                            Text("Canlı Harita")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(AppTheme.navy)
                            Text("Araç Takip / Canlı Harita")
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.textMuted)
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        AvatarCircle(
                            initials: authVM.currentUser?.avatar ?? "A",
                            size: 30
                        )
                    }
                }
                .sheet(isPresented: $showVehicleList) {
                    vehicleListSheet
                        .presentationDetents([.fraction(0.12), .fraction(0.35), .fraction(0.75)])
                        .presentationDragIndicator(.visible)
                        .presentationBackgroundInteraction(.enabled)
                        .presentationCornerRadius(20)
                        .interactiveDismissDisabled()
                }
                .sheet(item: $selectedVehicle) { vehicle in
                    vehiclePopupSheet(vehicle)
                        .presentationDetents([.fraction(0.50), .large])
                        .presentationDragIndicator(.visible)
                        .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.50)))
                        .presentationCornerRadius(20)
                }
                .fullScreenCover(item: $detailVehicle) { vehicle in
                    VehicleDetailView(vehicle: vehicle)
                }
            }
    }

    // MARK: - Map Content
    var mapContent: some View {
        Map(position: $mapCameraPosition) {
            ForEach(vm.filteredVehicles) { vehicle in
                Annotation(vehicle.plate, coordinate: CLLocationCoordinate2D(latitude: vehicle.lat, longitude: vehicle.lng)) {
                    Button(action: {
                        selectedVehicle = vehicle
                        withAnimation {
                            mapCameraPosition = .region(MKCoordinateRegion(
                                center: CLLocationCoordinate2D(latitude: vehicle.lat, longitude: vehicle.lng),
                                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                            ))
                        }
                    }) {
                        VehicleMapPin(vehicle: vehicle, isSelected: selectedVehicle?.id == vehicle.id)
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Top Overlay
    var topOverlay: some View {
        HStack(spacing: 6) {
            Spacer()
            // WebSocket status chip
            HStack(spacing: 5) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                Text("Canlı")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppTheme.navy)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .cornerRadius(20)

            // Vehicle count chip
            HStack(spacing: 5) {
                Image(systemName: "car.fill")
                    .font(.system(size: 9))
                Text("\(vm.filteredVehicles.count) Araç")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppTheme.navy)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    // MARK: - Status Filter Bar (more visible)
    var statusFilterBar: some View {
        HStack(spacing: 6) {
            statusFilterPill(label: "Tümü", count: vm.vehicles.count, filter: nil, color: AppTheme.navy)
            statusFilterPill(label: "Aktif", count: vm.onlineCount, filter: .online, color: AppTheme.online)
            statusFilterPill(label: "Rölanti", count: vm.idleCount, filter: .idle, color: AppTheme.idle)
            statusFilterPill(label: "Çevrimdışı", count: vm.offlineCount, filter: .offline, color: AppTheme.offline)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.white.opacity(0.95))
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        )
        .padding(.horizontal, 12)
    }

    func statusFilterPill(label: String, count: Int, filter: VehicleStatus?, color: Color) -> some View {
        let isActive = vm.statusFilter == filter
        return Button(action: { vm.statusFilter = filter }) {
            VStack(spacing: 3) {
                Text("\(count)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isActive ? .white : color)
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(isActive ? .white.opacity(0.9) : AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isActive ? color : color.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? color : color.opacity(0.2), lineWidth: 1.5)
            )
        }
    }

    // MARK: - Vehicle List Sheet
    var vehicleListSheet: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Araçlar")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppTheme.navy)
                    Text("\(vm.filteredVehicles.count) araç listeleniyor")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textMuted)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 10)

            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.textMuted)
                TextField("Plaka veya araç ara...", text: $vm.searchText)
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
            .frame(height: 38)
            .background(AppTheme.bg)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AppTheme.borderSoft, lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 10)

            Divider()

            // Vehicle list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(vm.filteredVehicles) { vehicle in
                        vehicleRow(vehicle)
                    }
                }
            }
        }
    }

    func vehicleRow(_ vehicle: Vehicle) -> some View {
        VStack(spacing: 0) {
            Button(action: {
                selectedVehicle = vehicle
                withAnimation {
                    mapCameraPosition = .region(MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: vehicle.lat, longitude: vehicle.lng),
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    ))
                }
            }) {
                HStack(spacing: 12) {
                    // Status bar
                    RoundedRectangle(cornerRadius: 2)
                        .fill(vehicle.status.color)
                        .frame(width: 3, height: 36)

                    // Vehicle icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(vehicle.status.color.opacity(0.1))
                            .frame(width: 36, height: 36)
                        Image(systemName: "car.fill")
                            .font(.system(size: 14))
                            .foregroundColor(vehicle.status.color)
                    }

                    // Info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(vehicle.plate)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppTheme.navy)
                        Text(vehicle.model)
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textMuted)
                    }

                    Spacer()

                    // Right side
                    VStack(alignment: .trailing, spacing: 2) {
                        if vehicle.status == .online {
                            Text("\(vehicle.todayKm) km/h")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppTheme.navy)
                        }
                        StatusBadge(status: vehicle.status)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(selectedVehicle?.id == vehicle.id ? AppTheme.navy.opacity(0.04) : Color.clear)
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 72)
        }
    }

    // MARK: - Vehicle Popup Sheet (half screen with detail button)
    func vehiclePopupSheet(_ vehicle: Vehicle) -> some View {
        VStack(spacing: 0) {
            // Header with plate & status
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(vehicle.status.color.opacity(0.12))
                        .frame(width: 52, height: 52)
                    Image(systemName: "car.fill")
                        .font(.system(size: 22))
                        .foregroundColor(vehicle.status.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(vehicle.plate)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.navy)
                    HStack(spacing: 6) {
                        Text(vehicle.model)
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.textMuted)
                        Text("•")
                            .foregroundColor(AppTheme.textFaint)
                        Text(vehicle.driver)
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.textMuted)
                    }
                }

                Spacer()

                StatusBadge(status: vehicle.status)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    // Info grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        infoCell(icon: "mappin.circle.fill", label: "Konum", value: vehicle.city, color: .blue)
                        infoCell(icon: "speedometer", label: "Hız", value: vehicle.status == .online ? "\(vehicle.todayKm) km/h" : "0 km/h", color: .orange)
                        infoCell(icon: "road.lanes", label: "Bugün", value: vehicle.formattedTodayKm, color: AppTheme.indigo)
                        infoCell(icon: "key.fill", label: "Kontak", value: vehicle.kontakOn ? "Açık" : "Kapalı", color: vehicle.kontakOn ? AppTheme.online : AppTheme.offline)
                        infoCell(icon: "gauge.open.with.lines.needle.33percent", label: "Toplam Km", value: vehicle.formattedTotalKm + " km", color: AppTheme.navy)
                        infoCell(icon: "antenna.radiowaves.left.and.right", label: "Sinyal", value: vehicle.status == .online ? "Güçlü" : "Yok", color: vehicle.status == .online ? AppTheme.online : AppTheme.textFaint)
                    }
                    .padding(.horizontal, 20)

                    // Quick actions row
                    HStack(spacing: 10) {
                        quickAction(icon: "location.fill", label: "Konuma Git", color: .blue)
                        quickAction(icon: "clock.arrow.circlepath", label: "Rota Geçmişi", color: AppTheme.indigo)
                        quickAction(icon: "bell.fill", label: "Alarm Kur", color: .orange)
                        quickAction(icon: "lock.fill", label: "Blokaj", color: .red)
                    }
                    .padding(.horizontal, 20)

                    // DETAY GÖR Button
                    Button(action: {
                        let v = vehicle
                        selectedVehicle = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            detailVehicle = v
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Detay Gör")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(AppTheme.buttonGradient)
                        .cornerRadius(14)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .padding(.top, 16)
            }
        }
    }

    func infoCell(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.1))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(AppTheme.textFaint)
                    .textCase(.uppercase)
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.navy)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(12)
        .background(AppTheme.bg)
        .cornerRadius(10)
    }

    func quickAction(icon: String, label: String, color: Color) -> some View {
        Button(action: {}) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                    .frame(width: 42, height: 42)
                    .background(color.opacity(0.1))
                    .cornerRadius(12)
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(AppTheme.textMuted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Vehicle Map Pin
struct VehicleMapPin: View {
    let vehicle: Vehicle
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Pin body
                RoundedRectangle(cornerRadius: 8)
                    .fill(vehicle.status.color.opacity(isSelected ? 1.0 : 0.85))
                    .frame(width: isSelected ? 42 : 34, height: isSelected ? 42 : 34)
                    .shadow(color: vehicle.status.color.opacity(0.4), radius: isSelected ? 8 : 4, y: 2)

                Image(systemName: "car.fill")
                    .font(.system(size: isSelected ? 18 : 14, weight: .medium))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(vehicle.status == .online ? -45 : 0))
            }

            // Plate label
            if isSelected {
                Text(vehicle.plate)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppTheme.navy)
                    .cornerRadius(4)
                    .offset(y: 2)
            }

            // Arrow
            Triangle()
                .fill(vehicle.status.color.opacity(isSelected ? 1.0 : 0.85))
                .frame(width: 10, height: 6)
        }
        .animation(.spring(response: 0.25), value: isSelected)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Live Map ViewModel
@MainActor
class LiveMapViewModel: ObservableObject {
    @Published var vehicles: [Vehicle] = []
    @Published var statusFilter: VehicleStatus? = nil
    @Published var searchText = ""

    var onlineCount: Int { vehicles.filter { $0.status == .online }.count }
    var offlineCount: Int { vehicles.filter { $0.status == .offline }.count }
    var idleCount: Int { vehicles.filter { $0.status == .idle }.count }

    var filteredVehicles: [Vehicle] {
        var result = vehicles
        if let filter = statusFilter {
            result = result.filter { $0.status == filter }
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
        loadDummyData()
    }

    func loadDummyData() {
        vehicles = [
            Vehicle(id: "1", plate: "34 ABC 123", model: "Ford Transit", status: .online, kontakOn: true, totalKm: 48320, todayKm: 87, driver: "Ahmet Yılmaz", city: "İstanbul", lat: 41.0082, lng: 28.9784),
            Vehicle(id: "2", plate: "06 XYZ 789", model: "Mercedes Sprinter", status: .offline, kontakOn: false, totalKm: 92100, todayKm: 0, driver: "Mehmet Demir", city: "Ankara", lat: 39.9334, lng: 32.8597),
            Vehicle(id: "3", plate: "35 DEF 456", model: "Renault Master", status: .online, kontakOn: true, totalKm: 31540, todayKm: 62, driver: "Ayşe Kaya", city: "İzmir", lat: 38.4192, lng: 27.1287),
            Vehicle(id: "4", plate: "16 GHI 321", model: "Volkswagen Crafter", status: .idle, kontakOn: false, totalKm: 67890, todayKm: 0, driver: "Can Öztürk", city: "Bursa", lat: 40.1885, lng: 29.0610),
            Vehicle(id: "5", plate: "41 JKL 654", model: "Fiat Ducato", status: .online, kontakOn: true, totalKm: 22430, todayKm: 45, driver: "Zeynep Şahin", city: "Kocaeli", lat: 40.7654, lng: 29.9408),
            Vehicle(id: "6", plate: "07 MNO 987", model: "Peugeot Boxer", status: .offline, kontakOn: false, totalKm: 55670, todayKm: 0, driver: "Ali Çelik", city: "Antalya", lat: 36.8969, lng: 30.7133),
            Vehicle(id: "7", plate: "34 PRS 111", model: "Iveco Daily", status: .online, kontakOn: true, totalKm: 14220, todayKm: 112, driver: "Fatma Arslan", city: "İstanbul", lat: 41.0422, lng: 29.0083),
            Vehicle(id: "8", plate: "06 TUV 222", model: "Ford Transit Custom", status: .idle, kontakOn: false, totalKm: 38900, todayKm: 0, driver: "Hasan Koç", city: "Ankara", lat: 39.9208, lng: 32.8541),
        ]
    }
}

#Preview {
    LiveMapView(showSideMenu: .constant(false))
        .environmentObject(AuthViewModel())
}
