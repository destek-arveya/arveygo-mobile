import SwiftUI
import MapKit

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
                if selectedVehicle == nil, let first = vm.vehicles.first {
                    selectedVehicle = first
                    vm.selectVehicle(first)
                    vm.loadRoutes(from: startDate, to: endDate)
                }
            }
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
            Map {
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

    init() {
        loadVehicles()
    }

    func loadVehicles() {
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

    func selectVehicle(_ vehicle: Vehicle) {
        selectedVehicleId = vehicle.id
    }

    func selectRoute(_ route: RouteTrip) {
        selectedRoute = route
    }

    func loadRoutes(from startDate: Date, to endDate: Date) {
        // Generate dummy multi-day route data
        let cal = Calendar.current
        let dayCount = max(1, (cal.dateComponents([.day], from: cal.startOfDay(for: startDate), to: cal.startOfDay(for: endDate)).day ?? 0) + 1)
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM"

        var allRoutes: [RouteTrip] = []
        var routeId = 1

        for dayOffset in 0..<dayCount {
            guard let date = cal.date(byAdding: .day, value: dayOffset, to: startDate) else { continue }
            let dateStr = formatter.string(from: date)

            // Day 1 routes
            allRoutes.append(RouteTrip(
                id: "r\(routeId)",
                dateLabel: dateStr,
                startTime: "08:15",
                endTime: "09:42",
                startAddress: "Kadıköy, İstanbul",
                endAddress: "Maslak, İstanbul",
                distance: "32.4 km",
                duration: "1s 27dk",
                maxSpeed: "94 km/h",
                avgSpeed: "38 km/h",
                fuelUsed: "4.2 Lt",
                points: [
                    RoutePoint(lat: 40.9905, lng: 29.0230, speed: 0, time: "08:15"),
                    RoutePoint(lat: 40.9950, lng: 29.0180, speed: 45, time: "08:20"),
                    RoutePoint(lat: 41.0050, lng: 29.0100, speed: 62, time: "08:28"),
                    RoutePoint(lat: 41.0150, lng: 28.9950, speed: 78, time: "08:35"),
                    RoutePoint(lat: 41.0280, lng: 28.9800, speed: 94, time: "08:45"),
                    RoutePoint(lat: 41.0400, lng: 28.9700, speed: 85, time: "08:55"),
                    RoutePoint(lat: 41.0550, lng: 28.9600, speed: 50, time: "09:10"),
                    RoutePoint(lat: 41.0650, lng: 28.9550, speed: 30, time: "09:25"),
                    RoutePoint(lat: 41.0710, lng: 28.9520, speed: 0, time: "09:42"),
                ]
            ))
            routeId += 1

            allRoutes.append(RouteTrip(
                id: "r\(routeId)",
                dateLabel: dateStr,
                startTime: "10:30",
                endTime: "11:15",
                startAddress: "Maslak, İstanbul",
                endAddress: "Şişli, İstanbul",
                distance: "12.8 km",
                duration: "45dk",
                maxSpeed: "72 km/h",
                avgSpeed: "28 km/h",
                fuelUsed: "1.8 Lt",
                points: [
                    RoutePoint(lat: 41.0710, lng: 28.9520, speed: 0, time: "10:30"),
                    RoutePoint(lat: 41.0650, lng: 28.9550, speed: 40, time: "10:38"),
                    RoutePoint(lat: 41.0580, lng: 28.9700, speed: 72, time: "10:48"),
                    RoutePoint(lat: 41.0500, lng: 28.9820, speed: 55, time: "10:58"),
                    RoutePoint(lat: 41.0440, lng: 28.9870, speed: 0, time: "11:15"),
                ]
            ))
            routeId += 1

            allRoutes.append(RouteTrip(
                id: "r\(routeId)",
                dateLabel: dateStr,
                startTime: "13:00",
                endTime: "14:20",
                startAddress: "Şişli, İstanbul",
                endAddress: "Ataşehir, İstanbul",
                distance: "22.1 km",
                duration: "1s 20dk",
                maxSpeed: "88 km/h",
                avgSpeed: "32 km/h",
                fuelUsed: "3.1 Lt",
                points: [
                    RoutePoint(lat: 41.0440, lng: 28.9870, speed: 0, time: "13:00"),
                    RoutePoint(lat: 41.0350, lng: 28.9950, speed: 55, time: "13:10"),
                    RoutePoint(lat: 41.0250, lng: 29.0100, speed: 88, time: "13:25"),
                    RoutePoint(lat: 41.0150, lng: 29.0300, speed: 70, time: "13:40"),
                    RoutePoint(lat: 41.0050, lng: 29.0500, speed: 45, time: "13:55"),
                    RoutePoint(lat: 40.9950, lng: 29.0600, speed: 30, time: "14:10"),
                    RoutePoint(lat: 40.9870, lng: 29.0640, speed: 0, time: "14:20"),
                ]
            ))
            routeId += 1

            allRoutes.append(RouteTrip(
                id: "r\(routeId)",
                dateLabel: dateStr,
                startTime: "16:00",
                endTime: "17:35",
                startAddress: "Ataşehir, İstanbul",
                endAddress: "Kadıköy, İstanbul",
                distance: "15.6 km",
                duration: "1s 35dk",
                maxSpeed: "65 km/h",
                avgSpeed: "22 km/h",
                fuelUsed: "2.4 Lt",
                points: [
                    RoutePoint(lat: 40.9870, lng: 29.0640, speed: 0, time: "16:00"),
                    RoutePoint(lat: 40.9900, lng: 29.0550, speed: 40, time: "16:15"),
                    RoutePoint(lat: 40.9920, lng: 29.0400, speed: 65, time: "16:35"),
                    RoutePoint(lat: 40.9910, lng: 29.0300, speed: 50, time: "16:55"),
                    RoutePoint(lat: 40.9905, lng: 29.0230, speed: 0, time: "17:35"),
                ]
            ))
            routeId += 1
        }

        routes = allRoutes
        if let first = routes.first {
            selectedRoute = first
        }
    }
}

#Preview {
    RouteHistoryView(showSideMenu: .constant(false))
        .environmentObject(AuthViewModel())
}
