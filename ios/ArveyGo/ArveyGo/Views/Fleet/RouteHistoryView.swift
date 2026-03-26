import SwiftUI
import MapKit
import Combine

// MARK: - Speed Category
enum SpeedCategory: Int, CaseIterable {
    case stopped = 0   // 0 km/h
    case low = 1       // 1–50 km/h
    case medium = 2    // 51–90 km/h
    case high = 3      // 91–120 km/h
    case veryHigh = 4  // 120+ km/h

    var color: Color {
        switch self {
        case .stopped:  return Color(hex: "#f59e0b")  // Rölanti / idle – matches LiveMap
        case .low:      return Color(hex: "#22c55e")
        case .medium:   return Color(hex: "#f59e0b")
        case .high:     return Color(hex: "#f97316")
        case .veryHigh: return Color(hex: "#ef4444")
        }
    }

    var label: String {
        switch self {
        case .stopped:  return "Rölanti"
        case .low:      return "≤50"
        case .medium:   return "51–90"
        case .high:     return "91–120"
        case .veryHigh: return "120+"
        }
    }

    static func from(speed: Int) -> SpeedCategory {
        switch speed {
        case 0:        return .stopped
        case 1..<51:   return .low
        case 51..<91:  return .medium
        case 91..<121: return .high
        default:       return .veryHigh
        }
    }
}

// MARK: - Alarm Type
enum AlarmType: String {
    case speeding     = "speedometer"
    case harshBrake   = "exclamationmark.brake"
    case harshAccel   = "bolt.fill"
    case idling       = "pause.circle.fill"
    case geofence     = "mappin.and.ellipse"

    var color: Color {
        switch self {
        case .speeding:   return Color(hex: "#ef4444")
        case .harshBrake: return Color(hex: "#f97316")
        case .harshAccel: return Color(hex: "#8b5cf6")
        case .idling:     return Color(hex: "#06b6d4")
        case .geofence:   return Color(hex: "#ec4899")
        }
    }

    var icon: String {
        switch self {
        case .speeding:   return "speedometer"
        case .harshBrake: return "exclamationmark.triangle.fill"
        case .harshAccel: return "bolt.fill"
        case .idling:     return "pause.circle.fill"
        case .geofence:   return "mappin.and.ellipse"
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
    let alarm: AlarmType?

    var speedCategory: SpeedCategory { SpeedCategory.from(speed: speed) }
}

struct SpeedSegment {
    let coordinates: [CLLocationCoordinate2D]
    let category: SpeedCategory
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

    var speedSegments: [SpeedSegment] {
        guard points.count > 1 else { return [] }
        var segments: [SpeedSegment] = []
        var currentCat = points[0].speedCategory
        var currentCoords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: points[0].lat, longitude: points[0].lng)
        ]
        for i in 1..<points.count {
            let pt = points[i]
            let coord = CLLocationCoordinate2D(latitude: pt.lat, longitude: pt.lng)
            let cat = pt.speedCategory
            if cat == currentCat {
                currentCoords.append(coord)
            } else {
                currentCoords.append(coord)
                segments.append(SpeedSegment(coordinates: currentCoords, category: currentCat))
                currentCat = cat
                currentCoords = [coord]
            }
        }
        if currentCoords.count > 1 {
            segments.append(SpeedSegment(coordinates: currentCoords, category: currentCat))
        }
        return segments
    }

    var alarmPoints: [RoutePoint] {
        points.filter { $0.alarm != nil }
    }
}

