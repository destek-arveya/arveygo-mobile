import SwiftUI
import MapKit
import Combine

struct LiveMapView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = LiveMapViewModel()
    @Binding var showSideMenu: Bool
    @State private var selectedVehicle: Vehicle?
    @State private var showVehicleDetail = false
    @State private var detailVehicle: Vehicle?
    @State private var hasFittedBounds = false
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

                    // (filter bar moved to top overlay)
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
                .onAppear {
                    // Connect WebSocket when map appears
                    authVM.connectWebSocket()
                    // If WS fails to deliver data, fall back to dummy
                    vm.loadDummyDataIfNeeded()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    // Reconnect when app returns to foreground
                    WebSocketManager.shared.reconnect()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    // Optionally disconnect in background to save battery
                    // WebSocketManager.shared.disconnect()
                }
                .onChange(of: vm.vehicles) { _, vehicles in
                    fitBoundsIfNeeded(vehicles: vehicles)
                }
            }
    }

    /// Fit map camera to show all vehicles on first load
    private func fitBoundsIfNeeded(vehicles: [Vehicle]) {
        guard !hasFittedBounds, !vehicles.isEmpty else { return }
        hasFittedBounds = true

        let lats = vehicles.map { $0.lat }
        let lngs = vehicles.map { $0.lng }

        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLng = lngs.min(), let maxLng = lngs.max() else { return }

        let centerLat = (minLat + maxLat) / 2.0
        let centerLng = (minLng + maxLng) / 2.0
        let spanLat = max((maxLat - minLat) * 1.3, 0.05)
        let spanLng = max((maxLng - minLng) * 1.3, 0.05)

        withAnimation(.easeInOut(duration: 0.8)) {
            mapCameraPosition = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng),
                span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLng)
            ))
        }
    }

    // MARK: - Map Content
    var mapContent: some View {
        Map(position: $mapCameraPosition) {
            ForEach(vm.filteredVehicles) { vehicle in
                // Use animated coordinates for smooth movement
                let coord = vm.animatedCoordinate(for: vehicle)
                Annotation("", coordinate: coord) {
                    Button(action: {
                        selectedVehicle = vehicle
                        withAnimation {
                            mapCameraPosition = .region(MKCoordinateRegion(
                                center: CLLocationCoordinate2D(latitude: vehicle.lat, longitude: vehicle.lng),
                                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                            ))
                        }
                    }) {
                        VehicleMapPin(vehicle: vehicle, isSelected: selectedVehicle?.id == vehicle.id, animatedDirection: vm.animatedDirection(for: vehicle))
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Top Overlay (filter chips + WS status)
    var topOverlay: some View {
        VStack(spacing: 6) {
            // Filter chips row (like Android)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    statusChip(label: "Tümü", count: vm.vehicles.count, filter: nil, color: AppTheme.navy)
                    statusChip(label: "Aktif", count: vm.onlineCount, filter: .online, color: AppTheme.online)
                    statusChip(label: "Çevrimdışı", count: vm.offlineCount, filter: .offline, color: AppTheme.offline)
                    statusChip(label: "Rölanti", count: vm.idleCount, filter: .idle, color: AppTheme.idle)
                    
                    Spacer()
                    
                    // WebSocket status chip
                    HStack(spacing: 5) {
                        Circle()
                            .fill(wsStatusColor)
                            .frame(width: 6, height: 6)
                        Text(vm.wsStatus.label)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(wsStatusColor)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(wsStatusColor.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(wsStatusColor.opacity(0.3), lineWidth: 1)
                    )
                    .onTapGesture {
                        if case .error = vm.wsStatus {
                            authVM.connectWebSocket()
                        } else if vm.wsStatus == .disconnected || vm.wsStatus == .idle {
                            authVM.connectWebSocket()
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
        }
        .padding(.top, 4)
    }
    
    func statusChip(label: String, count: Int, filter: VehicleStatus?, color: Color) -> some View {
        let isActive = vm.statusFilter == filter
        return Button(action: { vm.statusFilter = filter }) {
            Text("\(label) (\(count))")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(isActive ? color : AppTheme.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(isActive ? color.opacity(0.15) : Color.white.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isActive ? color : AppTheme.borderSoft, lineWidth: 1)
        )
    }

    private var wsStatusColor: Color {
        switch vm.wsStatus {
        case .connected:    return .green
        case .connecting, .reconnecting: return .orange
        case .error:        return .red
        default:            return .gray
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
                        infoCell(icon: "speedometer", label: "Hız", value: vehicle.formattedSpeed, color: .orange)
                        infoCell(icon: "road.lanes", label: "Bugün", value: vehicle.formattedTodayKm, color: AppTheme.indigo)
                        infoCell(icon: "key.fill", label: "Kontak", value: vehicle.kontakOn ? "Açık" : "Kapalı", color: vehicle.kontakOn ? AppTheme.online : AppTheme.offline)
                        infoCell(icon: "gauge.open.with.lines.needle.33percent", label: "Toplam Km", value: vehicle.formattedTotalKm + " km", color: AppTheme.navy)
                        infoCell(icon: "antenna.radiowaves.left.and.right", label: "Sinyal", value: vehicle.status == .online ? "Güçlü" : "Yok", color: vehicle.status == .online ? AppTheme.online : AppTheme.textFaint)
                    }
                    .padding(.horizontal, 20)

                    // Temperature row (if available)
                    if let temp = vehicle.temperatureC {
                        HStack(spacing: 10) {
                            infoCell(icon: "thermometer.medium", label: "Sıcaklık", value: String(format: "%.1f°C", temp), color: temp < 0 ? .blue : temp < 30 ? AppTheme.online : .red)
                            if let hum = vehicle.humidityPct {
                                infoCell(icon: "humidity.fill", label: "Nem", value: "%\(Int(hum))", color: Color(red: 0.05, green: 0.65, blue: 0.88))
                            } else {
                                Spacer().frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal, 20)
                    }

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

// MARK: - Vehicle Map Pin (circle + direction arrow, like Android)
struct VehicleMapPin: View {
    let vehicle: Vehicle
    let isSelected: Bool
    var animatedDirection: Double = 0

    private var pinSize: CGFloat { isSelected ? 44 : 36 }

    var body: some View {
        VStack(spacing: 2) {
            // Circle with direction arrow inside
            ZStack {
                Circle()
                    .fill(vehicle.status.color)
                    .frame(width: pinSize, height: pinSize)
                    .shadow(color: vehicle.status.color.opacity(0.4), radius: isSelected ? 8 : 4, y: 2)

                Circle()
                    .strokeBorder(Color.white, lineWidth: 2.5)
                    .frame(width: pinSize, height: pinSize)

                // Direction arrow (matching Android)
                DirectionArrow()
                    .fill(Color.white)
                    .frame(width: pinSize * 0.5, height: pinSize * 0.6)
                    .rotationEffect(.degrees(animatedDirection))
            }

            // Plate label (always visible)
            Text(vehicle.plate)
                .font(.system(size: isSelected ? 9 : 8, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(AppTheme.navy.opacity(0.9))
                )

            // Speed label
            Text(vehicle.formattedSpeed)
                .font(.system(size: isSelected ? 8 : 7, weight: .semibold))
                .foregroundColor(AppTheme.navy)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.9))
                )
        }
        .animation(.spring(response: 0.25), value: isSelected)
    }
}

/// Arrow shape matching Android's direction arrow
struct DirectionArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.midX
        let cy = rect.midY
        let w = rect.width
        let h = rect.height
        // Upward-pointing arrow
        path.move(to: CGPoint(x: cx, y: cy - h * 0.5))        // top
        path.addLine(to: CGPoint(x: cx - w * 0.5, y: cy + h * 0.3)) // bottom-left
        path.addLine(to: CGPoint(x: cx, y: cy + h * 0.1))     // notch
        path.addLine(to: CGPoint(x: cx + w * 0.5, y: cy + h * 0.3)) // bottom-right
        path.closeSubpath()
        return path
    }
}

// (Triangle shape removed — not needed)

// MARK: - Live Map ViewModel
@MainActor
class LiveMapViewModel: ObservableObject {
    @Published var vehicles: [Vehicle] = []
    @Published var statusFilter: VehicleStatus? = nil
    @Published var searchText = ""
    @Published var wsStatus: WSConnectionStatus = .idle

    /// Animated positions: maps vehicle ID → animated CLLocationCoordinate2D
    @Published var animatedPositions: [String: CLLocationCoordinate2D] = [:]
    /// Animated directions: maps vehicle ID → animated heading
    @Published var animatedDirections: [String: Double] = [:]

    private var cancellables = Set<AnyCancellable>()
    private let wsManager = WebSocketManager.shared
    private var animationTimers: [String: Timer] = [:]

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
                $0.driver.lowercased().contains(q) ||
                $0.imei.lowercased().contains(q)
            }
        }
        return result
    }

    /// Get the animated coordinate for a vehicle (falls back to raw lat/lng)
    func animatedCoordinate(for vehicle: Vehicle) -> CLLocationCoordinate2D {
        return animatedPositions[vehicle.id] ?? CLLocationCoordinate2D(latitude: vehicle.lat, longitude: vehicle.lng)
    }

    /// Get the animated direction for a vehicle
    func animatedDirection(for vehicle: Vehicle) -> Double {
        return animatedDirections[vehicle.id] ?? vehicle.direction
    }

    init() {
        subscribeToWebSocket()
    }

    // MARK: - Smooth Animation
    /// Smoothly interpolate a vehicle marker from its current animated position to the new target over ~1 second.
    private func animateVehicle(_ vehicle: Vehicle) {
        let vehicleId = vehicle.id
        let targetLat = vehicle.lat
        let targetLng = vehicle.lng
        let targetDir = vehicle.direction

        let startPos = animatedPositions[vehicleId] ?? CLLocationCoordinate2D(latitude: targetLat, longitude: targetLng)
        let startDir = animatedDirections[vehicleId] ?? targetDir

        // If first time or same position, snap instantly
        if animatedPositions[vehicleId] == nil ||
           (abs(startPos.latitude - targetLat) < 0.000001 && abs(startPos.longitude - targetLng) < 0.000001) {
            animatedPositions[vehicleId] = CLLocationCoordinate2D(latitude: targetLat, longitude: targetLng)
            animatedDirections[vehicleId] = targetDir
            return
        }

        // Cancel previous animation for this vehicle
        animationTimers[vehicleId]?.invalidate()

        let duration: Double = 1.0
        let steps = 30 // 30 frames over 1 second
        let interval = duration / Double(steps)
        var currentStep = 0

        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            currentStep += 1
            let t = min(Double(currentStep) / Double(steps), 1.0)
            // Ease-in-out curve
            let ease = t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t

            let lat = startPos.latitude + (targetLat - startPos.latitude) * ease
            let lng = startPos.longitude + (targetLng - startPos.longitude) * ease
            let dir = startDir + (targetDir - startDir) * ease

            Task { @MainActor in
                self.animatedPositions[vehicleId] = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                self.animatedDirections[vehicleId] = dir
            }

            if currentStep >= steps {
                timer.invalidate()
                Task { @MainActor in
                    self.animationTimers.removeValue(forKey: vehicleId)
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        animationTimers[vehicleId] = timer
    }

    /// Animate all vehicles to their current positions
    private func animateAllVehicles(_ vehicleList: [Vehicle]) {
        for vehicle in vehicleList {
            animateVehicle(vehicle)
        }
    }

    // MARK: - WebSocket Subscription
    private func subscribeToWebSocket() {
        // Observe vehicle list from WebSocketManager
        wsManager.$vehicleList
            .receive(on: DispatchQueue.main)
            .sink { [weak self] vehicleList in
                guard let self = self else { return }
                if !vehicleList.isEmpty {
                    self.vehicles = vehicleList
                    self.animateAllVehicles(vehicleList)
                }
            }
            .store(in: &cancellables)

        // Observe connection status
        wsManager.$status
            .receive(on: DispatchQueue.main)
            .assign(to: &$wsStatus)

        // Listen for specific events if needed
        wsManager.eventSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                switch event {
                case .snapshot(let vehicles, _, _):
                    self.vehicles = vehicles
                    self.animateAllVehicles(vehicles)
                case .update(let vehicle, _):
                    // Update single vehicle in list
                    if let index = self.vehicles.firstIndex(where: { $0.id == vehicle.id }) {
                        self.vehicles[index] = vehicle
                    } else {
                        self.vehicles.append(vehicle)
                    }
                    self.animateVehicle(vehicle)
                case .statusChanged(let status):
                    self.wsStatus = status
                case .pong:
                    break
                }
            }
            .store(in: &cancellables)
    }

    /// If no WS data after some time, load dummy data for preview
    func loadDummyDataIfNeeded() {
        guard vehicles.isEmpty else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self = self, self.vehicles.isEmpty else { return }
            // Only load dummy if still no data after 3 seconds
            if case .error = self.wsStatus {
                self.loadDummyData()
            } else if self.wsStatus == .idle || self.wsStatus == .disconnected {
                self.loadDummyData()
            }
        }
    }

    func loadDummyData() {
        let dummyVehicles = [
            Vehicle(id: "1", plate: "34 ABC 123", model: "Ford Transit", status: .online, kontakOn: true, totalKm: 48320, todayKm: 87, driver: "Ahmet Yılmaz", city: "İstanbul", lat: 41.0082, lng: 28.9784),
            Vehicle(id: "2", plate: "06 XYZ 789", model: "Mercedes Sprinter", status: .offline, kontakOn: false, totalKm: 92100, todayKm: 0, driver: "Mehmet Demir", city: "Ankara", lat: 39.9334, lng: 32.8597),
            Vehicle(id: "3", plate: "35 DEF 456", model: "Renault Master", status: .online, kontakOn: true, totalKm: 31540, todayKm: 62, driver: "Ayşe Kaya", city: "İzmir", lat: 38.4192, lng: 27.1287),
            Vehicle(id: "4", plate: "16 GHI 321", model: "Volkswagen Crafter", status: .idle, kontakOn: false, totalKm: 67890, todayKm: 0, driver: "Can Öztürk", city: "Bursa", lat: 40.1885, lng: 29.0610),
            Vehicle(id: "5", plate: "41 JKL 654", model: "Fiat Ducato", status: .online, kontakOn: true, totalKm: 22430, todayKm: 45, driver: "Zeynep Şahin", city: "Kocaeli", lat: 40.7654, lng: 29.9408),
            Vehicle(id: "6", plate: "07 MNO 987", model: "Peugeot Boxer", status: .offline, kontakOn: false, totalKm: 55670, todayKm: 0, driver: "Ali Çelik", city: "Antalya", lat: 36.8969, lng: 30.7133),
            Vehicle(id: "7", plate: "34 PRS 111", model: "Iveco Daily", status: .online, kontakOn: true, totalKm: 14220, todayKm: 112, driver: "Fatma Arslan", city: "İstanbul", lat: 41.0422, lng: 29.0083),
            Vehicle(id: "8", plate: "06 TUV 222", model: "Ford Transit Custom", status: .idle, kontakOn: false, totalKm: 38900, todayKm: 0, driver: "Hasan Koç", city: "Ankara", lat: 39.9208, lng: 32.8541),
        ]
        vehicles = dummyVehicles
        // Initialize animated positions instantly for dummy data
        for v in dummyVehicles {
            animatedPositions[v.id] = CLLocationCoordinate2D(latitude: v.lat, longitude: v.lng)
            animatedDirections[v.id] = v.direction
        }
    }

    deinit {
        animationTimers.values.forEach { $0.invalidate() }
        animationTimers.removeAll()
    }
}

#Preview {
    LiveMapView(showSideMenu: .constant(false))
        .environmentObject(AuthViewModel())
}
