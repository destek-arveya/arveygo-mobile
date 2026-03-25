import SwiftUI
import MapKit
import Combine

struct RouteHistoryView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Binding var showSideMenu: Bool
    @State private var selectedVehicle: Vehicle?
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var isPlaying = false
    @State private var playbackProgress: Double = 0.0
    @State private var selectedRouteIndex: Int? = nil
    @State private var showVehiclePicker = false
    @State private var vehicleSearchText = ""
    @StateObject private var vm = RouteHistoryViewModel()
    @State private var mapCameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 40.136, longitude: 26.408),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Selector bar (vehicle + date range)
                    selectorBar

                    // Map area
                    mapArea

                    // Bottom panel
                    bottomPanel
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
                        Text("Rota Geçmişi")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.navy)
                        Text("Araç Takip / Rota Geçmişi")
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
            .sheet(isPresented: $showVehiclePicker) {
                vehiclePickerSheet
                    .presentationDetents([.fraction(0.55), .large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(20)
            }
            .onAppear {
                // Auto-select first vehicle and load routes when vehicles arrive from WS
                if selectedVehicle == nil, let first = vm.vehicles.first {
                    selectedVehicle = first
                    vm.selectVehicle(first)
                    vm.loadRoutes(from: startDate, to: endDate)
                }
            }
            .onChange(of: vm.vehicles) { _, vehicles in
                // When WS vehicles first arrive, auto-select and load
                if selectedVehicle == nil, let first = vehicles.first {
                    selectedVehicle = first
                    vm.selectVehicle(first)
                    vm.loadRoutes(from: startDate, to: endDate)
                }
            }
            .onChange(of: vm.selectedRoute?.id) { _, _ in
                zoomToSelectedRoute()
            }
            .onChange(of: vm.routes.count) { _, _ in
                zoomToSelectedRoute()
            }
        }
    }

    private func zoomToSelectedRoute() {
        guard let route = vm.selectedRoute, !route.points.isEmpty else { return }
        let lats = route.points.map { $0.lat }
        let lngs = route.points.map { $0.lng }
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLng = lngs.min(), let maxLng = lngs.max() else { return }
        let centerLat = (minLat + maxLat) / 2.0
        let centerLng = (minLng + maxLng) / 2.0
        let spanLat = max((maxLat - minLat) * 2.0, 0.005)
        let spanLng = max((maxLng - minLng) * 2.0, 0.005)
        withAnimation(.easeInOut(duration: 0.6)) {
            mapCameraPosition = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng),
                span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLng)
            ))
        }
    }

    // MARK: - Selector Bar
    var selectorBar: some View {
        VStack(spacing: 8) {
            // Vehicle selector
            Button(action: { showVehiclePicker = true }) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill((selectedVehicle?.status.color ?? AppTheme.textFaint).opacity(0.12))
                            .frame(width: 34, height: 34)
                        Image(systemName: "car.fill")
                            .font(.system(size: 14))
                            .foregroundColor(selectedVehicle?.status.color ?? AppTheme.textFaint)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(selectedVehicle?.plate ?? "Araç Seçin")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppTheme.navy)
                        if let v = selectedVehicle {
                            Text("\(v.model) • \(v.driver)")
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.textMuted)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.textMuted)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppTheme.surface)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.borderSoft, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // Date range selector
            HStack(spacing: 8) {
                // Start date
                VStack(alignment: .leading, spacing: 2) {
                    Text("Başlangıç")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(AppTheme.textFaint)
                        .textCase(.uppercase)
                    DatePicker("", selection: $startDate, in: ...endDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(AppTheme.indigo)
                        .scaleEffect(0.85, anchor: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppTheme.surface)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppTheme.borderSoft, lineWidth: 1)
                )

                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.textFaint)

                // End date
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bitiş")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(AppTheme.textFaint)
                        .textCase(.uppercase)
                    DatePicker("", selection: $endDate, in: startDate...Date(), displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(AppTheme.indigo)
                        .scaleEffect(0.85, anchor: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppTheme.surface)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppTheme.borderSoft, lineWidth: 1)
                )

                // Apply button
                Button(action: {
                    vm.loadRoutes(from: startDate, to: endDate)
                }) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(AppTheme.buttonGradient)
                        .cornerRadius(10)
                }
            }

            // Date range summary
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.indigo)
                Text(dateRangeSummary)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.textMuted)
                Spacer()
                Text("\(vm.routes.count) sefer")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppTheme.indigo)
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppTheme.surface)
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }

    var dateRangeSummary: String {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: startDate), to: cal.startOfDay(for: endDate)).day ?? 0
        if days == 0 {
            return "Bugün"
        } else if days == 1 {
            return "Son 1 gün"
        } else {
            return "\(days) günlük aralık"
        }
    }

    // MARK: - Vehicle Picker Sheet
    var vehiclePickerSheet: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Araç Seçin")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(AppTheme.navy)
                Spacer()
                Button(action: { showVehiclePicker = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(AppTheme.textFaint)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.textMuted)
                TextField("Plaka ile ara...", text: $vehicleSearchText)
                    .font(.system(size: 14))
                    .autocapitalization(.allCharacters)
                if !vehicleSearchText.isEmpty {
                    Button(action: { vehicleSearchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(AppTheme.textFaint)
                    }
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background(AppTheme.bg)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.borderSoft, lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 10)

            Divider()

            // Vehicle list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredPickerVehicles) { vehicle in
                        Button(action: {
                            selectedVehicle = vehicle
                            vm.selectVehicle(vehicle)
                            vm.loadRoutes(from: startDate, to: endDate)
                            showVehiclePicker = false
                            vehicleSearchText = ""
                        }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(vehicle.status.color.opacity(0.1))
                                        .frame(width: 38, height: 38)
                                    Image(systemName: "car.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(vehicle.status.color)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(vehicle.plate)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(AppTheme.navy)
                                    Text("\(vehicle.model) • \(vehicle.driver)")
                                        .font(.system(size: 11))
                                        .foregroundColor(AppTheme.textMuted)
                                        .lineLimit(1)
                                }

                                Spacer()

                                if selectedVehicle?.id == vehicle.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(AppTheme.indigo)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(selectedVehicle?.id == vehicle.id ? AppTheme.indigo.opacity(0.04) : Color.clear)
                        }
                        .buttonStyle(.plain)

                        Divider().padding(.leading, 72)
                    }

                    if filteredPickerVehicles.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 28))
                                .foregroundColor(AppTheme.textFaint)
                            Text("'\(vehicleSearchText)' için sonuç bulunamadı")
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.textMuted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                    }
                }
            }
        }
    }

    var filteredPickerVehicles: [Vehicle] {
        if vehicleSearchText.isEmpty { return vm.vehicles }
        let q = vehicleSearchText.lowercased()
        return vm.vehicles.filter {
            $0.plate.lowercased().contains(q) ||
            $0.model.lowercased().contains(q) ||
            $0.driver.lowercased().contains(q)
        }
    }

    // MARK: - Map Area
    var mapArea: some View {
        ZStack {
            Map(position: $mapCameraPosition) {
                // All routes polylines
                ForEach(vm.routes) { route in
                    let isSelected = vm.selectedRoute?.id == route.id
                    MapPolyline(coordinates: route.points.map {
                        CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
                    })
                    .stroke(isSelected ? AppTheme.indigo : AppTheme.lavender.opacity(0.6), lineWidth: isSelected ? 4 : 2)
                }

                // Start/End markers for selected route
                if let route = vm.selectedRoute {
                    if let first = route.points.first {
                        Annotation("Başlangıç", coordinate: CLLocationCoordinate2D(latitude: first.lat, longitude: first.lng)) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.online)
                                    .frame(width: 24, height: 24)
                                Image(systemName: "flag.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white)
                            }
                        }
                    }

                    if let last = route.points.last {
                        Annotation("Bitiş", coordinate: CLLocationCoordinate2D(latitude: last.lat, longitude: last.lng)) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.offline)
                                    .frame(width: 24, height: 24)
                                Image(systemName: "flag.checkered")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat))

            // Playback controls overlay (if route selected)
            if vm.selectedRoute != nil {
                VStack {
                    Spacer()
                    playbackBar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
            }
        }
        .frame(height: UIScreen.main.bounds.height * 0.30)
    }

    // MARK: - Playback Bar
    var playbackBar: some View {
        HStack(spacing: 12) {
            Button(action: { isPlaying.toggle() }) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.indigo)
                    .cornerRadius(18)
            }

            VStack(spacing: 4) {
                Slider(value: $playbackProgress, in: 0...1)
                    .tint(AppTheme.indigo)

                HStack {
                    Text(vm.selectedRoute?.startTime ?? "—")
                        .font(.system(size: 9))
                        .foregroundColor(AppTheme.textMuted)
                    Spacer()
                    Text(vm.selectedRoute?.endTime ?? "—")
                        .font(.system(size: 9))
                        .foregroundColor(AppTheme.textMuted)
                }
            }

            // Speed selector
            Menu {
                Button("1x") {}
                Button("2x") {}
                Button("4x") {}
                Button("8x") {}
            } label: {
                Text("1x")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppTheme.navy)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial)
                    .cornerRadius(18)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }

    // MARK: - Bottom Panel
    var bottomPanel: some View {
        VStack(spacing: 0) {
            // Route summary bar
            if let route = vm.selectedRoute {
                routeSummary(route)
            }

            Divider()

            // Route list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(vm.routes.enumerated()), id: \.element.id) { index, route in
                        routeRow(route, index: index)
                    }

                    if vm.routes.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "road.lanes")
                                .font(.system(size: 36))
                                .foregroundColor(AppTheme.textFaint.opacity(0.5))
                            Text("Seçilen tarih aralığında rota bulunamadı")
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.textMuted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
            }
        }
        .background(AppTheme.surface)
    }

    // MARK: - Route Summary
    func routeSummary(_ route: RouteTrip) -> some View {
        HStack(spacing: 0) {
            summaryItem(icon: "road.lanes", value: route.distance, label: "Mesafe", color: AppTheme.navy)
            Divider().frame(height: 30)
            summaryItem(icon: "clock.fill", value: route.duration, label: "Süre", color: AppTheme.indigo)
            Divider().frame(height: 30)
            summaryItem(icon: "speedometer", value: route.maxSpeed, label: "Max Hız", color: .orange)
            Divider().frame(height: 30)
            summaryItem(icon: "fuelpump.fill", value: route.fuelUsed, label: "Yakıt", color: .cyan)
        }
        .padding(.vertical, 12)
        .background(AppTheme.bg)
    }

    func summaryItem(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(AppTheme.navy)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(AppTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Route Row
    func routeRow(_ route: RouteTrip, index: Int) -> some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation { selectedRouteIndex = index }
                vm.selectRoute(route)
            }) {
                HStack(spacing: 12) {
                    // Timeline
                    VStack(spacing: 2) {
                        Circle()
                            .fill(AppTheme.online)
                            .frame(width: 10, height: 10)
                        Rectangle()
                            .fill(AppTheme.borderSoft)
                            .frame(width: 2, height: 24)
                        Circle()
                            .fill(AppTheme.offline)
                            .frame(width: 10, height: 10)
                    }

                    // Route info
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            if !route.dateLabel.isEmpty {
                                Text(route.dateLabel)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(AppTheme.indigo)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(AppTheme.indigo.opacity(0.08))
                                    .cornerRadius(4)
                            }
                            Text(route.startTime)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppTheme.navy)
                            Text("→")
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.textFaint)
                            Text(route.endTime)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppTheme.navy)
                        }

                        Text(route.startAddress)
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textMuted)
                            .lineLimit(1)

                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Image(systemName: "road.lanes")
                                    .font(.system(size: 9))
                                Text(route.distance)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(AppTheme.textMuted)

                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 9))
                                Text(route.duration)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(AppTheme.textMuted)

                            HStack(spacing: 4) {
                                Image(systemName: "speedometer")
                                    .font(.system(size: 9))
                                Text(route.maxSpeed)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(AppTheme.textMuted)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppTheme.textFaint)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(selectedRouteIndex == index ? AppTheme.indigo.opacity(0.04) : Color.clear)
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 40)
        }
    }
}

