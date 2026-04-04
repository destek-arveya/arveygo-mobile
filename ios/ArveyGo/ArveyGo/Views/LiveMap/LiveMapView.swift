import SwiftUI
import MapKit
import Combine

struct LiveMapView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme
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
    @State private var showVehicleSearch = false
    @State private var vehicleSearchText = ""
    @State private var mapCameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 39.9, longitude: 32.8),
            span: MKCoordinateSpan(latitudeDelta: 6, longitudeDelta: 6)
        )
    )

    private var isDark: Bool { colorScheme == .dark }
    private var overlaySurface: Color {
        isDark ? Color(red: 18/255, green: 24/255, blue: 47/255).opacity(0.96) : Color.white.opacity(0.96)
    }
    private var overlayElevatedSurface: Color {
        isDark ? Color(red: 24/255, green: 33/255, blue: 60/255) : Color(red: 246/255, green: 248/255, blue: 252/255)
    }
    private var overlayBorder: Color {
        isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
    }
    private var overlayPrimaryText: Color {
        isDark ? AppTheme.darkText : AppTheme.textPrimary
    }
    private var overlaySecondaryText: Color {
        isDark ? AppTheme.darkTextSub : AppTheme.textSecondary
    }
    private var overlayMutedText: Color {
        isDark ? AppTheme.darkTextMuted : AppTheme.textMuted
    }
    private var vehicleSearchResults: [Vehicle] {
        let query = vehicleSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let base = vm.vehicles.sorted { lhs, rhs in
            if lhs.status != rhs.status {
                return lhs.status.sortOrder < rhs.status.sortOrder
            }
            return lhs.plate < rhs.plate
        }
        guard !query.isEmpty else { return base }
        return base.filter { vehicle in
            vehicle.plate.lowercased().contains(query) ||
            vehicle.model.lowercased().contains(query) ||
            vehicle.driver.lowercased().contains(query) ||
            vehicle.city.lowercased().contains(query)
        }
    }

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

                    if let selected = selectedVehicle {
                        VStack {
                            Spacer()
                            EnrichedPopupWrapper(initialVehicle: selected, liveVehicles: vm.vehicles) { enriched in
                                vehiclePopupSheet(enriched)
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 12)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: selectedVehicle?.id)
                    }

                    // Bottom tracking badge
                    if let trackId = trackingVehicleId {
                        VStack {
                            Spacer()
                            trackingBadge(vehicleId: trackId)
                                .padding(.horizontal, 16)
                                .padding(.bottom, selectedVehicle != nil ? 292 : 16)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.3), value: trackingVehicleId)
                    }

                    // (filter bar moved to top overlay)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(colorScheme == .dark ? AppTheme.darkBg : Color.white, for: .navigationBar)
                .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
                .toolbar {

                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 1) {
                            Text("Canlı Harita")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(colorScheme == .dark ? AppTheme.darkText : AppTheme.navy)
                            Text("Araç Takip / Canlı Harita")
                                .font(.system(size: 10))
                                .foregroundColor(colorScheme == .dark ? AppTheme.darkTextMuted : AppTheme.textMuted)
                        }
                    }
                }
                .sheet(isPresented: $showVehicleSearch) {
                    NavigationStack {
                        vehicleSearchSheet
                    }
                    .presentationDetents([.medium, .large])
                }
                .fullScreenCover(item: $detailVehicle) { vehicle in
                    NavigationStack {
                        VehicleDetailFifthView(
                            vehicle: vehicle,
                            presentationMode: .modal,
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
                       let tracked = vehicles.first(where: { $0.id == trackId && $0.hasValidCoordinates }) {
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

        fitMapToVehicles(vehicles, animated: true, zoomOutFactor: 1.3)
    }

    private func fitMapToVehicles(_ vehicles: [Vehicle], animated: Bool, zoomOutFactor: Double = 1.15) {
        let validVehicles = vehicles.filter(\.hasValidCoordinates)
        guard !validVehicles.isEmpty else { return }

        let lats = validVehicles.map { $0.lat }
        let lngs = validVehicles.map { $0.lng }

        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLng = lngs.min(), let maxLng = lngs.max() else { return }

        let centerLat = (minLat + maxLat) / 2.0
        let centerLng = (minLng + maxLng) / 2.0
        let spanLat = max((maxLat - minLat) * zoomOutFactor, validVehicles.count == 1 ? 0.05 : 0.08)
        let spanLng = max((maxLng - minLng) * zoomOutFactor, validVehicles.count == 1 ? 0.05 : 0.08)

        let update = {
            mapCameraPosition = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng),
                span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLng)
            ))
        }

        if animated {
            withAnimation(.easeInOut(duration: 0.8)) { update() }
        } else {
            update()
        }
    }

    private func focusVehicle(_ vehicle: Vehicle, liftForCard: Bool = true) {
        guard vehicle.hasValidCoordinates else { return }
        let offsetLat = liftForCard ? vehicle.lat + 0.012 : vehicle.lat
        withAnimation(.easeInOut(duration: 0.55)) {
            mapCameraPosition = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: offsetLat, longitude: vehicle.lng),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
        }
    }

    // MARK: - Map Content
    var mapContent: some View {
        Map(position: $mapCameraPosition) {
            // Trail polylines for online + idle vehicles (keep trail visible during rölanti)
            ForEach(vm.mappableVehicles.filter { $0.status == .ignitionOn }) { vehicle in
                if let trail = vm.trailHistory[vehicle.id], trail.count >= 2 {
                    MapPolyline(coordinates: trail)
                        .stroke(vehicle.status.color.opacity(0.6), lineWidth: 3)
                }
            }

            ForEach(vm.mappableVehicles) { vehicle in
                // Use animated coordinates for smooth movement
                let coord = vm.animatedCoordinate(for: vehicle)
                Annotation("", coordinate: coord) {
                    Button(action: {
                        selectedVehicle = vehicle
                        focusVehicle(vehicle)
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

    // MARK: - Top Overlay
    var topOverlay: some View {
        HStack(spacing: 10) {
            Button {
                showVehicleSearch = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Araç Ara")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer(minLength: 0)
                    Text("\(vm.vehicles.count)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(AppTheme.indigo, in: Capsule())
                }
                .foregroundStyle(overlayPrimaryText)
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(overlaySurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(overlayBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Button {
                fitMapToVehicles(vm.filteredVehicles.isEmpty ? vm.vehicles : vm.filteredVehicles, animated: true)
                selectedVehicle = nil
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "scope")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Filoyu Ortala")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(
                    LinearGradient(
                        colors: [AppTheme.indigo, AppTheme.navy],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
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
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            RadialGradient(
                                colors: [vehicle.status.color.opacity(0.2), vehicle.status.color.opacity(0.05)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 30
                            )
                        )
                        .frame(width: 42, height: 42)
                    Image(systemName: vehicle.isMotorcycle ? "bicycle" : "car.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(vehicle.status.color)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(vehicle.plate)
                            .font(.system(size: 17, weight: .heavy))
                            .foregroundColor(overlayPrimaryText)
                            .tracking(0.5)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        StatusBadge(status: vehicle.status)
                    }
                    // name yorum satırına alındı
                    // Text(vehicle.model)
                }
                Spacer()

                Button {
                    selectedVehicle = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(overlaySecondaryText)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(overlayElevatedSurface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(overlayBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 10)

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
                    Divider().frame(height: 30)
                    compactInfoTile(
                        icon: "gauge.open.with.lines.needle.33percent",
                        label: "Hız",
                        value: vehicle.formattedSpeed,
                        iconColor: AppTheme.lavender
                    )
                }

                Divider().padding(.horizontal, 12)

                // Row 2: Bugünkü KM - Toplam KM
                HStack(spacing: 0) {
                    compactInfoTile(
                        icon: "road.lanes",
                        label: "Bugün",
                        value: vehicle.formattedTodayKm,
                        iconColor: AppTheme.lavender
                    )
                    Divider().frame(height: 30)
                    compactInfoTile(
                        icon: "speedometer",
                        label: "Toplam",
                        value: vehicle.formattedTotalKm + " km",
                        iconColor: AppTheme.darkTextSub
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
                        Divider().frame(height: 30)
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
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(overlayMutedText.opacity(0.7))
                        Text("Son Güncelleme: \(vehicle.formattedDeviceTime)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(overlayMutedText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                }
            }
            .background(overlayElevatedSurface)
            .cornerRadius(14)
            .padding(.horizontal, 12)

            // ── Quick Actions ──
            HStack(spacing: 8) {
                popupActionBtn(icon: "location.fill", label: "Yol Tarifi", color: Color(hex: "#3B82F6")) {
                    openMapsDirections(lat: vehicle.lat, lng: vehicle.lng, label: vehicle.plate)
                }
                popupActionBtn(icon: "clock.arrow.circlepath", label: "Rota Geçmişi", color: AppTheme.lavender) {
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
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(overlayElevatedSurface)
            .cornerRadius(14)
            .padding(.horizontal, 12)
            .padding(.top, 8)

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
                            .font(.system(size: 13, weight: .semibold))
                        Text("Canlı İzle")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(AppTheme.online)
                    .cornerRadius(12)
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
                            .font(.system(size: 11, weight: .semibold))
                        Text("Detay Gör")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(isDark ? AppTheme.darkCard : AppTheme.navy)
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 14)
        }
        .background(overlaySurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(overlayBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(isDark ? 0.28 : 0.10), radius: 14, x: 0, y: 8)
    }

    // MARK: - Compact Info Tile
    func compactInfoTile(icon: String, label: String, value: String, valueColor: Color? = nil, iconColor: Color = AppTheme.lavender) -> some View {
        HStack(spacing: 7) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 26, height: 26)
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(overlayMutedText)
                Text(value)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(valueColor ?? overlayPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }

    func popupRow(icon: String, label: String, value: String, valueColor: Color? = nil) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.lavender.opacity(0.7))
                .frame(width: 18)
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(overlaySecondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(valueColor ?? overlayPrimaryText)
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
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 34, height: 34)
                    .background(color.opacity(0.15))
                    .cornerRadius(10)
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(overlayMutedText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
    }

    private var vehicleSearchSheet: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Araç Ara")
                        .font(.system(size: 20, weight: .bold))
                    Text("Seçtiğin araç haritada odaklanır ve bilgi kartı açılır.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 14)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                TextField("Plaka, araç veya sürücü ara", text: $vehicleSearchText)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(overlayElevatedSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 20)
            .padding(.bottom, 14)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(vehicleSearchResults) { vehicle in
                        Button {
                            showVehicleSearch = false
                            vehicleSearchText = ""
                            trackingVehicleId = nil
                            selectedVehicle = vehicle
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                focusVehicle(vehicle)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(vehicle.status.color)
                                    .frame(width: 12, height: 12)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(vehicle.plate)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(overlayPrimaryText)
                                    Text(vehicle.model)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(overlaySecondaryText)
                                        .lineLimit(1)
                                }

                                Spacer(minLength: 12)

                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(vehicle.formattedSpeed)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(overlayPrimaryText)
                                    Text(vehicle.city.isEmpty ? vehicle.status.label : vehicle.city)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(overlayMutedText)
                                        .lineLimit(1)
                                }
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(overlaySurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(overlayBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .background(isDark ? AppTheme.darkBg : Color(red: 244/255, green: 246/255, blue: 251/255))
        .presentationDragIndicator(.visible)
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
    @Published var vehicles: [Vehicle] = [] { didSet { refreshDerivedState() } }
    @Published var statusFilter: VehicleStatus? = nil { didSet { refreshDerivedState() } }
    @Published var searchText = "" { didSet { refreshDerivedState() } }
    @Published var wsStatus: WSConnectionStatus = .idle
    @Published var geofences: [Geofence] = []
    @Published var showGeofences = true
    @Published private(set) var filteredVehicles: [Vehicle] = []
    @Published private(set) var mappableVehicles: [Vehicle] = []
    @Published private(set) var onlineCount = 0
    @Published private(set) var offlineCount = 0
    @Published private(set) var idleCount = 0

    /// Animated positions: maps vehicle ID → animated CLLocationCoordinate2D
    @Published var animatedPositions: [String: CLLocationCoordinate2D] = [:]
    /// Animated directions: maps vehicle ID → animated heading
    @Published var animatedDirections: [String: Double] = [:]
    /// Trail history: last 40 positions per vehicle for iz düşümü
    @Published var trailHistory: [String: [CLLocationCoordinate2D]] = [:]

    private var cancellables = Set<AnyCancellable>()
    private let wsManager = WebSocketManager.shared

    /// Get the animated coordinate for a vehicle (falls back to raw lat/lng)
    func animatedCoordinate(for vehicle: Vehicle) -> CLLocationCoordinate2D {
        animatedPositions[vehicle.id] ?? CLLocationCoordinate2D(latitude: vehicle.lat, longitude: vehicle.lng)
    }

    /// Get the animated direction for a vehicle
    func animatedDirection(for vehicle: Vehicle) -> Double {
        return animatedDirections[vehicle.id] ?? vehicle.direction
    }

    init() {
        refreshDerivedState()
        subscribeToWebSocket()
        loadGeofences()
    }

    private func refreshDerivedState() {
        onlineCount = vehicles.filter { $0.status == .ignitionOn }.count
        offlineCount = vehicles.filter { $0.status == .ignitionOff }.count
        idleCount = vehicles.filter { $0.status == .noData || $0.status == .sleeping }.count

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
        filteredVehicles = result
        mappableVehicles = result.filter(\.hasValidCoordinates)
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
        guard vehicle.hasValidCoordinates else {
            animatedPositions[vehicle.id] = nil
            animatedDirections[vehicle.id] = nil
            trailHistory[vehicle.id] = nil
            return
        }
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

        let targetCoordinate = CLLocationCoordinate2D(latitude: targetLat, longitude: targetLng)
        if animatedPositions[vehicleId] == nil {
            animatedPositions[vehicleId] = targetCoordinate
            animatedDirections[vehicleId] = targetDir
            return
        }

        withAnimation(.linear(duration: 0.35)) {
            animatedPositions[vehicleId] = targetCoordinate
            animatedDirections[vehicleId] = targetDir
        }
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
    LiveMapView(showSideMenu: .constant(false), selectedPage: .constant(.liveMap), alarmsSearchText: .constant(""), alarmsAutoOpenCreate: .constant(false), alarmsPrePlate: .constant(""))
        .environmentObject(AuthViewModel())
}

private extension VehicleStatus {
    var sortOrder: Int {
        switch self {
        case .ignitionOn: return 0
        case .sleeping: return 1
        case .ignitionOff: return 2
        case .noData: return 3
        }
    }
}
