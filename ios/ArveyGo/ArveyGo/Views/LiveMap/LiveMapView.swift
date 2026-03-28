import SwiftUI
import MapKit
import Combine

struct LiveMapView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = LiveMapViewModel()
    @Binding var showSideMenu: Bool
    @Binding var selectedPage: AppPage
    @Binding var alarmsSearchText: String
    @Binding var alarmsAutoOpenCreate: Bool
    @Binding var alarmsPrePlate: String
    @State private var selectedVehicle: Vehicle?
    @State private var showVehicleDetail = false
    @State private var detailVehicle: Vehicle?
    @State private var hasFittedBounds = false
    @State private var trackingVehicleId: String?
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

                    // Bottom tracking badge
                    if let trackId = trackingVehicleId {
                        VStack {
                            Spacer()
                            trackingBadge(vehicleId: trackId)
                                .padding(.horizontal, 16)
                                .padding(.bottom, selectedVehicle != nil ? 260 : 16)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.3), value: trackingVehicleId)
                    }

                    // (filter bar moved to top overlay)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            selectedVehicle = nil
                            withAnimation(.spring(response: 0.3)) { showSideMenu.toggle() }
                        }) {
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
                .sheet(item: $selectedVehicle) { selected in
                    // Look up latest vehicle data from ViewModel for real-time updates
                    let liveVehicle = vm.vehicles.first(where: { $0.id == selected.id }) ?? selected
                    EnrichedPopupWrapper(initialVehicle: liveVehicle, liveVehicles: vm.vehicles) { enriched in
                        vehiclePopupSheet(enriched)
                    }
                        .presentationDetents([.fraction(0.50), .large])
                        .presentationDragIndicator(.visible)
                        .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.50)))
                        .presentationCornerRadius(20)
                }
                .fullScreenCover(item: $detailVehicle) { vehicle in
                    VehicleDetailView(
                        vehicle: vehicle,
                        onNavigateToRouteHistory: { v in
                            detailVehicle = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                selectedPage = .routeHistory
                            }
                        },
                        onNavigateToAlarms: { plateText in
                            detailVehicle = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                alarmsSearchText = plateText
                                selectedPage = .alarms
                            }
                        },
                        onNavigateToAddAlarm: { plate in
                            detailVehicle = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                alarmsSearchText = ""
                                alarmsAutoOpenCreate = true
                                alarmsPrePlate = plate
                                selectedPage = .alarms
                            }
                        }
                    )
                }
                .onAppear {
                    // Connect WebSocket when map appears
                    authVM.connectWebSocket()
                }
                .onChange(of: showSideMenu) { _, isShowing in
                    if isShowing { selectedVehicle = nil }
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
                    // If tracking a vehicle, follow it
                    if let trackId = trackingVehicleId,
                       let tracked = vehicles.first(where: { $0.id == trackId }) {
                        withAnimation(.easeInOut(duration: 0.6)) {
                            mapCameraPosition = .region(MKCoordinateRegion(
                                center: CLLocationCoordinate2D(latitude: tracked.lat, longitude: tracked.lng),
                                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                            ))
                        }
                    }
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
            // Trail polylines for online + idle vehicles (keep trail visible during rölanti)
            ForEach(vm.filteredVehicles.filter { $0.status == .ignitionOn }) { vehicle in
                if let trail = vm.trailHistory[vehicle.id], trail.count >= 2 {
                    MapPolyline(coordinates: trail)
                        .stroke(vehicle.status.color.opacity(0.6), lineWidth: 3)
                }
            }

            ForEach(vm.filteredVehicles) { vehicle in
                // Use animated coordinates for smooth movement
                let coord = vm.animatedCoordinate(for: vehicle)
                Annotation("", coordinate: coord) {
                    Button(action: {
                        selectedVehicle = vehicle
                        // Aracı haritanın üst %25'lik kısmına taşı (modal alt yarıyı kaplayacağı için)
                        let offsetLat = vehicle.lat + 0.012 // ~%25 yukarı kaydırma
                        withAnimation {
                            mapCameraPosition = .region(MKCoordinateRegion(
                                center: CLLocationCoordinate2D(latitude: offsetLat, longitude: vehicle.lng),
                                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                            ))
                        }
                    }) {
                        VehicleMapPin(vehicle: vehicle, isSelected: selectedVehicle?.id == vehicle.id, animatedDirection: vm.animatedDirection(for: vehicle))
                    }
                }
            }

            // Geofence overlays
            if vm.showGeofences {
                ForEach(vm.geofences) { geofence in
                    if geofence.isCircle, let cLat = geofence.centerLat, let cLng = geofence.centerLng, let r = geofence.radius {
                        MapCircle(center: CLLocationCoordinate2D(latitude: cLat, longitude: cLng), radius: r)
                            .foregroundStyle(geofence.swiftUIColor.opacity(0.15))
                            .stroke(geofence.swiftUIColor.opacity(0.6), lineWidth: 1.5)
                    } else if !geofence.points.isEmpty {
                        MapPolygon(coordinates: geofence.points.map {
                            CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
                        })
                        .foregroundStyle(geofence.swiftUIColor.opacity(0.15))
                        .stroke(geofence.swiftUIColor.opacity(0.6), lineWidth: 1.5)
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
                    statusChip(label: "Kontak Açık", count: vm.onlineCount, filter: .ignitionOn, color: AppTheme.online)
                    statusChip(label: "Kontak Kapalı", count: vm.offlineCount, filter: .ignitionOff, color: AppTheme.offline)
                    statusChip(label: "Bilgi Yok", count: vm.idleCount, filter: .noData, color: Color(red: 148/255, green: 163/255, blue: 184/255))
                    
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

    // MARK: - Tracking Badge (bottom, wider, readable)
    func trackingBadge(vehicleId: String) -> some View {
        let trackedPlate = vm.vehicles.first(where: { $0.id == vehicleId })?.plate ?? vehicleId
        return Button(action: { trackingVehicleId = nil }) {
            HStack(spacing: 10) {
                // Pulsing red dot
                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle()
                            .stroke(Color.red.opacity(0.4), lineWidth: 3)
                            .scaleEffect(1.5)
                    )

                Image(systemName: "location.fill")
                    .font(.system(size: 16, weight: .semibold))

                VStack(alignment: .leading, spacing: 1) {
                    Text("Canlı İzleme Aktif")
                        .font(.system(size: 14, weight: .bold))
                    Text(trackedPlate)
                        .font(.system(size: 12, weight: .medium))
                        .opacity(0.9)
                }

                Spacer()

                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .opacity(0.8)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppTheme.online)
                    .shadow(color: AppTheme.online.opacity(0.4), radius: 8, y: 4)
            )
        }
        .buttonStyle(.plain)
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

    // MARK: - Vehicle Popup Sheet (modern compact design)
    func vehiclePopupSheet(_ vehicle: Vehicle) -> some View {
        VStack(spacing: 0) {
            // ── Header: Plate + Status (name ve kontak durumu kaldırıldı) ──
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            RadialGradient(
                                colors: [vehicle.status.color.opacity(0.2), vehicle.status.color.opacity(0.05)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 30
                            )
                        )
                        .frame(width: 48, height: 48)
                    Image(systemName: vehicle.isMotorcycle ? "bicycle" : "car.fill")
                        .font(.system(size: 22))
                        .foregroundColor(vehicle.status.color)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 10) {
                        Text(vehicle.plate)
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundColor(AppTheme.navy)
                            .tracking(0.5)
                        StatusBadge(status: vehicle.status)
                    }
                    // name yorum satırına alındı
                    // Text(vehicle.model)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 14)

            // ── Compact Info Grid (2-column rows) ──
            VStack(spacing: 0) {
                // Row 1: Kontak - Hız
                HStack(spacing: 0) {
                    compactInfoTile(
                        icon: vehicle.kontakOn ? "key.fill" : "key",
                        label: "Kontak",
                        value: vehicle.kontakOn ? "Açık" : "Kapalı",
                        valueColor: vehicle.kontakOn ? AppTheme.online : AppTheme.offline,
                        iconColor: vehicle.kontakOn ? AppTheme.online : AppTheme.offline
                    )
                    Divider().frame(height: 36)
                    compactInfoTile(
                        icon: "gauge.open.with.lines.needle.33percent",
                        label: "Hız",
                        value: vehicle.formattedSpeed,
                        iconColor: AppTheme.indigo
                    )
                }

                Divider().padding(.horizontal, 12)

                // Row 2: Bugünkü KM - Toplam KM
                HStack(spacing: 0) {
                    compactInfoTile(
                        icon: "road.lanes",
                        label: "Bugün",
                        value: vehicle.formattedTodayKm,
                        iconColor: AppTheme.indigo
                    )
                    Divider().frame(height: 36)
                    compactInfoTile(
                        icon: "speedometer",
                        label: "Toplam",
                        value: vehicle.formattedTotalKm + " km",
                        iconColor: AppTheme.navy
                    )
                }

                // Row 3: Sıcaklık - Nem (varsa)
                if vehicle.temperatureC != nil || vehicle.humidityPct != nil {
                    Divider().padding(.horizontal, 12)
                    HStack(spacing: 0) {
                        compactInfoTile(
                            icon: "thermometer.medium",
                            label: "Sıcaklık",
                            value: vehicle.temperatureC.map { String(format: "%.1f°C", $0) } ?? "—",
                            valueColor: vehicle.temperatureC.map { $0 < 0 ? .blue : ($0 < 30 ? AppTheme.online : .red) },
                            iconColor: Color(red: 1.0, green: 0.42, blue: 0.21)
                        )
                        Divider().frame(height: 36)
                        compactInfoTile(
                            icon: "humidity.fill",
                            label: "Nem",
                            value: vehicle.humidityPct.map { "%\(Int($0))" } ?? "—",
                            iconColor: Color(red: 0.024, green: 0.714, blue: 0.831)
                        )
                    }
                }

                // Konum - yorum satırına alındı
                // popupRow(icon: "mappin.circle.fill", label: "Konum", value: vehicle.locationDisplay)

                // Son Güncelleme - ortalanmış
                if vehicle.deviceTime != nil {
                    Divider().padding(.horizontal, 12)
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textMuted.opacity(0.6))
                        Text("Son Güncelleme: \(vehicle.formattedDeviceTime)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
            .background(AppTheme.surface)
            .cornerRadius(16)
            .padding(.horizontal, 16)

            // ── Quick Actions ──
            HStack(spacing: 8) {
                popupActionBtn(icon: "location.fill", label: "Yol Tarifi", color: Color(hex: "#3B82F6")) {
                    openMapsDirections(lat: vehicle.lat, lng: vehicle.lng, label: vehicle.plate)
                }
                popupActionBtn(icon: "clock.arrow.circlepath", label: "Rota Geçmişi", color: AppTheme.indigo) {
                    selectedVehicle = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        selectedPage = .routeHistory
                    }
                }
                popupActionBtn(icon: "bell.badge.fill", label: "Alarm Ekle", color: .orange) {
                    let plate = vehicle.plate
                    selectedVehicle = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        alarmsSearchText = ""
                        alarmsAutoOpenCreate = true
                        alarmsPrePlate = plate
                        selectedPage = .alarms
                    }
                }
                popupActionBtn(icon: "lock.fill", label: "Blokaj", color: .red) {}
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .background(AppTheme.surface)
            .cornerRadius(16)
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // ── Action Buttons (yan yana) ──
            HStack(spacing: 10) {
                Button(action: {
                    trackingVehicleId = vehicle.id
                    selectedVehicle = nil
                    withAnimation(.easeInOut(duration: 0.6)) {
                        mapCameraPosition = .region(MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: vehicle.lat, longitude: vehicle.lng),
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        ))
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "location.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Canlı İzle")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(AppTheme.online)
                    .cornerRadius(14)
                }

                Button(action: {
                    let v = vehicle
                    selectedVehicle = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        detailVehicle = v
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Detay Gör")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(AppTheme.buttonGradient)
                    .cornerRadius(14)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Compact Info Tile
    func compactInfoTile(icon: String, label: String, value: String, valueColor: Color? = nil, iconColor: Color = AppTheme.indigo) -> some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(iconColor)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppTheme.textMuted)
                Text(value)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(valueColor ?? AppTheme.navy)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    func popupRow(icon: String, label: String, value: String, valueColor: Color? = nil) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.indigo.opacity(0.7))
                .frame(width: 18)
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textMuted)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(valueColor ?? AppTheme.navy)
                .lineLimit(1)
                .frame(maxWidth: 170, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    var popupDivider: some View {
        Divider()
            .padding(.leading, 48)
            .padding(.trailing, 16)
    }

    func popupActionBtn(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                    .frame(width: 40, height: 40)
                    .background(color.opacity(0.1))
                    .cornerRadius(11)
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(AppTheme.textMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Open Maps Directions
    private func openMapsDirections(lat: Double, lng: Double, label: String) {
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = label
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
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

                if vehicle.isMotorcycle {
                    // Motorcycle icon
                    Image(systemName: "bicycle")
                        .font(.system(size: pinSize * 0.4, weight: .bold))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(animatedDirection))
                } else {
                    // Direction arrow (matching Android)
                    DirectionArrow()
                        .fill(Color.white)
                        .frame(width: pinSize * 0.5, height: pinSize * 0.6)
                        .rotationEffect(.degrees(animatedDirection))
                }
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
    @Published var geofences: [Geofence] = []
    @Published var showGeofences = true

    /// Animated positions: maps vehicle ID → animated CLLocationCoordinate2D
    @Published var animatedPositions: [String: CLLocationCoordinate2D] = [:]
    /// Animated directions: maps vehicle ID → animated heading
    @Published var animatedDirections: [String: Double] = [:]
    /// Trail history: last 40 positions per vehicle for iz düşümü
    @Published var trailHistory: [String: [CLLocationCoordinate2D]] = [:]

    private var cancellables = Set<AnyCancellable>()
    private let wsManager = WebSocketManager.shared
    private var animationTimers: [String: Timer] = [:]

    var onlineCount: Int { vehicles.filter { $0.status == .ignitionOn }.count }
    var offlineCount: Int { vehicles.filter { $0.status == .ignitionOff }.count }
    var idleCount: Int { vehicles.filter { $0.status == .noData || $0.status == .sleeping }.count }

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
        loadGeofences()
    }

    func loadGeofences() {
        Task {
            do {
                let result = try await APIService.shared.fetchGeofences()
                await MainActor.run { self.geofences = result }
            } catch {
                print("[LiveMap] Geofence fetch error: \(error)")
            }
        }
    }

    // MARK: - Smooth Animation
    /// Smoothly interpolate a vehicle marker from its current animated position to the new target over ~1 second.
    private func animateVehicle(_ vehicle: Vehicle) {
        let vehicleId = vehicle.id
        let targetLat = vehicle.lat
        let targetLng = vehicle.lng
        let targetDir = vehicle.direction

        // Update trail history for online/idle vehicles (keep trail visible during rölanti)
        let newPos = CLLocationCoordinate2D(latitude: targetLat, longitude: targetLng)
        if vehicle.status == .ignitionOn && targetLat != 0 && targetLng != 0 {
            var trail = trailHistory[vehicleId] ?? []
            if let last = trail.last {
                if abs(last.latitude - targetLat) > 0.000001 || abs(last.longitude - targetLng) > 0.000001 {
                    trail.append(newPos)
                    if trail.count > 20 { trail.removeFirst() }
                    trailHistory[vehicleId] = trail
                }
            } else {
                trailHistory[vehicleId] = [newPos]
            }
        }

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
                    // Mevcut araç değerlerini koruyarak güncelle (null sıcaklık/nem için)
                    let currentMap = Dictionary(uniqueKeysWithValues: self.vehicles.map { ($0.id, $0) })
                    self.vehicles = vehicleList.map { newVehicle in
                        if var existing = currentMap[newVehicle.id] {
                            existing.mergeUpdate(from: newVehicle)
                            return existing
                        }
                        return newVehicle
                    }
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
                    // Snapshot'ta da mevcut değerleri koru
                    let currentMap = Dictionary(uniqueKeysWithValues: self.vehicles.map { ($0.id, $0) })
                    self.vehicles = vehicles.map { newVehicle in
                        if var existing = currentMap[newVehicle.id] {
                            existing.mergeUpdate(from: newVehicle)
                            return existing
                        }
                        return newVehicle
                    }
                    self.animateAllVehicles(vehicles)
                case .update(let vehicle, _):
                    // mergeUpdate ile null değerlerde önceki değeri koru
                    if let index = self.vehicles.firstIndex(where: { $0.id == vehicle.id }) {
                        self.vehicles[index].mergeUpdate(from: vehicle)
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



    deinit {
        animationTimers.values.forEach { $0.invalidate() }
        animationTimers.removeAll()
    }
}

// MARK: - Enriched Popup Wrapper (fetches API data for LiveMap popup)
struct EnrichedPopupWrapper<Content: View>: View {
    @State private var vehicle: Vehicle
    let liveVehicles: [Vehicle]
    let content: (Vehicle) -> Content

    init(initialVehicle: Vehicle, liveVehicles: [Vehicle], @ViewBuilder content: @escaping (Vehicle) -> Content) {
        self._vehicle = State(initialValue: initialVehicle)
        self.liveVehicles = liveVehicles
        self.content = content
    }

    var body: some View {
        content(vehicle)
            .task {
                guard vehicle.deviceId > 0,
                      vehicle.groupName.isEmpty || vehicle.address.isEmpty else { return }
                do {
                    let detail = try await APIService.shared.fetchVehicleDetail(deviceId: vehicle.deviceId)
                    let todayKmVal = (detail["todayKm"] as? Double) ?? (detail["todayKm"] as? Int).map { Double($0) } ?? 0
                    let todayDistanceM = (detail["todayDistanceM"] as? Double) ?? (detail["todayDistanceM"] as? Int).map { Double($0) } ?? 0
                    let dailyKmVal = todayKmVal > 0 ? todayKmVal : (todayDistanceM > 0 ? todayDistanceM / 1000.0 : 0)

                    var enriched = vehicle
                    if let v = detail["groupName"] as? String, !v.isEmpty, v != "<null>" { enriched.groupName = v }
                    if let v = detail["vehicleBrand"] as? String, !v.isEmpty, v != "<null>" { enriched.vehicleBrand = v }
                    if let v = detail["vehicleModel"] as? String, !v.isEmpty, v != "<null>" { enriched.vehicleModel = v }
                    if let v = detail["address"] as? String, !v.isEmpty, v != "<null>" { enriched.address = v }
                    if let v = detail["city"] as? String, !v.isEmpty, v != "<null>" { enriched.city = v }
                    if dailyKmVal > 0 { enriched.dailyKm = dailyKmVal; enriched.todayKm = Int(dailyKmVal) }
                    if let v = detail["first_ignition_on_at_today"] as? String, !v.isEmpty, v != "<null>" { enriched.firstIgnitionOnAtToday = v }
                    if let v = detail["last_ignition_on_at"] as? String, !v.isEmpty, v != "<null>" { enriched.lastIgnitionOnAt = v }
                    if let v = detail["last_ignition_off_at"] as? String, !v.isEmpty, v != "<null>" { enriched.lastIgnitionOffAt = v }
                    vehicle = enriched
                } catch {
                    print("[LiveMap] Popup enrichment error: \(error)")
                }
            }
            .onChange(of: liveVehicles) { _, newVehicles in
                // Keep live WS data synced while preserving enriched fields
                guard let live = newVehicles.first(where: { $0.id == vehicle.id }) else { return }
                var merged = live
                if !vehicle.groupName.isEmpty { merged.groupName = vehicle.groupName }
                if !vehicle.vehicleBrand.isEmpty { merged.vehicleBrand = vehicle.vehicleBrand }
                if !vehicle.vehicleModel.isEmpty { merged.vehicleModel = vehicle.vehicleModel }
                if !vehicle.address.isEmpty { merged.address = vehicle.address }
                if !vehicle.city.isEmpty { merged.city = vehicle.city }
                if vehicle.dailyKm > 0 { merged.dailyKm = vehicle.dailyKm; merged.todayKm = Int(vehicle.dailyKm) }
                if vehicle.firstIgnitionOnAtToday != nil { merged.firstIgnitionOnAtToday = vehicle.firstIgnitionOnAtToday }
                if vehicle.lastIgnitionOnAt != nil { merged.lastIgnitionOnAt = vehicle.lastIgnitionOnAt }
                if vehicle.lastIgnitionOffAt != nil { merged.lastIgnitionOffAt = vehicle.lastIgnitionOffAt }
                vehicle = merged
            }
    }
}

#Preview {
    LiveMapView(showSideMenu: .constant(false), selectedPage: .constant(.liveMap), alarmsSearchText: .constant(""))
        .environmentObject(AuthViewModel())
}