// MARK: - Route Models
struct RoutePoint: Identifiable {
    let id = UUID()
    let lat: Double
    let lng: Double
    let speed: Int
    let time: String
}

struct RouteTrip: Identifiable {
    let id: String
    let dateLabel: String
    let startTime: String
    let endTime: String
    let startAddress: String
    let endAddress: String
    let distance: String
    let duration: String
    let maxSpeed: String
    let avgSpeed: String
    let fuelUsed: String
    let points: [RoutePoint]
}

// MARK: - Route History ViewModel
@MainActor
class RouteHistoryViewModel: ObservableObject {
    @Published var vehicles: [Vehicle] = []
    @Published var routes: [RouteTrip] = []
    @Published var selectedRoute: RouteTrip?
    @Published var selectedVehicleId: String?
    @Published var isLoadingVehicles = false
    @Published var isLoadingRoutes = false
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()
    private let wsManager = WebSocketManager.shared

    init() {
        subscribeToWebSocket()
    }

    // MARK: - Get vehicles from WebSocket (real data)
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
    }

    func selectVehicle(_ vehicle: Vehicle) {
        selectedVehicleId = vehicle.id
    }

    func selectRoute(_ route: RouteTrip) {
        selectedRoute = route
    }

    // MARK: - IMEI → device_id mapping cache
    private var imeiToDeviceId: [String: Int] = [:]

    /// Resolve the backend device_id for a given IMEI via /api/mobile/route-history/vehicles
    private func resolveDeviceId(for imei: String) async throws -> Int {
        if let cached = imeiToDeviceId[imei] { return cached }

        let json = try await APIService.shared.get("/api/mobile/route-history/vehicles")
        if let data = json["data"] as? [[String: Any]] {
            for v in data {
                let vImei = v["imei"] as? String ?? ""
                let vId = v["id"] as? Int ?? v["deviceId"] as? Int ?? 0
                if !vImei.isEmpty && vId > 0 {
                    imeiToDeviceId[vImei] = vId
                }
            }
        }
        guard let deviceId = imeiToDeviceId[imei], deviceId > 0 else {
            throw NSError(domain: "RouteHistory", code: 404, userInfo: [NSLocalizedDescriptionKey: "Araç bulunamadı (IMEI: \(imei))"])
        }
        return deviceId
    }

    // MARK: - Load routes from API
    func loadRoutes(from startDate: Date, to endDate: Date) {
        guard let vehicleId = selectedVehicleId else { return }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let startStr = dateFormatter.string(from: startDate)
        let endStr = dateFormatter.string(from: endDate)

        isLoadingRoutes = true
        errorMessage = nil

        Task {
            do {
                // Resolve IMEI to backend device_id
                let deviceId = try await resolveDeviceId(for: vehicleId)

                let json = try await APIService.shared.get(
                    "/api/mobile/route-history/\(deviceId)/trips?started_at=\(startStr)&ended_at=\(endStr)&per_page=4"
                )

                let tripsArray = json["trips"] as? [[String: Any]] ?? json["data"] as? [[String: Any]] ?? []

                var parsedRoutes: [RouteTrip] = []

                for tripJson in tripsArray {
                    let tripNo = tripJson["tripNo"] as? Int ?? tripJson["trip_no"] as? Int ?? tripJson["id"] as? Int ?? 0
                    let startTime = tripJson["startTime"] as? String ?? tripJson["started_at"] as? String ?? ""
                    let endTime = tripJson["endTime"] as? String ?? tripJson["ended_at"] as? String ?? ""

                    // Distance comes in meters from API
                    let distanceM = (tripJson["distance"] as? Double) ?? Double(tripJson["distance"] as? Int ?? 0)
                    let distanceKm = distanceM / 1000.0
                    let distanceStr = distanceKm < 1.0 ? String(format: "%.0f m", distanceM) : String(format: "%.1f km", distanceKm)

                    // Duration comes in seconds
                    let durationSec = (tripJson["duration"] as? Int) ?? Int((tripJson["duration"] as? Double) ?? 0)
                    let dMin = durationSec / 60
                    let dSec = durationSec % 60
                    let durationStr = dMin > 0 ? "\(dMin)dk \(dSec)sn" : "\(dSec)sn"

                    let maxSpeedVal = (tripJson["maxSpeed"] as? Int) ?? (tripJson["max_speed"] as? Int) ?? 0
                    let avgSpeedVal = (tripJson["avgSpeed"] as? Int) ?? (tripJson["avg_speed"] as? Int) ?? 0

                    // Parse time for display
                    let displayStart = Self.formatTimeOnly(startTime)
                    let displayEnd = Self.formatTimeOnly(endTime)
                    let dateLabel = Self.formatDateLabel(startTime)

                    // Parse coords from startCoord/endCoord (used for start/end markers)
                    var points: [RoutePoint] = []

                    // Try inline coords array [[lat, lng, alt], ...]
                    if let coordsArray = tripJson["coords"] as? [[Any]], !coordsArray.isEmpty {
                        for coord in coordsArray {
                            if coord.count >= 2, let lat = coord[0] as? Double, let lng = coord[1] as? Double {
                                points.append(RoutePoint(lat: lat, lng: lng, speed: 0, time: ""))
                            }
                        }
                    }

                    // If no inline coords, fetch playbackPoints from points endpoint
                    if points.isEmpty {
                        do {
                            let pointsJson = try await APIService.shared.get(
                                "/api/mobile/route-history/\(deviceId)/trips/\(tripNo)/points?started_at=\(startStr)&ended_at=\(endStr)"
                            )
                            // playbackPoints has full data with lat, lng, speed, time
                            if let pbPoints = pointsJson["playbackPoints"] as? [[String: Any]], !pbPoints.isEmpty {
                                for pt in pbPoints {
                                    let lat = (pt["lat"] as? Double) ?? 0
                                    let lng = (pt["lng"] as? Double) ?? 0
                                    let spd = (pt["speed"] as? Int) ?? Int((pt["speed"] as? Double) ?? 0)
                                    let time = (pt["time"] as? String) ?? ""
                                    points.append(RoutePoint(lat: lat, lng: lng, speed: spd, time: Self.formatTimeOnly(time)))
                                }
                            }
                            // Fallback to routeCoords [[lat, lng, alt], ...]
                            else if let routeCoords = pointsJson["routeCoords"] as? [[Any]], !routeCoords.isEmpty {
                                for coord in routeCoords {
                                    if coord.count >= 2, let lat = coord[0] as? Double, let lng = coord[1] as? Double {
                                        points.append(RoutePoint(lat: lat, lng: lng, speed: 0, time: ""))
                                    }
                                }
                            }
                        } catch {
                            print("[RouteHistory] Failed to load points for trip \(tripNo): \(error)")
                        }
                    }

                    // If still no points, use startCoord/endCoord as fallback
                    if points.isEmpty {
                        if let sc = tripJson["startCoord"] as? [Any], sc.count >= 2,
                           let lat = sc[0] as? Double, let lng = sc[1] as? Double {
                            points.append(RoutePoint(lat: lat, lng: lng, speed: 0, time: displayStart))
                        }
                        if let ec = tripJson["endCoord"] as? [Any], ec.count >= 2,
                           let lat = ec[0] as? Double, let lng = ec[1] as? Double {
                            points.append(RoutePoint(lat: lat, lng: lng, speed: 0, time: displayEnd))
                        }
                    }

                    parsedRoutes.append(RouteTrip(
                        id: "trip\(tripNo)",
                        dateLabel: dateLabel,
                        startTime: displayStart,
                        endTime: displayEnd,
                        startAddress: tripJson["startTimeLabel"] as? String ?? displayStart,
                        endAddress: tripJson["endTimeLabel"] as? String ?? displayEnd,
                        distance: distanceStr,
                        duration: durationStr,
                        maxSpeed: "\(maxSpeedVal) km/h",
                        avgSpeed: "\(avgSpeedVal) km/h",
                        fuelUsed: "—",
                        points: points
                    ))
                }

                self.routes = parsedRoutes
                self.isLoadingRoutes = false

                if let first = parsedRoutes.first {
                    self.selectedRoute = first
                } else {
                    self.selectedRoute = nil
                }
            } catch {
                self.isLoadingRoutes = false
                self.errorMessage = error.localizedDescription
                self.routes = []
                self.selectedRoute = nil
                print("[RouteHistory] API error: \(error)")
            }
        }
    }

    // MARK: - Helpers
    private static func formatTimeOnly(_ iso: String) -> String {
        guard !iso.isEmpty else { return "—" }
        let cleaned = iso.replacingOccurrences(of: "\\.\\d+", with: "", options: .regularExpression)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: cleaned) {
            let out = DateFormatter()
            out.dateFormat = "HH:mm"
            out.timeZone = TimeZone(identifier: "Europe/Istanbul")
            return out.string(from: date)
        }
        // Fallback: extract HH:mm from string
        if let range = iso.range(of: "\\d{2}:\\d{2}", options: .regularExpression) {
            return String(iso[range])
        }
        return iso
    }

    private static func formatDateLabel(_ iso: String) -> String {
        guard !iso.isEmpty else { return "" }
        let cleaned = iso.replacingOccurrences(of: "\\.\\d+", with: "", options: .regularExpression)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: cleaned) {
            let cal = Calendar.current
            let now = Date()
            if cal.isDateInToday(date) { return "Bugün" }
            if cal.isDateInYesterday(date) { return "Dün" }
            let out = DateFormatter()
            out.dateFormat = "dd.MM"
            out.timeZone = TimeZone(identifier: "Europe/Istanbul")
            return out.string(from: date)
        }
        return ""
    }
}

#Preview {
    RouteHistoryView(showSideMenu: .constant(false))
        .environmentObject(AuthViewModel())
}