// MARK: - RouteHistoryView
struct RouteHistoryView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Binding var showSideMenu: Bool

    @State private var selectedVehicle: Vehicle?
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var isPlaying = false
    @State private var playbackIndex: Int = 0
    @State private var playbackSpeed: Double = 1.0
    @State private var playbackTimer: Timer?
    @State private var selectedRouteIndex: Int? = nil
    @State private var showVehiclePicker = false
    @State private var vehicleSearchText = ""
    @State private var showDatePickerModal = false
    @State private var mapStyle: MapStyleMode = .standard
    @State private var showSpeedLegend = false
    @State private var isAutoAdvancing = false  // true when auto-jumping to next trip
    @State private var followVehicle = true     // camera follows vehicle during playback

    @StateObject private var vm = RouteHistoryViewModel()

    @State private var mapCameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 40.136, longitude: 26.408),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )

    enum MapStyleMode { case standard, satellite, hybrid }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.bg.ignoresSafeArea()
                VStack(spacing: 0) {
                    selectorBar
                    mapArea
                    if let route = vm.selectedRoute {
                        liveHUDBar(route)
                    }
                    compactTripList
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
                    HStack(spacing: 6) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.indigo)
                        Text("Rota Geçmişi")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.navy)
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
            .sheet(isPresented: $showDatePickerModal) {
                datePickerModal
                    .presentationDetents([.fraction(0.52)])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(24)
            }
            .onAppear { handleOnAppear() }
            .onDisappear { stopPlayback() }
            .onChange(of: vm.vehicles) { _, vehicles in
                if selectedVehicle == nil, let first = vehicles.first {
                    selectedVehicle = first
                    vm.selectVehicle(first)
                    vm.loadRoutes(from: startDate, to: endDate)
                }
            }
            .onChange(of: vm.selectedRoute?.id) { _, _ in
                if !isAutoAdvancing {
                    stopPlayback()
                }
                isAutoAdvancing = false
                zoomToSelectedRoute()
            }
            .onChange(of: vm.routes.count) { _, count in
                if count > 0 { zoomToSelectedRoute() }
            }
            .onChange(of: playbackSpeed) { _, _ in
                if isPlaying { restartPlaybackTimer() }
            }
        }
    }

    private func handleOnAppear() {
        if selectedVehicle == nil, let first = vm.vehicles.first {
            selectedVehicle = first
            vm.selectVehicle(first)
        }
        if vm.selectedVehicleId != nil {
            vm.loadRoutes(from: startDate, to: endDate)
        }
    }

    // MARK: - Zoom to selected route
    private func zoomToSelectedRoute() {
        guard let route = vm.selectedRoute, !route.points.isEmpty else { return }
        let lats = route.points.map { $0.lat }
        let lngs = route.points.map { $0.lng }
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLng = lngs.min(), let maxLng = lngs.max(),
              minLat > -90 && maxLat < 90 && minLng > -180 && maxLng < 180 else { return }
        let centerLat = (minLat + maxLat) / 2.0
        let centerLng = (minLng + maxLng) / 2.0
        let spanLat = max((maxLat - minLat) * 1.5, 0.005)
        let spanLng = max((maxLng - minLng) * 1.5, 0.005)
        withAnimation(.easeInOut(duration: 0.7)) {
            mapCameraPosition = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng),
                span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLng)
            ))
        }
    }

    // MARK: - Selector Bar
    var selectorBar: some View {
        HStack(spacing: 8) {
            // Vehicle selector
            Button(action: { showVehiclePicker = true }) {
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.indigo.opacity(0.12))
                            .frame(width: 24, height: 24)
                        Image(systemName: "car.fill")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.indigo)
                    }
                    Text(selectedVehicle?.plate ?? "Araç Seç")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.navy)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(AppTheme.textMuted)
                }
                .padding(.horizontal, 10)
                .frame(height: 36)
                .background(AppTheme.surface)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.indigo.opacity(0.25), lineWidth: 1))
            }
            .buttonStyle(.plain)

            // Date chip — opens modal
            Button(action: { showDatePickerModal = true }) {
                HStack(spacing: 5) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.indigo)
                    Text(dateRangeSummary)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.navy)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(AppTheme.textMuted)
                }
                .padding(.horizontal, 10)
                .frame(height: 36)
                .background(AppTheme.surface)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.indigo.opacity(0.25), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer()

            // Search / Refresh button
            Button(action: { vm.loadRoutes(from: startDate, to: endDate) }) {
                HStack(spacing: 4) {
                    if vm.isLoadingRoutes {
                        ProgressView().scaleEffect(0.7).tint(.white)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12, weight: .bold))
                    }
                    Text("Ara")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(vm.isLoadingRoutes ? AppTheme.indigo.opacity(0.6) : AppTheme.indigo)
                .cornerRadius(10)
            }
            .disabled(vm.isLoadingRoutes)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppTheme.surface)
        .shadow(color: .black.opacity(0.05), radius: 3, y: 2)
    }

    // MARK: - Date Picker Modal
    var datePickerModal: some View {
        VStack(spacing: 0) {
            // Handle bar
            RoundedRectangle(cornerRadius: 3)
                .fill(AppTheme.borderSoft)
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 12)

            // Header with gradient accent
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tarih Aralığı")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppTheme.navy)
                    Text("Rota geçmişi için tarih seçin")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textMuted)
                }
                Spacer()
                Button(action: { showDatePickerModal = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(AppTheme.textFaint)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            // Quick filters — pill chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(["Bugün", "Dün", "Bu Hafta", "Bu Ay"], id: \.self) { label in
                        let isActive = dateRangeSummary == label
                        Button(action: { applyQuickFilter(label) }) {
                            HStack(spacing: 4) {
                                Image(systemName: label == "Bugün" ? "sun.max.fill" : label == "Dün" ? "moon.fill" : label == "Bu Hafta" ? "calendar" : "calendar.badge.clock")
                                    .font(.system(size: 10))
                                Text(label)
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(isActive ? .white : AppTheme.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Group {
                                    if isActive {
                                        LinearGradient(colors: [AppTheme.indigo, AppTheme.navy], startPoint: .leading, endPoint: .trailing)
                                    } else {
                                        LinearGradient(colors: [AppTheme.bg, AppTheme.bg], startPoint: .leading, endPoint: .trailing)
                                    }
                                }
                            )
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(isActive ? Color.clear : AppTheme.borderSoft, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 20)

            // Date pickers — card style
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.indigo)
                            Text("Başlangıç")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppTheme.textMuted)
                        }
                        DatePicker("", selection: $startDate, in: ...endDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(AppTheme.indigo)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(AppTheme.bg)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppTheme.borderSoft, lineWidth: 1)
                    )

                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.indigo)
                        .frame(width: 28, height: 28)
                        .background(AppTheme.indigo.opacity(0.1))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.indigo)
                            Text("Bitiş")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppTheme.textMuted)
                        }
                        DatePicker("", selection: $endDate, in: startDate...Date(), displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(AppTheme.indigo)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(AppTheme.bg)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppTheme.borderSoft, lineWidth: 1)
                    )
                }
                .padding(.horizontal, 20)
            }

            Spacer()

            // Apply button — gradient
            Button(action: {
                showDatePickerModal = false
                vm.loadRoutes(from: startDate, to: endDate)
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .bold))
                    Text("Rotaları Getir")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(colors: [AppTheme.indigo, AppTheme.navy], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(14)
                .shadow(color: AppTheme.indigo.opacity(0.3), radius: 8, y: 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .background(AppTheme.surface)
    }

    // MARK: - Map Area
    var mapArea: some View {
        ZStack(alignment: .topTrailing) {
            Map(position: $mapCameraPosition) {
                // ALL routes — speed-colored, selected is thicker
                ForEach(vm.routes) { route in
                    let isSelected = vm.selectedRoute?.id == route.id
                    ForEach(Array(route.speedSegments.enumerated()), id: \.offset) { _, seg in
                        MapPolyline(coordinates: seg.coordinates)
                            .stroke(
                                isSelected ? seg.category.color : seg.category.color.opacity(0.45),
                                lineWidth: isSelected ? 5 : 2.5
                            )
                    }
                }

                // Start / End markers for selected route
                if let route = vm.selectedRoute {
                    if let first = route.points.first {
                        Annotation("Başlangıç", coordinate: CLLocationCoordinate2D(latitude: first.lat, longitude: first.lng)) {
                            routeMarker(icon: "flag.fill", color: Color(hex: "#22c55e"), size: 28)
                        }
                    }
                    if let last = route.points.last {
                        Annotation("Bitiş", coordinate: CLLocationCoordinate2D(latitude: last.lat, longitude: last.lng)) {
                            routeMarker(icon: "flag.checkered", color: Color(hex: "#ef4444"), size: 28)
                        }
                    }

                    // Alarm markers
                    ForEach(route.alarmPoints) { pt in
                        if let alarm = pt.alarm {
                            Annotation("", coordinate: CLLocationCoordinate2D(latitude: pt.lat, longitude: pt.lng)) {
                                alarmMarker(alarm: alarm)
                            }
                        }
                    }

                    // Playback vehicle marker — only show when user has interacted
                    if isPlaying || playbackIndex > 0, playbackIndex < route.points.count {
                        let pt = route.points[playbackIndex]
                        Annotation("", coordinate: CLLocationCoordinate2D(latitude: pt.lat, longitude: pt.lng)) {
                            playbackVehicleMarker(speed: pt.speed)
                        }
                    }
                }
            }
            .mapStyle(currentMapStyle)
            .onMapCameraChange { context in
                // Kullanıcının zoom seviyesini yakala — takip ederken aynı uzaklıkta takip et
                userZoomSpan = context.region.span
            }

            // ── Loading blur overlay ──────────────────────────
            if vm.isLoadingRoutes {
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(1.4)
                            .tint(AppTheme.indigo)
                        Text("Rotalar yükleniyor…")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppTheme.navy)
                    }
                    .padding(24)
                    .background(AppTheme.surface.opacity(0.9))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
                }
                .ignoresSafeArea()
                .transition(.opacity)
            }

            // ── Map controls (top-right) ──────────────────────
            if !vm.isLoadingRoutes {
                VStack(spacing: 8) {
                    mapStyleToggle
                    Button(action: { withAnimation(.spring(response: 0.3)) { showSpeedLegend.toggle() } }) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 13))
                            .foregroundColor(showSpeedLegend ? .white : AppTheme.navy)
                            .frame(width: 34, height: 34)
                            .background(showSpeedLegend ? AppTheme.indigo : Color.white.opacity(0.85))
                            .cornerRadius(10)
                            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                    }
                    // Follow vehicle toggle
                    Button(action: { withAnimation(.spring(response: 0.3)) { followVehicle.toggle() } }) {
                        Image(systemName: followVehicle ? "location.fill" : "location.slash")
                            .font(.system(size: 13))
                            .foregroundColor(followVehicle ? .white : AppTheme.navy)
                            .frame(width: 34, height: 34)
                            .background(followVehicle ? AppTheme.indigo : Color.white.opacity(0.85))
                            .cornerRadius(10)
                            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                    }
                }
                .padding(.top, 10)
                .padding(.trailing, 10)

                if showSpeedLegend {
                    speedLegend
                        .padding(.top, 96)
                        .padding(.trailing, 10)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }

            // ── Playback bar (bottom) ─────────────────────────
            if vm.selectedRoute != nil && !vm.isLoadingRoutes {
                VStack {
                    Spacer()
                    playbackBar
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.3), value: vm.isLoadingRoutes)
    }

    // MARK: - Map sub-views
    @ViewBuilder
    func routeMarker(icon: String, color: Color, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .shadow(color: color.opacity(0.5), radius: 6, y: 2)
            Image(systemName: icon)
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundColor(.white)
        }
    }

    @ViewBuilder
    func alarmMarker(alarm: AlarmType) -> some View {
        ZStack {
            Circle()
                .fill(alarm.color.opacity(0.15))
                .frame(width: 28, height: 28)
            Circle()
                .stroke(alarm.color, lineWidth: 1.5)
                .frame(width: 28, height: 28)
            Image(systemName: alarm.icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(alarm.color)
        }
    }

    @ViewBuilder
    func playbackVehicleMarker(speed: Int) -> some View {
        let cat = SpeedCategory.from(speed: speed)
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(cat.color.opacity(0.25))
                    .frame(width: 40, height: 40)
                Circle()
                    .fill(cat.color)
                    .frame(width: 28, height: 28)
                    .shadow(color: cat.color.opacity(0.6), radius: 8, y: 2)
                Image(systemName: "car.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
            .scaleEffect(isPlaying ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isPlaying)

            // Speed label below car
            Text("\(speed) km/h")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(cat.color)
                .cornerRadius(6)
                .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
        }
    }

    // MARK: - Speed Legend
    var speedLegend: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Hız (km/h)")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(AppTheme.textMuted)
                .padding(.bottom, 2)
            ForEach(SpeedCategory.allCases, id: \.rawValue) { cat in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(cat.color)
                        .frame(width: 18, height: 4)
                    Text(cat.label)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(AppTheme.navy)
                }
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
    }

    // MARK: - Map Style Toggle
    var mapStyleToggle: some View {
        Menu {
            Button(action: { mapStyle = .standard }) {
                Label("Standart", systemImage: "map")
            }
            Button(action: { mapStyle = .satellite }) {
                Label("Uydu", systemImage: "globe.americas.fill")
            }
            Button(action: { mapStyle = .hybrid }) {
                Label("Hibrit", systemImage: "map.fill")
            }
        } label: {
            Image(systemName: mapStyleIcon)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.navy)
                .frame(width: 34, height: 34)
                .background(.ultraThinMaterial)
                .cornerRadius(10)
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
        }
    }

    var mapStyleIcon: String {
        switch mapStyle {
        case .standard:  return "map"
        case .satellite: return "globe.americas.fill"
        case .hybrid:    return "map.fill"
        }
    }

    var currentMapStyle: MapStyle {
        switch mapStyle {
        case .standard:  return .standard(elevation: .flat)
        case .satellite: return .imagery(elevation: .flat)
        case .hybrid:    return .hybrid(elevation: .flat)
        }
    }

    // MARK: - Live HUD Bar (dynamic real-time info)
    func liveHUDBar(_ route: RouteTrip) -> some View {
        let currentPoint: RoutePoint? = (isPlaying || playbackIndex > 0) && playbackIndex < route.points.count
            ? route.points[playbackIndex]
            : nil
        let currentSpeed = currentPoint?.speed ?? 0
        let cat = SpeedCategory.from(speed: currentSpeed)
        let currentTime = currentPoint?.time.isEmpty == false ? currentPoint!.time : route.startTime

        return VStack(spacing: 0) {
            // Speed graph — shows speed profile of current trip
            speedGraphView(route: route)

            // Info row: time, speed badge, sefer info, address
            HStack(spacing: 0) {
                // Compact speed badge (small, not distracting)
                HStack(spacing: 3) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 9))
                        .foregroundColor(cat.color)
                    Text("\(currentSpeed) km/h")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(cat.color)
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.2), value: currentSpeed)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(cat.color.opacity(0.1))
                .cornerRadius(8)

                Divider().frame(height: 20).padding(.horizontal, 8)

                // Dynamic info: time, sefer info, address
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.system(size: 9))
                                .foregroundColor(AppTheme.indigo)
                            Text(currentTime)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(AppTheme.navy)
                        }

                        Text("•")
                            .font(.system(size: 8))
                            .foregroundColor(AppTheme.textFaint)

                        Text("Sefer \(currentTripIndex + 1)/\(vm.routes.count)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(AppTheme.indigo)

                        Spacer()
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(AppTheme.textFaint)
                        Text(route.startAddress)
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textMuted)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
        }
        .background(AppTheme.surface)
        .overlay(Rectangle().frame(height: 1).foregroundColor(AppTheme.borderSoft), alignment: .top)
    }

    // MARK: - Speed Graph View
    func speedGraphView(route: RouteTrip) -> some View {
        let points = route.points
        let maxSpeedVal = points.map { $0.speed }.max() ?? 1
        let progress = points.isEmpty ? 0.0 : Double(playbackIndex) / Double(max(points.count - 1, 1))

        return GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack(alignment: .leading) {
                // Background gradient fill under graph
                Path { path in
                    guard points.count > 1 else { return }
                    let step = w / CGFloat(points.count - 1)
                    path.move(to: CGPoint(x: 0, y: h))
                    for (i, pt) in points.enumerated() {
                        let x = CGFloat(i) * step
                        let y = h - (CGFloat(pt.speed) / CGFloat(max(maxSpeedVal, 1))) * (h - 4)
                        if i == 0 {
                            path.addLine(to: CGPoint(x: x, y: y))
                        } else {
                            // Smooth curve
                            let prevX = CGFloat(i - 1) * step
                            let prevY = h - (CGFloat(points[i-1].speed) / CGFloat(max(maxSpeedVal, 1))) * (h - 4)
                            let midX = (prevX + x) / 2
                            path.addCurve(
                                to: CGPoint(x: x, y: y),
                                control1: CGPoint(x: midX, y: prevY),
                                control2: CGPoint(x: midX, y: y)
                            )
                        }
                    }
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [AppTheme.indigo.opacity(0.15), AppTheme.indigo.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Speed line — colored by speed at each segment
                Path { path in
                    guard points.count > 1 else { return }
                    let step = w / CGFloat(points.count - 1)
                    for (i, pt) in points.enumerated() {
                        let x = CGFloat(i) * step
                        let y = h - (CGFloat(pt.speed) / CGFloat(max(maxSpeedVal, 1))) * (h - 4)
                        if i == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            let prevX = CGFloat(i - 1) * step
                            let prevY = h - (CGFloat(points[i-1].speed) / CGFloat(max(maxSpeedVal, 1))) * (h - 4)
                            let midX = (prevX + x) / 2
                            path.addCurve(
                                to: CGPoint(x: x, y: y),
                                control1: CGPoint(x: midX, y: prevY),
                                control2: CGPoint(x: midX, y: y)
                            )
                        }
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: "#22c55e"), Color(hex: "#f59e0b"), Color(hex: "#ef4444")],
                        startPoint: .bottom,
                        endPoint: .top
                    ),
                    lineWidth: 1.5
                )

                // Playback position indicator — vertical line + dot
                if (isPlaying || playbackIndex > 0), points.count > 1 {
                    let posX = w * CGFloat(progress)
                    let currentPt = points[min(playbackIndex, points.count - 1)]
                    let posY = h - (CGFloat(currentPt.speed) / CGFloat(max(maxSpeedVal, 1))) * (h - 4)
                    let ptCat = SpeedCategory.from(speed: currentPt.speed)

                    // Vertical line
                    Rectangle()
                        .fill(ptCat.color.opacity(0.4))
                        .frame(width: 1, height: h)
                        .position(x: posX, y: h / 2)

                    // Dot on the graph line
                    Circle()
                        .fill(ptCat.color)
                        .frame(width: 7, height: 7)
                        .shadow(color: ptCat.color.opacity(0.5), radius: 4)
                        .position(x: posX, y: posY)
                        .animation(.easeOut(duration: 0.15), value: playbackIndex)
                }

                // Max speed label (top-left)
                VStack {
                    Text("\(maxSpeedVal)")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(AppTheme.textFaint)
                    Spacer()
                }
                .padding(.leading, 3)
                .padding(.top, 1)
            }
        }
        .frame(height: 40)
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    // MARK: - Global Playback Helpers
    /// Total number of points across all trips
    var totalGlobalPoints: Int {
        vm.routes.reduce(0) { $0 + $1.points.count }
    }

    /// Global index = sum of previous trips' points + current trip's playbackIndex
    var globalPlaybackIndex: Int {
        guard let currentRoute = vm.selectedRoute else { return 0 }
        var offset = 0
        for route in vm.routes {
            if route.id == currentRoute.id { break }
            offset += route.points.count
        }
        return offset + playbackIndex
    }

    /// Global progress (0...1) across all trips
    var globalProgress: Double {
        let total = totalGlobalPoints
        guard total > 1 else { return 0 }
        return Double(globalPlaybackIndex) / Double(total - 1)
    }

    /// Current trip index in the routes array
    var currentTripIndex: Int {
        guard let sel = vm.selectedRoute else { return 0 }
        return vm.routes.firstIndex(where: { $0.id == sel.id }) ?? 0
    }

    /// Set playback position from a global slider value
    private func seekToGlobal(_ fraction: Double) {
        let total = totalGlobalPoints
        guard total > 1 else { return }
        let targetGlobal = Int(fraction * Double(total - 1))
        var cumulative = 0
        for (idx, route) in vm.routes.enumerated() {
            if cumulative + route.points.count > targetGlobal {
                let localIdx = targetGlobal - cumulative
                if vm.selectedRoute?.id != route.id {
                    isAutoAdvancing = true
                    selectedRouteIndex = idx
                    vm.selectRoute(route)
                }
                playbackIndex = max(0, min(localIdx, route.points.count - 1))
                return
            }
            cumulative += route.points.count
        }
        // Fallback: last point of last trip
        if let last = vm.routes.last {
            if vm.selectedRoute?.id != last.id {
                isAutoAdvancing = true
                selectedRouteIndex = vm.routes.count - 1
                vm.selectRoute(last)
            }
            playbackIndex = max(0, last.points.count - 1)
        }
    }

    // MARK: - Playback Bar
    var playbackBar: some View {
        VStack(spacing: 8) {
            // Time labels + slider
            HStack(spacing: 8) {
                // Play/Pause button
                Button(action: togglePlayback) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.indigo)
                            .frame(width: 38, height: 38)
                            .shadow(color: AppTheme.indigo.opacity(0.4), radius: 8, y: 3)
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }

                // Global slider + time
                VStack(spacing: 3) {
                    Slider(value: Binding(
                        get: { globalProgress },
                        set: { newVal in seekToGlobal(newVal) }
                    ), in: 0...1) { editing in
                        // Slider interaction finished
                    }
                    .tint(currentSpeedColor)

                    HStack {
                        Text(currentTimeLabel)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(AppTheme.textMuted)
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: 0.2), value: playbackIndex)
                        Spacer()
                        // Trip indicator
                        Text("Sefer \(currentTripIndex + 1)/\(vm.routes.count)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(AppTheme.indigo)
                        Spacer()
                        Text(vm.routes.last?.endTime ?? "—")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(AppTheme.textMuted)
                    }
                }

                // Speed selector
                Menu {
                    Button("1×") { playbackSpeed = 1.0 }
                    Button("2×") { playbackSpeed = 2.0 }
                    Button("4×") { playbackSpeed = 4.0 }
                    Button("8×") { playbackSpeed = 8.0 }
                } label: {
                    Text(speedLabel)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppTheme.navy)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                }
            }

            // Global progress bar with trip segment markers
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.borderSoft)
                        .frame(height: 3)
                    Capsule()
                        .fill(currentSpeedColor)
                        .frame(width: geo.size.width * globalProgress, height: 3)
                        .animation(.linear(duration: 0.1), value: globalPlaybackIndex)

                    // Trip boundary markers
                    ForEach(Array(tripBoundaryFractions.enumerated()), id: \.offset) { _, frac in
                        Circle()
                            .fill(AppTheme.textFaint)
                            .frame(width: 5, height: 5)
                            .offset(x: geo.size.width * frac - 2.5)
                    }
                }
            }
            .frame(height: 5)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.2), lineWidth: 1))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
    }

    /// Fraction positions where trips end (for markers on progress bar)
    var tripBoundaryFractions: [CGFloat] {
        let total = totalGlobalPoints
        guard total > 1 else { return [] }
        var cum = 0
        var fracs: [CGFloat] = []
        for route in vm.routes.dropLast() {
            cum += route.points.count
            fracs.append(CGFloat(cum) / CGFloat(total))
        }
        return fracs
    }

    var currentSpeedColor: Color {
        guard let route = vm.selectedRoute, playbackIndex < route.points.count else {
            return AppTheme.indigo
        }
        return route.points[playbackIndex].speedCategory.color
    }

    var currentTimeLabel: String {
        guard let route = vm.selectedRoute, playbackIndex < route.points.count,
              !route.points[playbackIndex].time.isEmpty else {
            return vm.selectedRoute?.startTime ?? "—"
        }
        return route.points[playbackIndex].time
    }

    var speedLabel: String {
        let v = Int(playbackSpeed)
        return "\(v)×"
    }

    // MARK: - Playback Logic
    private func togglePlayback() {
        isPlaying ? stopPlayback() : startPlayback()
    }

    private func startPlayback() {
        guard !vm.routes.isEmpty else { return }
        // If at very end (last point of last trip), restart from beginning
        if let lastRoute = vm.routes.last,
           vm.selectedRoute?.id == lastRoute.id,
           playbackIndex >= lastRoute.points.count - 1 {
            // Jump to first trip, first point
            isAutoAdvancing = true
            selectedRouteIndex = 0
            vm.selectRoute(vm.routes[0])
            playbackIndex = 0
        } else if let route = vm.selectedRoute, playbackIndex >= route.points.count - 1 {
            // Current trip ended but there are more — advance
            advanceToNextTrip()
        }
        guard let route = vm.selectedRoute, route.points.count > 1 else { return }
        isPlaying = true
        scheduleTimer()
    }

    /// Advance to the next trip's first point
    private func advanceToNextTrip() {
        let idx = currentTripIndex
        guard idx + 1 < vm.routes.count else { return }
        let nextRoute = vm.routes[idx + 1]
        isAutoAdvancing = true
        selectedRouteIndex = idx + 1
        vm.selectRoute(nextRoute)
        playbackIndex = 0
    }

    // Track user's preferred zoom level
    @State private var userZoomSpan: MKCoordinateSpan = MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)

    private func scheduleTimer() {
        playbackTimer?.invalidate()
        // 1x = 0.4 saniye → akıcı/kaygan animasyon (su gibi akma)
        let interval = 0.4 / playbackSpeed
        playbackTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor in
                guard let route = vm.selectedRoute else { stopPlayback(); return }
                if playbackIndex < route.points.count - 1 {
                    // Normal: advance within current trip
                    playbackIndex += 1
                    // Follow vehicle camera – keep user's zoom level
                    if followVehicle, playbackIndex < route.points.count {
                        let pt = route.points[playbackIndex]
                        withAnimation(.easeOut(duration: 0.35)) {
                            mapCameraPosition = .region(MKCoordinateRegion(
                                center: CLLocationCoordinate2D(latitude: pt.lat, longitude: pt.lng),
                                span: userZoomSpan
                            ))
                        }
                    }
                } else {
                    // Current trip ended — try next trip
                    let tripIdx = currentTripIndex
                    if tripIdx + 1 < vm.routes.count {
                        // Auto-advance to next trip
                        advanceToNextTrip()
                    } else {
                        // All trips finished
                        stopPlayback()
                    }
                }
            }
        }
    }

    private func restartPlaybackTimer() {
        if isPlaying { scheduleTimer() }
    }

    private func stopPlayback() {
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    // MARK: - Date helpers
    private func applyQuickFilter(_ label: String) {
        let cal = Calendar.current
        switch label {
        case "Bugün":
            startDate = cal.startOfDay(for: Date()); endDate = Date()
        case "Dün":
            let y = cal.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            startDate = cal.startOfDay(for: y)
            var c = DateComponents(); c.hour = 23; c.minute = 59; c.second = 59
            endDate = cal.date(byAdding: c, to: cal.startOfDay(for: y)) ?? y
        case "Bu Hafta":
            let wc = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
            startDate = cal.date(from: wc) ?? Date(); endDate = Date()
        case "Bu Ay":
            let mc = cal.dateComponents([.year, .month], from: Date())
            startDate = cal.date(from: mc) ?? Date(); endDate = Date()
        default: break
        }
        showDatePickerModal = false
        vm.loadRoutes(from: startDate, to: endDate)
    }

    var dateRangeSummary: String {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let start = cal.startOfDay(for: startDate)
        let days = cal.dateComponents([.day], from: start, to: cal.startOfDay(for: endDate)).day ?? 0
        if start == today && days == 0 { return "Bugün" }
        if let y = cal.date(byAdding: .day, value: -1, to: today), start == y && days == 0 { return "Dün" }
        let wc = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        if let ws = cal.date(from: wc), start == ws { return "Bu Hafta" }
        let mc = cal.dateComponents([.year, .month], from: Date())
        if let ms = cal.date(from: mc), start == ms { return "Bu Ay" }
        let df = DateFormatter(); df.dateFormat = "dd.MM"
        return "\(df.string(from: startDate)) – \(df.string(from: endDate))"
    }

    // MARK: - Vehicle Picker Sheet
    var vehiclePickerSheet: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Araç Seçin")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(AppTheme.navy)
                    Text("\(vm.vehicles.count) araç mevcut")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textMuted)
                }
                Spacer()
                Button(action: { showVehiclePicker = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(AppTheme.textFaint)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

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
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.borderSoft, lineWidth: 1))
            .padding(.horizontal, 20)
            .padding(.bottom, 10)

            Divider()

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
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(vehicle.status.color.opacity(0.12))
                                        .frame(width: 42, height: 42)
                                    Image(systemName: "car.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(vehicle.status.color)
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(vehicle.plate)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(AppTheme.navy)
                                    Text("\(vehicle.model) • \(vehicle.driver)")
                                        .font(.system(size: 11))
                                        .foregroundColor(AppTheme.textMuted)
                                        .lineLimit(1)
                                }
                                Spacer()
                                if selectedVehicle?.id == vehicle.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(AppTheme.indigo)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(selectedVehicle?.id == vehicle.id ? AppTheme.indigo.opacity(0.04) : Color.clear)
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 76)
                    }

                    if filteredPickerVehicles.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "car.badge.questionmark")
                                .font(.system(size: 32))
                                .foregroundColor(AppTheme.textFaint)
                            Text("'\(vehicleSearchText)' bulunamadı")
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.textMuted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
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

    // MARK: - Trip List
    var compactTripList: some View {
        VStack(spacing: 0) {
            if let error = vm.errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textMuted)
                        .lineLimit(1)
                    Spacer()
                    Button(action: { vm.loadRoutes(from: startDate, to: endDate) }) {
                        Text("Tekrar Dene")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(AppTheme.indigo)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            } else if vm.routes.isEmpty && !vm.isLoadingRoutes {
                HStack(spacing: 8) {
                    Image(systemName: "map.circle")
                        .font(.system(size: 18))
                        .foregroundColor(AppTheme.textFaint)
                    Text("Bu tarihte rota bulunamadı")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            } else if !vm.routes.isEmpty {
                // Header row
                HStack {
                    Text("Seferler")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppTheme.textMuted)
                    Text("(\(vm.routes.count))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.indigo)
                    Spacer()
                    Text(totalDistanceSummary)
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textFaint)
                }
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .padding(.bottom, 2)

                // Horizontal card list with auto-scroll
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(vm.routes.enumerated()), id: \.element.id) { index, route in
                                enhancedTripCard(route, index: index)
                                    .id(route.id)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                    .onChange(of: vm.selectedRoute?.id) { _, newId in
                        if let id = newId {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(id, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .background(AppTheme.surface)
        .overlay(Rectangle().frame(height: 1).foregroundColor(AppTheme.borderSoft), alignment: .top)
    }

    var totalDistanceSummary: String {
        // Rough sum, display first/last
        guard !vm.routes.isEmpty else { return "—" }
        return "\(vm.routes.count) sefer"
    }

    // MARK: - Enhanced Trip Card
    func enhancedTripCard(_ route: RouteTrip, index: Int) -> some View {
        let isSelected = vm.selectedRoute?.id == route.id

        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedRouteIndex = index
                vm.selectRoute(route)
            }
        }) {
            VStack(alignment: .leading, spacing: 6) {
                // Header: trip number + status dot
                HStack(spacing: 4) {
                    Text("Sefer \(index + 1)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(isSelected ? AppTheme.indigo : AppTheme.textMuted)
                    Spacer()
                    Circle()
                        .fill(isSelected ? AppTheme.indigo : AppTheme.borderSoft)
                        .frame(width: 6, height: 6)
                    if !route.alarmPoints.isEmpty {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.orange)
                    }
                }

                // Time range with colored dots
                HStack(spacing: 4) {
                    Circle().fill(Color(hex: "#22c55e")).frame(width: 5, height: 5)
                    Text(route.startTime)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(AppTheme.navy)
                    Text("→")
                        .font(.system(size: 9))
                        .foregroundColor(AppTheme.textFaint)
                    Circle().fill(Color(hex: "#ef4444")).frame(width: 5, height: 5)
                    Text(route.endTime)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(AppTheme.navy)
                }

                Divider()

                // Stats grid
                HStack(spacing: 10) {
                    tripCardStat(icon: "road.lanes", value: route.distance)
                    tripCardStat(icon: "clock", value: route.duration)
                }
                HStack(spacing: 10) {
                    tripCardStat(icon: "speedometer", value: route.maxSpeed)
                    tripCardStat(icon: "chart.line.uptrend.xyaxis", value: route.avgSpeed)
                }
            }
            .padding(10)
            .frame(width: 160)
            .background(isSelected ? AppTheme.indigo.opacity(0.04) : AppTheme.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? AppTheme.indigo : AppTheme.borderSoft, lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: isSelected ? AppTheme.indigo.opacity(0.15) : .black.opacity(0.04),
                    radius: isSelected ? 6 : 2, y: isSelected ? 3 : 1)
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3), value: isSelected)
    }

    func tripCardStat(icon: String, value: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundColor(AppTheme.indigo)
            Text(value)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(AppTheme.textMuted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        let scanner = Scanner(string: h)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8)  & 0xFF) / 255
        let b = Double(rgb         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - RouteHistoryViewModel
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
    private var loadTask: Task<Void, Never>?
    private var imeiToDeviceId: [String: Int] = [:]

    init() { subscribeToWebSocket() }

    private func subscribeToWebSocket() {
        wsManager.$vehicleList
            .receive(on: DispatchQueue.main)
            .sink { [weak self] list in
                guard let self = self, !list.isEmpty else { return }
                self.vehicles = list
            }
            .store(in: &cancellables)
    }

    func selectVehicle(_ vehicle: Vehicle) { selectedVehicleId = vehicle.id }
    func selectRoute(_ route: RouteTrip)   { selectedRoute = route }

    private func resolveDeviceId(for imei: String) async throws -> Int {
        if let cached = imeiToDeviceId[imei] { return cached }
        let json = try await APIService.shared.get("/api/mobile/route-history/vehicles")
        if let data = json["data"] as? [[String: Any]] {
            for v in data {
                let vImei = v["imei"] as? String ?? ""
                let vId   = v["id"] as? Int ?? v["deviceId"] as? Int ?? 0
                if !vImei.isEmpty && vId > 0 { imeiToDeviceId[vImei] = vId }
            }
        }
        guard let deviceId = imeiToDeviceId[imei], deviceId > 0 else {
            throw NSError(domain: "RouteHistory", code: 404,
                          userInfo: [NSLocalizedDescriptionKey: "Araç bulunamadı (IMEI: \(imei))"])
        }
        return deviceId
    }

    func loadRoutes(from startDate: Date, to endDate: Date) {
        guard let vehicleId = selectedVehicleId else { return }
        loadTask?.cancel()
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let startStr = df.string(from: startDate)
        let endStr   = df.string(from: endDate)

        isLoadingRoutes = true
        errorMessage = nil
        routes = []
        selectedRoute = nil

        loadTask = Task {
            do {
                let deviceId = try await resolveDeviceId(for: vehicleId)
                let json = try await APIService.shared.get(
                    "/api/mobile/route-history/\(deviceId)/trips?started_at=\(startStr)&ended_at=\(endStr)&per_page=4"
                )
                let tripsArray = json["trips"] as? [[String: Any]] ?? json["data"] as? [[String: Any]] ?? []
                var parsedRoutes: [RouteTrip] = []

                for tripJson in tripsArray {
                    let tripNo     = tripJson["tripNo"] as? Int ?? tripJson["trip_no"] as? Int ?? tripJson["id"] as? Int ?? 0
                    let startTime  = tripJson["startTime"] as? String ?? tripJson["started_at"] as? String ?? ""
                    let endTime    = tripJson["endTime"] as? String ?? tripJson["ended_at"] as? String ?? ""
                    let distanceM  = (tripJson["distance"] as? Double) ?? Double(tripJson["distance"] as? Int ?? 0)
                    let distanceKm = distanceM / 1000.0
                    let distanceStr = distanceKm < 1.0 ? String(format: "%.0f m", distanceM) : String(format: "%.1f km", distanceKm)
                    let durationSec = (tripJson["duration"] as? Int) ?? Int((tripJson["duration"] as? Double) ?? 0)
                    let dMin = durationSec / 60; let dSec = durationSec % 60
                    let durationStr = dMin > 0 ? "\(dMin)dk \(dSec)sn" : "\(dSec)sn"
                    let maxSpeedVal = (tripJson["maxSpeed"] as? Int) ?? (tripJson["max_speed"] as? Int) ?? 0
                    let avgSpeedVal = (tripJson["avgSpeed"] as? Int) ?? (tripJson["avg_speed"] as? Int) ?? 0
                    let displayStart = Self.formatTimeOnly(startTime)
                    let displayEnd   = Self.formatTimeOnly(endTime)
                    let dateLabel    = Self.formatDateLabel(startTime)

                    var points: [RoutePoint] = []

                    // Inline coords
                    if let coordsArray = tripJson["coords"] as? [[Any]], !coordsArray.isEmpty {
                        for coord in coordsArray {
                            if coord.count >= 2, let lat = coord[0] as? Double, let lng = coord[1] as? Double {
                                let spd = coord.count >= 4 ? (coord[3] as? Int ?? Int((coord[3] as? Double) ?? 0)) : 0
                                points.append(RoutePoint(lat: lat, lng: lng, speed: spd, time: "", alarm: nil))
                            }
                        }
                    }

                    // Points endpoint
                    if points.isEmpty {
                        do {
                            let pointsJson = try await APIService.shared.get(
                                "/api/mobile/route-history/\(deviceId)/trips/\(tripNo)/points?started_at=\(startStr)&ended_at=\(endStr)"
                            )
                            if let pbPoints = pointsJson["playbackPoints"] as? [[String: Any]], !pbPoints.isEmpty {
                                for pt in pbPoints {
                                    let lat   = (pt["lat"]   as? Double) ?? 0
                                    let lng   = (pt["lng"]   as? Double) ?? 0
                                    let spd   = (pt["speed"] as? Int)    ?? Int((pt["speed"] as? Double) ?? 0)
                                    let time  = (pt["time"]  as? String) ?? ""
                                    // Parse alarms if present
                                    let alarmRaw = pt["alarm"] as? String
                                    let alarm: AlarmType? = alarmRaw.flatMap { AlarmType(rawValue: $0) }
                                    points.append(RoutePoint(lat: lat, lng: lng, speed: spd,
                                                             time: Self.formatTimeOnly(time), alarm: alarm))
                                }
                            } else if let routeCoords = pointsJson["routeCoords"] as? [[Any]], !routeCoords.isEmpty {
                                for coord in routeCoords {
                                    if coord.count >= 2, let lat = coord[0] as? Double, let lng = coord[1] as? Double {
                                        let spd = coord.count >= 4 ? (coord[3] as? Int ?? 0) : 0
                                        points.append(RoutePoint(lat: lat, lng: lng, speed: spd, time: "", alarm: nil))
                                    }
                                }
                            }
                        } catch {
                            print("[RouteHistory] Points load failed for trip \(tripNo): \(error)")
                        }
                    }

                    // Fallback: start/end coords only
                    if points.isEmpty {
                        if let sc = tripJson["startCoord"] as? [Any], sc.count >= 2,
                           let lat = sc[0] as? Double, let lng = sc[1] as? Double {
                            points.append(RoutePoint(lat: lat, lng: lng, speed: 0, time: displayStart, alarm: nil))
                        }
                        if let ec = tripJson["endCoord"] as? [Any], ec.count >= 2,
                           let lat = ec[0] as? Double, let lng = ec[1] as? Double {
                            points.append(RoutePoint(lat: lat, lng: lng, speed: 0, time: displayEnd, alarm: nil))
                        }
                    }

                    parsedRoutes.append(RouteTrip(
                        id: "trip\(tripNo)",
                        dateLabel: dateLabel,
                        startTime: displayStart,
                        endTime: displayEnd,
                        startAddress: tripJson["startTimeLabel"] as? String ?? displayStart,
                        endAddress: tripJson["endTimeLabel"]   as? String ?? displayEnd,
                        distance: distanceStr,
                        duration: durationStr,
                        maxSpeed: "\(maxSpeedVal) km/h",
                        avgSpeed: "\(avgSpeedVal) km/h",
                        fuelUsed: "—",
                        points: points
                    ))
                }

                guard !Task.isCancelled else { return }
                self.routes = parsedRoutes
                self.isLoadingRoutes = false
                self.selectedRoute = parsedRoutes.first
                print("[RouteHistory] Loaded \(parsedRoutes.count) trips")

            } catch {
                guard !Task.isCancelled else { return }
                self.isLoadingRoutes = false
                self.errorMessage = error.localizedDescription
                self.routes = []
                self.selectedRoute = nil
                print("[RouteHistory] Error: \(error)")
            }
        }
    }

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
            if cal.isDateInToday(date)     { return "Bugün" }
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