import SwiftUI
import MapKit
import Combine

// MARK: - Live Vehicle Observer
/// Observes WebSocket updates for a specific vehicle and publishes changes.
@MainActor
class VehicleDetailObserver: ObservableObject {
    @Published var vehicle: Vehicle
    @Published var driverName: String = ""
    @Published var driverPhone: String = ""
    private var cancellables = Set<AnyCancellable>()

    init(vehicle: Vehicle) {
        self.vehicle = vehicle
        subscribeToUpdates()
        fetchDriverInfo()
    }

    func fetchDriverInfo() {
        guard vehicle.deviceId > 0 else { return }
        Task {
            do {
                let detail = try await APIService.shared.fetchVehicleDetail(deviceId: vehicle.deviceId)
                if let driverDict = detail["driver"] as? [String: Any] {
                    let name = driverDict["name"] as? String ?? ""
                    let phone = driverDict["phone"] as? String ?? ""
                    await MainActor.run {
                        self.driverName = name
                        self.driverPhone = phone
                    }
                }
                await MainActor.run {
                    self.enrichVehicleFromDetail(detail)
                }
            } catch {
                print("[VehicleDetail] fetchDriverInfo error: \(error)")
            }
        }
    }

    func enrichVehicleFromDetail(_ detail: [String: Any]) {
        let todayKmVal = (detail["todayKm"] as? Double) ?? (detail["todayKm"] as? Int).map { Double($0) } ?? 0
        let todayDistanceM = (detail["todayDistanceM"] as? Double) ?? (detail["todayDistanceM"] as? Int).map { Double($0) } ?? 0
        let dailyKmApi = (detail["dailyKm"] as? Double) ?? (detail["daily_km"] as? Double) ?? (detail["dailyKm"] as? Int).map { Double($0) } ?? (detail["daily_km"] as? Int).map { Double($0) } ?? 0
        let dailyKmVal = dailyKmApi > 0 ? dailyKmApi : (todayKmVal > 0 ? todayKmVal : (todayDistanceM > 0 ? todayDistanceM / 1000.0 : 0))
        let groupNameVal = detail["groupName"] as? String ?? ""
        let vehicleBrandVal = detail["vehicleBrand"] as? String ?? ""
        let vehicleModelVal = detail["vehicleModel"] as? String ?? ""
        let addressVal = detail["address"] as? String ?? ""
        let cityVal = detail["city"] as? String ?? ""
        let fuelTypeVal = detail["fuelType"] as? String ?? ""
        let dailyFuelLitersVal = (detail["dailyFuelLiters"] as? Double) ?? (detail["dailyFuelLiters"] as? Int).map { Double($0) } ?? 0
        let dailyFuelPer100kmVal = (detail["dailyFuelPer100km"] as? Double) ?? (detail["dailyFuelPer100km"] as? Int).map { Double($0) } ?? 0
        let fuelPer100kmVal = (detail["fuelPer100km"] as? Double) ?? (detail["fuelPer100km"] as? Int).map { Double($0) } ?? 0
        let odometerVal = (detail["odometer"] as? Double) ?? (detail["odometer"] as? Int).map { Double($0) } ?? 0
        let kmVal = (detail["km"] as? Double) ?? (detail["km"] as? Int).map { Double($0) } ?? 0
        let batteryVal = (detail["battery"] as? Double)
            ?? (detail["battery_voltage"] as? Double)
            ?? (detail["battery"] as? Int).map { Double($0) }
            ?? (detail["battery_voltage"] as? Int).map { Double($0) }
        let externalVoltageVal = (detail["externalVoltage"] as? Double)
            ?? (detail["external_voltage"] as? Double)
            ?? (detail["externalVoltage"] as? Int).map { Double($0) }
            ?? (detail["external_voltage"] as? Int).map { Double($0) }
        let powerObj = detail["power"] as? [String: Any]
        let deviceBatteryVal: Double? = {
            if let v = detail["deviceBatteryLevelPct"] as? Double { return v }
            if let v = (detail["deviceBatteryLevelPct"] as? Int).map({ Double($0) }) { return v }
            if let v = detail["battery_level_pct"] as? Double { return v }
            if let v = (detail["battery_level_pct"] as? Int).map({ Double($0) }) { return v }
            if let v = detail["deviceBattery"] as? Double { return v }
            if let v = detail["device_battery"] as? Double { return v }
            if let v = (detail["deviceBattery"] as? Int).map({ Double($0) }) { return v }
            if let v = (detail["device_battery"] as? Int).map({ Double($0) }) { return v }
            if let pw = powerObj, let v = pw["device_battery_level_pct"] as? Double { return v }
            if let pw = powerObj, let v = (pw["device_battery_level_pct"] as? Int).map({ Double($0) }) { return v }
            return nil
        }()

        if dailyKmVal > 0 { vehicle.todayKm = Int(dailyKmVal); vehicle.dailyKm = dailyKmVal }
        if !groupNameVal.isEmpty && groupNameVal != "<null>" { vehicle.groupName = groupNameVal }
        if !vehicleBrandVal.isEmpty && vehicleBrandVal != "<null>" { vehicle.vehicleBrand = vehicleBrandVal }
        if !vehicleModelVal.isEmpty && vehicleModelVal != "<null>" { vehicle.vehicleModel = vehicleModelVal }
        if !addressVal.isEmpty && addressVal != "<null>" { vehicle.address = addressVal }
        if !cityVal.isEmpty && cityVal != "<null>" { vehicle.city = cityVal }
        if !fuelTypeVal.isEmpty && fuelTypeVal != "<null>" { vehicle.fuelType = fuelTypeVal }
        if dailyFuelLitersVal > 0 { vehicle.dailyFuelLiters = dailyFuelLitersVal }
        if dailyFuelPer100kmVal > 0 { vehicle.dailyFuelPer100km = dailyFuelPer100kmVal }
        if fuelPer100kmVal > 0 { vehicle.fuelPer100km = fuelPer100kmVal }
        if odometerVal > 0 { vehicle.totalKm = Int(odometerVal); vehicle.odometer = odometerVal }
        else if kmVal > 0 { vehicle.totalKm = Int(kmVal); vehicle.odometer = kmVal }
        if let v = batteryVal { vehicle.batteryVoltage = v }
        if let v = externalVoltageVal { vehicle.externalVoltage = v }
        if let v = deviceBatteryVal { vehicle.deviceBattery = v }

        // Ignition timestamps from API
        if let v = detail["first_ignition_on_at_today"] as? String, !v.isEmpty, v != "<null>" { vehicle.firstIgnitionOnAtToday = v }
        if let v = detail["last_ignition_on_at"] as? String, !v.isEmpty, v != "<null>" { vehicle.lastIgnitionOnAt = v }
        if let v = detail["last_ignition_off_at"] as? String, !v.isEmpty, v != "<null>" { vehicle.lastIgnitionOffAt = v }
    }

    private var hasFetchedDriverInfo = false

    private func subscribeToUpdates() {
        let targetId = vehicle.id
        let targetImei = vehicle.imei

        WebSocketManager.shared.$vehicleList
            .receive(on: DispatchQueue.main)
            .sink { [weak self] vehicles in
                guard let self = self else { return }
                if let updated = vehicles.first(where: { $0.id == targetId || (!targetImei.isEmpty && $0.imei == targetImei) }) {
                    // Merge WS update but preserve API-enriched fields
                    self.vehicle.mergeUpdate(from: updated)
                    // Use enriched driverName from WS manager if available
                    if !updated.driverName.isEmpty && self.driverName.isEmpty {
                        self.driverName = updated.driverName
                    }
                    // If deviceId became available and we haven't fetched yet, do it now
                    if !self.hasFetchedDriverInfo && updated.deviceId > 0 && self.driverName.isEmpty {
                        self.hasFetchedDriverInfo = true
                        self.fetchDriverInfo()
                    }
                }
            }
            .store(in: &cancellables)

        WebSocketManager.shared.eventSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                if case .update(let updatedVehicle, _) = event,
                   updatedVehicle.id == targetId || (!targetImei.isEmpty && updatedVehicle.imei == targetImei) {
                    self.vehicle.mergeUpdate(from: updatedVehicle)
                }
            }
            .store(in: &cancellables)
    }
}

struct VehicleDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var observer: VehicleDetailObserver
    @State private var selectedTab: DetailTab = .overview
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @State private var showDriverAssign = false
    @State private var showEditSheet = false
    @State private var showBlockageModal = false
    @State private var blockageLoading = false
    @State private var blockageError: String?
    @State private var blockageSuccess: String?

    // Fleet data states
    @State private var fleetMaintenances: [FleetMaintenance] = []
    @State private var fleetDocuments: [FleetDocument] = []
    @State private var fleetCosts: [FleetCost] = []
    @State private var isLoadingMaintenance = false
    @State private var isLoadingCosts = false

    /// Navigation callbacks for quick actions
    var onNavigateToRouteHistory: ((Vehicle) -> Void)?
    var onNavigateToAlarms: ((String) -> Void)?
    var onNavigateToAddAlarm: ((String) -> Void)?

    private var vehicle: Vehicle { observer.vehicle }

    init(vehicle: Vehicle, onNavigateToRouteHistory: ((Vehicle) -> Void)? = nil, onNavigateToAlarms: ((String) -> Void)? = nil, onNavigateToAddAlarm: ((String) -> Void)? = nil) {
        _observer = StateObject(wrappedValue: VehicleDetailObserver(vehicle: vehicle))
        self.onNavigateToRouteHistory = onNavigateToRouteHistory
        self.onNavigateToAlarms = onNavigateToAlarms
        self.onNavigateToAddAlarm = onNavigateToAddAlarm
    }

    enum DetailTab: String, CaseIterable {
        case overview = "Genel"
        case maintenance = "Bakım"
        case costs = "Masraf"
        case events = "Olaylar"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.darkBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Map Header
                        mapHeader

                        // Vehicle Identity Card
                        vehicleIdentityCard
                            .padding(.horizontal, 16)
                            .offset(y: -30)

                        // Tab Selector
                        tabSelector
                            .padding(.horizontal, 16)
                            .padding(.top, -14)

                        // Tab Content
                        Group {
                            switch selectedTab {
                            case .overview:
                                overviewTab
                            case .maintenance:
                                maintenanceTab
                            case .costs:
                                costsTab
                            case .events:
                                eventsTab
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.darkBg, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Geri")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(AppTheme.darkText)
                    }
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text(vehicle.plate)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.darkText)
                        Text("Araç Detayı")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.darkTextMuted)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if vehicle.isMotorcycle {
                        NavigationLink(destination: MotorcycleSettingsView(vehicle: vehicle)) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 18))
                                .foregroundColor(AppTheme.online)
                        }
                    }
                }
            }
            .onAppear {
                mapCameraPosition = .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: vehicle.lat, longitude: vehicle.lng),
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                ))
            }
        }
    }

    // MARK: - Map Header
    var mapHeader: some View {
        ZStack(alignment: .bottomTrailing) {
            Map(position: $mapCameraPosition) {
                Annotation(vehicle.plate, coordinate: CLLocationCoordinate2D(latitude: vehicle.lat, longitude: vehicle.lng)) {
                    VehicleMapPinDetail(vehicle: vehicle)
                }
            }
            .mapStyle(.standard(elevation: .flat))
            .frame(height: 200)
            .allowsHitTesting(false)

            // Status overlay
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(vehicle.status.color)
                        .frame(width: 7, height: 7)
                    Text(!vehicle.livenessStatus.isEmpty ? vehicle.livenessLabel : vehicle.status.label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(vehicle.status.color)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                // Kontak durumu badge kaldırıldı
            }
            .padding(12)
        }
    }

    // MARK: - Vehicle Identity Card
    var vehicleIdentityCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(vehicle.status.color.opacity(0.1))
                        .frame(width: 56, height: 56)
                    Image(systemName: vehicle.isMotorcycle ? "bicycle" : "car.fill")
                        .font(.system(size: 22))
                        .foregroundColor(vehicle.status.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(vehicle.plate)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(AppTheme.darkText)
                        StatusBadge(status: vehicle.status)
                    }
                    // name fieldı yorum satırına alındı
                    // Text(vehicle.model)
                    //     .font(.system(size: 13))
                    //     .foregroundColor(AppTheme.textMuted)

                    HStack(spacing: 6) {
                        vehicleTag(vehicle.group, icon: "folder.fill", color: .blue)
                        vehicleTag(vehicle.vehicleType, icon: vehicle.isMotorcycle ? "bicycle" : "car.2.fill", color: .purple)
                    }
                    .padding(.top, 2)
                }
                Spacer()
            }
            .padding(16)

            Divider()

            HStack(spacing: 0) {
                quickStatItem(icon: "speedometer", value: vehicle.formattedTotalKm, label: "Toplam Km", color: AppTheme.navy)
                Divider().frame(height: 40)
                quickStatItem(icon: "road.lanes", value: vehicle.formattedTodayKm, label: "Bugün", color: AppTheme.indigo)
                Divider().frame(height: 40)
                quickStatItem(icon: "person.fill", value: {
                    let name = !observer.driverName.isEmpty ? observer.driverName : (!vehicle.driverName.isEmpty ? vehicle.driverName : vehicle.driver)
                    return name.isEmpty ? "—" : (name.components(separatedBy: " ").first ?? "—")
                }(), label: "Sürücü", color: AppTheme.online)
                Divider().frame(height: 40)
                quickStatItem(icon: "mappin.circle.fill", value: vehicle.locationDisplay, label: "Konum", color: .orange)
            }
            .padding(.vertical, 12)
        }
        .background(AppTheme.darkSurface)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
    }

    func vehicleTag(_ text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 8))
            Text(text)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.08))
        .cornerRadius(20)
    }

    func quickStatItem(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppTheme.darkText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(AppTheme.darkTextMuted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tab Selector
    var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(DetailTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                }) {
                    VStack(spacing: 6) {
                        Text(tab.rawValue)
                            .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .medium))
                            .foregroundColor(selectedTab == tab ? AppTheme.darkText : AppTheme.darkTextMuted)

                        Rectangle()
                            .fill(selectedTab == tab ? AppTheme.lavender : Color.clear)
                            .frame(height: 2.5)
                            .cornerRadius(2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 8)
        .background(AppTheme.darkSurface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.darkBorder, lineWidth: 1)
        )
    }

    // MARK: - Overview Tab
    var overviewTab: some View {
        VStack(spacing: 16) {
            // ── Quick Actions Row (top, prominent) ──
            HStack(spacing: 10) {
                quickActionButton(icon: "location.fill", label: "Yol Tarifi", color: Color(hex: "#3B82F6")) {
                    openMapsDirections(lat: vehicle.lat, lng: vehicle.lng, label: vehicle.plate)
                }
                quickActionButton(icon: "clock.arrow.circlepath", label: "Rota Geçmişi", color: AppTheme.lavender) {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        onNavigateToRouteHistory?(vehicle)
                    }
                }
                quickActionButton(icon: "pencil.circle.fill", label: "Düzenle", color: Color(hex: "#8B5CF6")) {
                    showEditSheet = true
                }
                quickActionButton(icon: "lock.shield.fill", label: "Blokaj", color: .red) {
                    blockageError = nil
                    blockageSuccess = nil
                    showBlockageModal = true
                }
            }
            .padding(14)
            .background(AppTheme.darkSurface)
            .cornerRadius(14)
            .sheet(isPresented: $showEditSheet) {
                VehicleEditSheet(vehicle: vehicle) { updatedVehicle in
                    observer.vehicle.plate = updatedVehicle.plate
                    if !updatedVehicle.name.isEmpty { observer.vehicle.name = updatedVehicle.name }
                }
            }
            .sheet(isPresented: $showBlockageModal) {
                BlockageSheet(
                    vehicle: vehicle,
                    isLoading: $blockageLoading,
                    errorMessage: $blockageError,
                    successMessage: $blockageSuccess
                )
            }

            // ── Vehicle Info ──
            cleanListCard {
                detailRow(icon: "gauge.open.with.lines.needle.33percent", label: "Hız", value: vehicle.formattedSpeed)
                listDivider
                detailRow(icon: "mappin.circle.fill", label: "Konum", value: vehicle.locationDisplay)
                if vehicle.deviceTime != nil {
                    listDivider
                    detailRow(icon: "clock.fill", label: "Son Güncelleme", value: vehicle.formattedDeviceTime)
                }
                if vehicle.lastPacketAt != nil {
                    listDivider
                    detailRow(icon: "arrow.triangle.2.circlepath", label: "Son Paket", value: vehicle.formattedLastPacketAt)
                }
            }

            // ── Kontak & Güç ──
            cleanListCard {
                detailRow(
                    icon: vehicle.kontakOn ? "key.fill" : "key",
                    label: "Kontak",
                    value: vehicle.kontakLabel,
                    valueColor: vehicle.kontakOn ? AppTheme.online : AppTheme.offline
                )
                listDivider
                detailRow(icon: "sunrise.fill", label: "İlk Kontak (Bugün)", value: vehicle.formattedFirstIgnitionToday)
                listDivider
                detailRow(icon: "key.fill", label: "Son Kontak Açma", value: vehicle.formattedLastIgnitionOn)
                listDivider
                detailRow(icon: "key", label: "Son Kontak Kapama", value: vehicle.formattedLastIgnitionOff)
                listDivider
                
                if vehicle.deviceBattery != nil {
                    listDivider
                    detailRow(icon: "iphone", label: "Cihaz Bataryası", value: formatDeviceBattery(vehicle.deviceBattery))
                }
                if vehicle.externalVoltage != nil {
                    listDivider
                    detailRow(icon: "bolt.fill", label: "Harici Voltaj", value: formatVoltage(vehicle.externalVoltage))
                }
            }

            // ── Temperature & Sensors (conditional) ──
            if vehicle.temperatureC != nil || vehicle.humidityPct != nil {
                cleanListCard {
                    if let temp = vehicle.temperatureC {
                        detailRow(icon: "thermometer.medium", label: "Sıcaklık", value: String(format: "%.1f°C", temp))
                    }
                    if vehicle.temperatureC != nil && vehicle.humidityPct != nil {
                        listDivider
                    }
                    if let hum = vehicle.humidityPct {
                        detailRow(icon: "humidity.fill", label: "Nem", value: "%\(Int(hum))")
                    }
                }
            }

            // ── Yakıt & Maliyet ──
            if !vehicle.fuelType.isEmpty || vehicle.dailyFuelPer100km > 0 || vehicle.fuelPer100km > 0 {
                cleanListCard {
                    if !vehicle.fuelType.isEmpty {
                        detailRow(icon: "fuelpump.fill", label: "Yakıt Tipi", value: vehicle.fuelType)
                        listDivider
                    }
                    let rate = vehicle.dailyFuelPer100km > 0 ? vehicle.dailyFuelPer100km : vehicle.fuelPer100km
                    if rate > 0 {
                        detailRow(icon: "gauge.open.with.lines.needle.33percent", label: "Tüketim", value: String(format: "%.1f L/100km", rate))
                        listDivider
                    }
                    detailRow(icon: "drop.fill", label: "Bugün Tahmini Yakıt", value: vehicle.formattedDailyFuelLiters)
                    listDivider
                    detailRow(icon: "turkishlirasign.circle.fill", label: "Bugün Tahmini Maliyet", value: vehicle.formattedDailyFuelCost)
                }
            }

            // ── Driver ──
            let displayName = !observer.driverName.isEmpty ? observer.driverName : (!vehicle.driverName.isEmpty ? vehicle.driverName : "")
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.lavender.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Text(displayName.isEmpty ? "?" : String(displayName.prefix(1)))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(AppTheme.lavender)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName.isEmpty ? "Sürücü Atanmamış" : displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.darkText)
                    Text("Sürücü")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.darkTextMuted)
                }

                Spacer()

                Button(action: { showDriverAssign = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 11))
                        Text("Değiştir")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(AppTheme.lavender)
                }
            }
            .padding(16)
            .background(AppTheme.darkSurface)
            .cornerRadius(14)
            .sheet(isPresented: $showDriverAssign) {
                VehicleDriverAssignSheet(
                    vehicleId: vehicle.deviceId,
                    currentDriverName: !observer.driverName.isEmpty ? observer.driverName : vehicle.driverName,
                    onAssigned: {
                        observer.fetchDriverInfo()
                    }
                )
            }
        }
    }

    // ── Clean List Card ──
    func cleanListCard(@ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(AppTheme.darkSurface)
        .cornerRadius(14)
    }

    var listDivider: some View {
        Divider()
            .padding(.leading, 48)
            .padding(.trailing, 16)
    }

    func detailRow(icon: String, label: String, value: String, valueColor: Color? = nil) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.lavender.opacity(0.8))
                .frame(width: 18)
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.darkTextSub)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(valueColor ?? AppTheme.darkText)
                .lineLimit(1)
                .frame(maxWidth: 180, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    func quickActionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                    .frame(width: 42, height: 42)
                    .background(color.opacity(0.1))
                    .cornerRadius(12)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppTheme.darkTextMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Maintenance Tab
    var maintenanceTab: some View {
        VStack(spacing: 16) {
            if isLoadingMaintenance {
                ProgressView("Yükleniyor...")
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                // Maintenance section
                sectionCard(title: "BAKIM TAKVİMİ", icon: "wrench.and.screwdriver.fill") {
                    if fleetMaintenances.isEmpty {
                        HStack {
                            Image(systemName: "wrench.and.screwdriver")
                                .foregroundColor(AppTheme.darkTextMuted)
                            Text("Bu araç için bakım kaydı bulunmuyor")
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.darkTextMuted)
                        }
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(fleetMaintenances.enumerated()), id: \.element.id) { index, m in
                                let mStatus: MaintenanceStatus = m.status == "completed" ? .completed : (m.status == "overdue" ? .overdue : .upcoming)
                                maintenanceRow(
                                    icon: m.maintenanceType == "oil_change" ? "drop.fill" : (m.maintenanceType == "tire_change" ? "circle.circle.fill" : "wrench.fill"),
                                    title: m.title,
                                    date: m.scheduledDate,
                                    status: mStatus,
                                    km: m.currentKm > 0 ? "\(m.currentKm) km" : "—"
                                )
                                if index < fleetMaintenances.count - 1 {
                                    Divider().padding(.leading, 44)
                                }
                            }
                        }
                    }
                }

                // Documents section
                sectionCard(title: "BELGELER", icon: "doc.text.fill") {
                    if fleetDocuments.isEmpty {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(AppTheme.darkTextMuted)
                            Text("Bu araç için belge kaydı bulunmuyor")
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.darkTextMuted)
                        }
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(fleetDocuments.enumerated()), id: \.element.id) { index, doc in
                                let dStatus: DocStatus = doc.status == "expired" ? .critical : (doc.status == "expiring_soon" ? .warning : .normal)
                                let daysLeft = doc.daysUntilExpiry
                                documentRow(title: doc.docTypeLabel, date: doc.expiryDate ?? "—", daysLeft: daysLeft, status: dStatus)
                                if index < fleetDocuments.count - 1 {
                                    Divider().padding(.leading, 14)
                                }
                            }
                        }
                    }
                }
            }
        }
        .task {
            guard !isLoadingMaintenance else { return }
            isLoadingMaintenance = true
            do {
                let (maintenances, _) = try await APIService.shared.fetchFleetMaintenance(imei: vehicle.imei)
                fleetMaintenances = maintenances
                let (documents, _) = try await APIService.shared.fetchFleetDocuments(imei: vehicle.imei)
                fleetDocuments = documents
            } catch {
                print("[VehicleDetail] fleet maintenance/docs error: \(error)")
            }
            isLoadingMaintenance = false
        }
    }

    // MARK: - Costs Tab
    var costsTab: some View {
        VStack(spacing: 16) {
            if isLoadingCosts {
                ProgressView("Yükleniyor...")
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else if fleetCosts.isEmpty {
                sectionCard(title: "MASRAFLAR", icon: "chart.bar.fill") {
                    HStack {
                        Image(systemName: "banknote")
                            .foregroundColor(AppTheme.darkTextMuted)
                        Text("Bu araç için masraf kaydı bulunmuyor")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.darkTextMuted)
                    }
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                }
            } else {
                // Cost summary by category
                let categoryTotals = Dictionary(grouping: fleetCosts, by: { $0.category })
                    .mapValues { costs in costs.reduce(0.0) { $0 + $1.amount } }
                let totalAmount = fleetCosts.reduce(0.0) { $0 + $1.amount }
                let currency = fleetCosts.first?.currency ?? "TRY"

                sectionCard(title: "MASRAF ÖZETİ", icon: "chart.bar.fill") {
                    let sortedCats = categoryTotals.sorted { $0.value > $1.value }
                    HStack(spacing: 0) {
                        ForEach(sortedCats.prefix(4), id: \.key) { cat, amt in
                            let pct = totalAmount > 0 ? Int(amt / totalAmount * 100) : 0
                            costSummaryItem(
                                label: cat.capitalized,
                                amount: FleetCost.formatAmount(amt, currency: currency),
                                color: costCategoryColor(cat),
                                percent: pct
                            )
                        }
                    }
                    .padding(.vertical, 8)

                    HStack {
                        Text("TOPLAM")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(AppTheme.darkTextMuted)
                        Spacer()
                        Text(FleetCost.formatAmount(totalAmount, currency: currency))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppTheme.darkText)
                    }
                    .padding(14)
                    .background(AppTheme.darkCard)
                    .cornerRadius(10)
                }

                sectionCard(title: "SON MASRAFLAR", icon: "list.bullet.rectangle") {
                    VStack(spacing: 0) {
                        ForEach(Array(fleetCosts.enumerated()), id: \.element.id) { index, cost in
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(costCategoryColor(cost.category).opacity(0.1))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: costCategoryIcon(cost.category))
                                        .font(.system(size: 14))
                                        .foregroundColor(costCategoryColor(cost.category))
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cost.category.capitalized)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(AppTheme.darkText)
                                    Text(cost.costDate)
                                        .font(.system(size: 11))
                                        .foregroundColor(AppTheme.darkTextSub)
                                }

                                Spacer()

                                Text(cost.formattedAmount)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(AppTheme.darkText)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)

                            if index < fleetCosts.count - 1 {
                                Divider().padding(.leading, 62)
                            }
                        }
                    }
                }
            }
        }
        .task {
            guard !isLoadingCosts else { return }
            isLoadingCosts = true
            do {
                let (costs, _) = try await APIService.shared.fetchFleetCosts(imei: vehicle.imei)
                fleetCosts = costs
            } catch {
                print("[VehicleDetail] fleet costs error: \(error)")
            }
            isLoadingCosts = false
        }
    }

    // MARK: - Events Tab
    var eventsTab: some View {
        EventsTabContent(vehicle: observer.vehicle, onNavigateToAlarms: onNavigateToAlarms)
    }

    // MARK: - Helper Views

    func formatVoltage(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.2f V", value)
    }

    func formatDeviceBattery(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value <= 100 ? "%\(Int(value))" : String(format: "%.2f V", value)
    }

    func sectionCard(title: String, icon: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.lavender)
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppTheme.darkTextMuted)
                    .tracking(0.5)
                Spacer()
            }
            content()
        }
        .padding(16)
        .background(AppTheme.darkSurface)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.darkBorder, lineWidth: 1)
        )
    }

    func infoCell(icon: String, label: String, value: String, valueColor: Color? = nil) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(AppTheme.lavender)
                .frame(width: 26, height: 26)
                .background(AppTheme.lavender.opacity(0.12))
                .cornerRadius(7)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(AppTheme.darkTextMuted)
                    .tracking(0.3)
                Text(value)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(valueColor ?? AppTheme.darkText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer()
        }
        .padding(10)
        .background(AppTheme.darkCard)
        .cornerRadius(10)
    }

    func actionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundColor(color)
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.08))
                    .cornerRadius(12)
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(AppTheme.darkTextMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // Maintenance helpers
    enum MaintenanceStatus {
        case completed, upcoming, normal, overdue

        var color: Color {
            switch self {
            case .completed: return AppTheme.online
            case .upcoming: return .orange
            case .normal: return .blue
            case .overdue: return .red
            }
        }

        var label: String {
            switch self {
            case .completed: return "Tamamlandı"
            case .upcoming: return "Yaklaşıyor"
            case .normal: return "Planlandı"
            case .overdue: return "Gecikmiş"
            }
        }
    }

    func maintenanceRow(icon: String, title: String, date: String, status: MaintenanceStatus, km: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(status.color.opacity(0.1))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(status.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.darkText)
                HStack(spacing: 8) {
                    Text(date)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.darkTextSub)
                    Text("•")
                        .font(.system(size: 8))
                        .foregroundColor(AppTheme.darkTextMuted)
                    Text(km)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.darkTextSub)
                }
            }

            Spacer()

            Text(status.label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(status.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(status.color.opacity(0.1))
                .cornerRadius(20)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
    }

    enum DocStatus {
        case normal, warning, critical

        var color: Color {
            switch self {
            case .normal: return AppTheme.online
            case .warning: return .orange
            case .critical: return .red
            }
        }
    }

    func documentRow(title: String, date: String, daysLeft: Int, status: DocStatus) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.darkText)
                Text("Bitiş: \(date)")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.darkTextSub)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(daysLeft) gün")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(status.color)
                Text("kalan")
                    .font(.system(size: 9))
                    .foregroundColor(AppTheme.darkTextMuted)
            }

            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
    }

    func costSummaryItem(label: String, amount: String, color: Color, percent: Int) -> some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 60)
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: 32, height: CGFloat(percent) / 100.0 * 60.0)
            }
            Text(amount)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(AppTheme.darkText)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(AppTheme.darkTextMuted)
        }
        .frame(maxWidth: .infinity)
    }

    func costCategoryColor(_ category: String) -> Color {
        switch category {
        case "Yakıt": return .orange
        case "Bakım": return .blue
        case "Sigorta": return .purple
        default: return AppTheme.textMuted
        }
    }

    func costCategoryIcon(_ category: String) -> String {
        switch category {
        case "Yakıt": return "fuelpump.fill"
        case "Bakım": return "wrench.fill"
        case "Sigorta": return "shield.fill"
        default: return "ellipsis"
        }
    }

    // MARK: - Open Maps Directions
private func openMapsDirections(lat: Double, lng: Double, label: String) {
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = label
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    // MARK: - Share Vehicle Location
    private func shareVehicleLocation(vehicle: Vehicle) {
        let mapsURL = "https://www.google.com/maps?q=\(vehicle.lat),\(vehicle.lng)"
        let message = """
        📍 \(vehicle.plate) - Anlık Konum
        🚗 \(vehicle.model)
        📊 Hız: \(vehicle.formattedSpeed)
        🔑 \(vehicle.kontakLabel)
        🗺️ \(mapsURL)
        """
        let activityVC = UIActivityViewController(activityItems: [message.trimmingCharacters(in: .whitespaces)], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController { topVC = presented }
            activityVC.popoverPresentationController?.sourceView = topVC.view
            topVC.present(activityVC, animated: true)
        }
    }

    func eventRow(icon: String, title: String, subtitle: String, time: String, severity: AlertSeverity) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(severity.color.opacity(0.1))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(severity.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.darkText)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.darkTextSub)
            }

            Spacer()

            Text(time)
                .font(.system(size: 10))
                .foregroundColor(AppTheme.darkTextMuted)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
    }
}

// MARK: - Vehicle Map Pin for Detail
struct VehicleMapPinDetail: View {
    let vehicle: Vehicle

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(vehicle.status.color)
                    .frame(width: 36, height: 36)
                    .shadow(color: vehicle.status.color.opacity(0.4), radius: 6, y: 2)
                Image(systemName: "car.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            }

            Text(vehicle.plate)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(AppTheme.navy)
                .cornerRadius(4)
                .offset(y: 2)
        }
    }
}

// MARK: - Events Tab Content (fetches real alarms)
struct EventsTabContent: View {
    let vehicle: Vehicle
    var onNavigateToAlarms: ((String) -> Void)?
    @State private var alarms: [AlarmEvent] = []
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 16) {
            sectionCard(title: "SON OLAYLAR", icon: "clock.fill") {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding(24)
                        Spacer()
                    }
                } else if alarms.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 28))
                            .foregroundColor(AppTheme.darkTextMuted)
                        Text("Bu araç için alarm bulunamadı")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.darkTextMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(alarms.enumerated()), id: \.element.id) { index, alarm in
                            eventRow(
                                icon: alarm.icon,
                                title: alarm.typeLabel,
                                subtitle: alarm.description.isEmpty ? alarm.plate : alarm.description,
                                time: alarm.formattedDate,
                                severity: alarmSeverity(alarm)
                            )
                            if index < alarms.count - 1 {
                                Divider().padding(.leading, 48)
                            }
                        }
                    }

                    // "Tümünü Gör" button
                    if let onNavigateToAlarms = onNavigateToAlarms {
                        Button(action: {
                            onNavigateToAlarms(vehicle.plate)
                        }) {
                            HStack(spacing: 6) {
                                Text("Tümünü Gör")
                                    .font(.system(size: 13, weight: .semibold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(AppTheme.lavender)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(AppTheme.lavender.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
        .task {
            await fetchAlarms()
        }
    }

    private func alarmSeverity(_ alarm: AlarmEvent) -> AlertSeverity {
        let key = alarm.alarmKey.lowercased()
        if key.contains("gf_") || key.contains("geofence") { return .green }
        if key.contains("t_towing") || key.contains("sos") { return .red }
        if key.contains("t_movement") { return .amber }
        return .blue
    }

    private func fetchAlarms() async {
        do {
            let json = try await APIService.shared.get("/api/mobile/alarms?page=1&per_page=20&imei=\(vehicle.imei)")
            let dataArr = json["data"] as? [[String: Any]] ?? []
            let results = dataArr.enumerated().compactMap { (i, dict) -> AlarmEvent? in
                let a = AlarmEvent.from(json: dict, index: i)
                guard a.imei == vehicle.imei || a.plate == vehicle.plate else { return nil }
                return a
            }
            alarms = Array(results.prefix(10))
        } catch {
            alarms = []
        }
        isLoading = false
    }

    func sectionCard(title: String, icon: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.lavender)
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppTheme.darkTextMuted)
                    .tracking(0.5)
                Spacer()
            }
            content()
        }
        .padding(16)
        .background(AppTheme.darkSurface)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.darkBorder, lineWidth: 1)
        )
    }

    func eventRow(icon: String, title: String, subtitle: String, time: String, severity: AlertSeverity) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(severity.color.opacity(0.1))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(severity.color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.darkText)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.darkTextSub)
            }
            Spacer()
            Text(time)
                .font(.system(size: 10))
                .foregroundColor(AppTheme.darkTextMuted)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
    }
}

struct VehicleDetailAlternativeView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var observer: VehicleDetailObserver
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @State private var selectedTab: AlternativeDetailTab = .overview
    @State private var showEditSheet = false
    @State private var showBlockageModal = false
    @State private var blockageLoading = false
    @State private var blockageError: String?
    @State private var blockageSuccess: String?
    @State private var showDriverAssign = false
    @State private var fleetMaintenances: [FleetMaintenance] = []
    @State private var fleetDocuments: [FleetDocument] = []
    @State private var fleetCosts: [FleetCost] = []
    @State private var alarms: [AlarmEvent] = []
    @State private var isLoadingMaintenance = false
    @State private var isLoadingCosts = false
    @State private var isLoadingEvents = false

    var onNavigateToRouteHistory: ((Vehicle) -> Void)?
    var onNavigateToAlarms: ((String) -> Void)?
    var onNavigateToAddAlarm: ((String) -> Void)?

    private var vehicle: Vehicle { observer.vehicle }
    private let pageBackground = Color(red: 243/255, green: 246/255, blue: 251/255)
    private let sectionBackground = Color.white
    private let sectionBorder = Color(red: 221/255, green: 228/255, blue: 238/255)
    private let subduedText = Color(red: 98/255, green: 108/255, blue: 131/255)
    private let accentLine = Color(red: 18/255, green: 41/255, blue: 86/255)
    private let softAccent = Color(red: 231/255, green: 237/255, blue: 247/255)

    enum AlternativeDetailTab: String, CaseIterable {
        case overview = "Genel"
        case maintenance = "Bakım"
        case costs = "Masraf"
        case events = "Olaylar"
    }

    enum AlternativeMaintenanceStatus {
        case completed, upcoming, overdue

        var color: Color {
            switch self {
            case .completed: return AppTheme.online
            case .upcoming: return .orange
            case .overdue: return .red
            }
        }

        var label: String {
            switch self {
            case .completed: return "Tamamlandı"
            case .upcoming: return "Yaklaşıyor"
            case .overdue: return "Gecikmiş"
            }
        }
    }

    enum AlternativeDocumentStatus {
        case normal, warning, critical

        var color: Color {
            switch self {
            case .normal: return AppTheme.online
            case .warning: return .orange
            case .critical: return .red
            }
        }
    }

    init(vehicle: Vehicle, onNavigateToRouteHistory: ((Vehicle) -> Void)? = nil, onNavigateToAlarms: ((String) -> Void)? = nil, onNavigateToAddAlarm: ((String) -> Void)? = nil) {
        _observer = StateObject(wrappedValue: VehicleDetailObserver(vehicle: vehicle))
        self.onNavigateToRouteHistory = onNavigateToRouteHistory
        self.onNavigateToAlarms = onNavigateToAlarms
        self.onNavigateToAddAlarm = onNavigateToAddAlarm
    }

    var body: some View {
        ZStack {
            pageBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    heroCard
                    compactMetricsStrip
                    mapCard
                    tabBar
                    tabContent
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Araçlar")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(AppTheme.textPrimary)
                }
            }

            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(vehicle.plate)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Araç Detayı")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.textMuted)
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Text(vehicle.livenessLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(vehicle.status.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(vehicle.status.color.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .toolbarBackground(.white, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            mapCameraPosition = .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: vehicle.lat, longitude: vehicle.lng),
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
            )
            loadSupplementaryData()
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Araç Genel Durumu")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(subduedText)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(vehicle.plate)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)

                        Text(primaryVehicleName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)

                        Text(vehicleLocationText)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(subduedText)
                            .lineLimit(2)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 10) {
                    statusBadge

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(vehicle.formattedSpeed)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(accentLine)
                        Text("Anlık Hız")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(subduedText)
                    }
                }
            }

            Rectangle()
                .fill(sectionBorder)
                .frame(height: 1)

            HStack(spacing: 12) {
                heroMetric(title: "Sürücü", value: currentDriverName)
                heroMetric(title: "Şehir", value: vehicle.city.isEmpty ? "Belirsiz" : vehicle.city)
                heroMetric(title: "Yakıt", value: vehicle.fuelType.isEmpty ? "Tanımsız" : vehicle.fuelType)
            }
        }
        .padding(20)
        .background(sectionBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(sectionBorder, lineWidth: 1)
        )
    }

    private var statusBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(vehicle.status.color)
                .frame(width: 10, height: 10)
            Text(vehicle.kontakLabel)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(vehicle.livenessLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(subduedText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(vehicle.status.color.opacity(0.12))
        .clipShape(Capsule())
    }

    private func heroMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(subduedText)

            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(pageBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var compactMetricsStrip: some View {
        HStack(spacing: 12) {
            summaryItem(title: "Bugün", value: vehicle.formattedTodayKm)
            summaryItem(title: "Toplam KM", value: vehicle.formattedTotalKm + " km")
            summaryItem(title: "Son Veri", value: vehicle.formattedLastPacketAt)
        }
    }

    private func summaryItem(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(subduedText)

            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(sectionBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(sectionBorder, lineWidth: 1)
        )
    }

    private var mapCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Konum Bilgisi", subtitle: vehicle.formattedDeviceTime)

            Map(position: $mapCameraPosition) {
                Annotation(vehicle.plate, coordinate: CLLocationCoordinate2D(latitude: vehicle.lat, longitude: vehicle.lng)) {
                    VStack(spacing: 6) {
                        Image(systemName: vehicle.mapIcon)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(vehicle.status.color)
                            .clipShape(Circle())

                        Text(vehicle.plate)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.navy)
                            .clipShape(Capsule())
                    }
                }
            }
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .padding(18)
        .background(sectionBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(sectionBorder, lineWidth: 1)
        )
    }

    private var tabBar: some View {
        HStack(spacing: 8) {
            ForEach(AlternativeDetailTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .medium))
                        .foregroundStyle(selectedTab == tab ? .white : accentLine)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedTab == tab ? accentLine : softAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .overview:
            overviewContent
        case .maintenance:
            maintenanceContent
        case .costs:
            costsContent
        case .events:
            eventsContent
        }
    }

    private var overviewContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            compactActionsCard
            overviewInfoCard
            ignitionInfoCard
            if vehicle.temperatureC != nil || vehicle.humidityPct != nil {
                sensorInfoCard
            }
            fuelInfoCard
            driverInfoCard
        }
    }

    private var maintenanceContent: some View {
        VStack(spacing: 14) {
            alternativeSectionCard(title: "Bakım Takvimi", subtitle: "Planlı bakım ve servis bilgileri") {
                if isLoadingMaintenance {
                    compactProgressRow
                } else if fleetMaintenances.isEmpty {
                    emptyStateRow(text: "Bu araç için bakım kaydı bulunmuyor")
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(fleetMaintenances.enumerated()), id: \.element.id) { index, m in
                            let mStatus: AlternativeMaintenanceStatus = m.status == "completed" ? .completed : (m.status == "overdue" ? .overdue : .upcoming)
                            compactTimelineRow(
                                title: m.title,
                                subtitle: "\(m.scheduledDate) • \(m.currentKm > 0 ? "\(m.currentKm) km" : "—")",
                                badge: mStatus.label,
                                badgeColor: mStatus.color,
                                icon: m.maintenanceType == "oil_change" ? "drop.fill" : (m.maintenanceType == "tire_change" ? "circle.circle.fill" : "wrench.fill")
                            )
                            if index < fleetMaintenances.count - 1 { sectionDivider }
                        }
                    }
                }
            }

            alternativeSectionCard(title: "Belgeler", subtitle: "Süre ve geçerlilik bilgileri") {
                if isLoadingMaintenance {
                    compactProgressRow
                } else if fleetDocuments.isEmpty {
                    emptyStateRow(text: "Bu araç için belge kaydı bulunmuyor")
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(fleetDocuments.enumerated()), id: \.element.id) { index, doc in
                            let dStatus: AlternativeDocumentStatus = doc.status == "expired" ? .critical : (doc.status == "expiring_soon" ? .warning : .normal)
                            compactTimelineRow(
                                title: doc.docTypeLabel,
                                subtitle: "Bitiş: \(doc.expiryDate ?? "—")",
                                badge: "\(doc.daysUntilExpiry) gün",
                                badgeColor: dStatus.color,
                                icon: "doc.text.fill"
                            )
                            if index < fleetDocuments.count - 1 { sectionDivider }
                        }
                    }
                }
            }
        }
    }

    private var costsContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            alternativeSectionCard(title: "Masraf Özeti", subtitle: "Kategori bazlı maliyet görünümü") {
                if isLoadingCosts {
                    compactProgressRow
                } else if fleetCosts.isEmpty {
                    emptyStateRow(text: "Bu araç için masraf kaydı bulunmuyor")
                } else {
                    let categoryTotals = Dictionary(grouping: fleetCosts, by: { $0.category })
                        .mapValues { costs in costs.reduce(0.0) { $0 + $1.amount } }
                    let totalAmount = fleetCosts.reduce(0.0) { $0 + $1.amount }
                    let currency = fleetCosts.first?.currency ?? "TRY"

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(categoryTotals.sorted(by: { $0.value > $1.value }), id: \.key) { cat, amt in
                            compactStatCard(
                                title: cat.capitalized,
                                value: FleetCost.formatAmount(amt, currency: currency),
                                note: totalAmount > 0 ? "%\(Int((amt / totalAmount) * 100))" : "%0",
                                icon: costCategoryIcon(cat),
                                accent: costCategoryColor(cat)
                            )
                        }
                    }
                }
            }

            alternativeSectionCard(title: "Son Masraflar", subtitle: "Güncel harcama kayıtları") {
                if isLoadingCosts {
                    compactProgressRow
                } else if fleetCosts.isEmpty {
                    emptyStateRow(text: "Masraf listesi boş")
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(fleetCosts.enumerated()), id: \.element.id) { index, cost in
                            compactTimelineRow(
                                title: cost.category.capitalized,
                                subtitle: cost.costDate,
                                badge: cost.formattedAmount,
                                badgeColor: costCategoryColor(cost.category),
                                icon: costCategoryIcon(cost.category)
                            )
                            if index < fleetCosts.count - 1 { sectionDivider }
                        }
                    }
                }
            }
        }
    }

    private var eventsContent: some View {
        alternativeSectionCard(title: "Son Olaylar", subtitle: "Alarm ve olay hareketleri") {
            if isLoadingEvents {
                compactProgressRow
            } else if alarms.isEmpty {
                emptyStateRow(text: "Bu araç için olay kaydı bulunmuyor")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(alarms.enumerated()), id: \.element.id) { index, alarm in
                        compactTimelineRow(
                            title: alarm.typeLabel,
                            subtitle: alarm.description.isEmpty ? alarm.plate : alarm.description,
                            badge: alarm.formattedDate,
                            badgeColor: alternativeAlarmSeverity(alarm).color,
                            icon: alarm.icon
                        )
                        if index < alarms.count - 1 { sectionDivider }
                    }
                }

                if let onNavigateToAlarms = onNavigateToAlarms {
                    Button {
                        onNavigateToAlarms(vehicle.plate)
                    } label: {
                        Text("Tüm Alarmları Aç")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(accentLine)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(softAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 10)
                }
            }
        }
    }

    private var compactActionsCard: some View {
        alternativeSectionCard(title: "Hızlı İşlemler", subtitle: "Sık kullanılan detay aksiyonları") {
            HStack(spacing: 8) {
                compactActionButton(title: "Yol Tarifi", icon: "location.fill", tint: .blue) {
                    openMapsDirections(lat: vehicle.lat, lng: vehicle.lng, label: vehicle.plate)
                }
                compactActionButton(title: "Rota", icon: "clock.arrow.circlepath", tint: AppTheme.indigo) {
                    onNavigateToRouteHistory?(vehicle)
                }
                compactActionButton(title: "Düzenle", icon: "pencil.circle.fill", tint: .purple) {
                    showEditSheet = true
                }
                compactActionButton(title: "Blokaj", icon: "lock.shield.fill", tint: .red) {
                    blockageError = nil
                    blockageSuccess = nil
                    showBlockageModal = true
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            VehicleEditSheet(vehicle: vehicle) { updatedVehicle in
                observer.vehicle.plate = updatedVehicle.plate
                if !updatedVehicle.name.isEmpty { observer.vehicle.name = updatedVehicle.name }
            }
        }
        .sheet(isPresented: $showBlockageModal) {
            BlockageSheet(
                vehicle: vehicle,
                isLoading: $blockageLoading,
                errorMessage: $blockageError,
                successMessage: $blockageSuccess
            )
        }
    }

    private var overviewInfoCard: some View {
        alternativeSectionCard(title: "Araç Bilgileri", subtitle: "Canlı konum ve cihaz zaman bilgisi") {
            compactInfoRow(icon: "speedometer", label: "Hız", value: vehicle.formattedSpeed)
            sectionDivider
            compactInfoRow(icon: "mappin.circle.fill", label: "Konum", value: vehicleLocationText)
            if vehicle.deviceTime != nil {
                sectionDivider
                compactInfoRow(icon: "clock.fill", label: "Son Güncelleme", value: vehicle.formattedDeviceTime)
            }
            if vehicle.lastPacketAt != nil {
                sectionDivider
                compactInfoRow(icon: "arrow.triangle.2.circlepath", label: "Son Paket", value: vehicle.formattedLastPacketAt)
            }
        }
    }

    private var ignitionInfoCard: some View {
        alternativeSectionCard(title: "Kontak ve Güç", subtitle: "Kontak hareketleri ve enerji değerleri") {
            compactInfoRow(icon: vehicle.kontakOn ? "key.fill" : "key", label: "Kontak", value: vehicle.kontakLabel, valueColor: vehicle.kontakOn ? AppTheme.online : AppTheme.offline)
            sectionDivider
            compactInfoRow(icon: "sunrise.fill", label: "İlk Kontak", value: vehicle.formattedFirstIgnitionToday)
            sectionDivider
            compactInfoRow(icon: "play.circle.fill", label: "Son Kontak Açma", value: vehicle.formattedLastIgnitionOn)
            sectionDivider
            compactInfoRow(icon: "pause.circle.fill", label: "Son Kontak Kapama", value: vehicle.formattedLastIgnitionOff)
            if vehicle.deviceBattery != nil {
                sectionDivider
                compactInfoRow(icon: "iphone", label: "Cihaz Bataryası", value: formattedBattery(vehicle.deviceBattery))
            }
            if vehicle.externalVoltage != nil {
                sectionDivider
                compactInfoRow(icon: "bolt.fill", label: "Harici Voltaj", value: formattedVoltage(vehicle.externalVoltage))
            }
            if vehicle.batteryVoltage != nil {
                sectionDivider
                compactInfoRow(icon: "car.rear.and.tire.marks", label: "Akü Voltajı", value: formattedVoltage(vehicle.batteryVoltage))
            }
        }
    }

    private var sensorInfoCard: some View {
        alternativeSectionCard(title: "Sensör Verileri", subtitle: "Araçtan gelen çevresel bilgiler") {
            if let temp = vehicle.temperatureC {
                compactInfoRow(icon: "thermometer.medium", label: "Sıcaklık", value: String(format: "%.1f°C", temp))
            }
            if vehicle.temperatureC != nil && vehicle.humidityPct != nil {
                sectionDivider
            }
            if let humidity = vehicle.humidityPct {
                compactInfoRow(icon: "humidity.fill", label: "Nem", value: "%\(Int(humidity))")
            }
        }
    }

    private var fuelInfoCard: some View {
        alternativeSectionCard(title: "Yakıt ve Maliyet", subtitle: "Günlük tüketim ve tahmini harcama") {
            compactInfoRow(icon: "fuelpump.fill", label: "Yakıt Tipi", value: vehicle.fuelType.isEmpty ? "Tanımsız" : vehicle.fuelType)
            sectionDivider
            compactInfoRow(
                icon: "gauge.open.with.lines.needle.33percent",
                label: "Tüketim",
                value: {
                    let rate = vehicle.dailyFuelPer100km > 0 ? vehicle.dailyFuelPer100km : vehicle.fuelPer100km
                    return rate > 0 ? String(format: "%.1f L/100km", rate) : "—"
                }()
            )
            sectionDivider
            compactInfoRow(icon: "drop.fill", label: "Bugün Tahmini Yakıt", value: vehicle.formattedDailyFuelLiters)
            sectionDivider
            compactInfoRow(icon: "turkishlirasign.circle.fill", label: "Bugün Tahmini Maliyet", value: vehicle.formattedDailyFuelCost)
        }
    }

    private var driverInfoCard: some View {
        alternativeSectionCard(title: "Sürücü Bilgisi", subtitle: "Atama ve temel sürücü görünümü") {
            HStack(spacing: 12) {
                Circle()
                    .fill(softAccent)
                    .frame(width: 34, height: 34)
                    .overlay(
                        Text(currentDriverName.isEmpty ? "?" : String(currentDriverName.prefix(1)))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(accentLine)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(currentDriverName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    if !observer.driverPhone.isEmpty {
                        Text(observer.driverPhone)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(subduedText)
                    }
                }

                Spacer()

                Button {
                    showDriverAssign = true
                } label: {
                    Text("Değiştir")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(accentLine)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(softAccent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showDriverAssign) {
            VehicleDriverAssignSheet(
                vehicleId: vehicle.deviceId,
                currentDriverName: currentDriverName == "Sürücü Atanmamış" ? "" : currentDriverName,
                onAssigned: {
                    observer.fetchDriverInfo()
                }
            )
        }
    }

    private func compactActionButton(title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(subduedText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func alternativeSectionCard(title: String, subtitle: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader(title: title, subtitle: subtitle)
                .padding(.bottom, 8)
            content()
        }
        .padding(16)
        .background(sectionBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(sectionBorder, lineWidth: 1)
        )
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Text(subtitle.isEmpty ? "Veri bekleniyor" : subtitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(subduedText)
        }
    }

    private func compactInfoRow(icon: String, label: String, value: String, valueColor: Color? = nil) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accentLine)
                .frame(width: 18)

            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(subduedText)

            Spacer()

            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(valueColor ?? AppTheme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 9)
    }

    private func compactTimelineRow(title: String, subtitle: String, badge: String, badgeColor: Color, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(badgeColor)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(subduedText)
            }

            Spacer()

            Text(badge)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(badgeColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(badgeColor.opacity(0.10))
                .clipShape(Capsule())
        }
        .padding(.vertical, 9)
    }

    private func compactStatCard(title: String, value: String, note: String, icon: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(accent)
                Spacer()
                Text(note)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(accent)
            }

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(subduedText)

            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(12)
        .background(pageBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var compactProgressRow: some View {
        HStack {
            Spacer()
            ProgressView()
                .padding(.vertical, 18)
            Spacer()
        }
    }

    private func emptyStateRow(text: String) -> some View {
        HStack {
            Spacer()
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(subduedText)
                .padding(.vertical, 16)
            Spacer()
        }
    }

    private var sectionDivider: some View {
        Divider()
            .padding(.leading, 28)
    }

    private var primaryVehicleName: String {
        if !vehicle.vehicleBrand.isEmpty || !vehicle.vehicleModel.isEmpty {
            return [vehicle.vehicleBrand, vehicle.vehicleModel].filter { !$0.isEmpty }.joined(separator: " ")
        }
        return vehicle.model
    }

    private var vehicleLocationText: String {
        if !vehicle.address.isEmpty { return vehicle.address }
        if !vehicle.city.isEmpty { return vehicle.city }
        return "Konum bilgisi bekleniyor"
    }

    private var currentDriverName: String {
        let name = !observer.driverName.isEmpty ? observer.driverName : (!vehicle.driverName.isEmpty ? vehicle.driverName : vehicle.driver)
        return name.isEmpty ? "Sürücü Atanmamış" : name
    }

    private func loadSupplementaryData() {
        if !isLoadingMaintenance && fleetMaintenances.isEmpty && fleetDocuments.isEmpty {
            isLoadingMaintenance = true
            Task {
                do {
                    let (maintenances, _) = try await APIService.shared.fetchFleetMaintenance(imei: vehicle.imei)
                    let (documents, _) = try await APIService.shared.fetchFleetDocuments(imei: vehicle.imei)
                    await MainActor.run {
                        fleetMaintenances = maintenances
                        fleetDocuments = documents
                        isLoadingMaintenance = false
                    }
                } catch {
                    await MainActor.run {
                        isLoadingMaintenance = false
                    }
                }
            }
        }

        if !isLoadingCosts && fleetCosts.isEmpty {
            isLoadingCosts = true
            Task {
                do {
                    let (costs, _) = try await APIService.shared.fetchFleetCosts(imei: vehicle.imei)
                    await MainActor.run {
                        fleetCosts = costs
                        isLoadingCosts = false
                    }
                } catch {
                    await MainActor.run {
                        isLoadingCosts = false
                    }
                }
            }
        }

        if !isLoadingEvents && alarms.isEmpty {
            isLoadingEvents = true
            Task {
                do {
                    let json = try await APIService.shared.get("/api/mobile/alarms?page=1&per_page=20&imei=\(vehicle.imei)")
                    let dataArr = json["data"] as? [[String: Any]] ?? []
                    let results = dataArr.enumerated().compactMap { (i, dict) -> AlarmEvent? in
                        let alarm = AlarmEvent.from(json: dict, index: i)
                        guard alarm.imei == vehicle.imei || alarm.plate == vehicle.plate else { return nil }
                        return alarm
                    }
                    await MainActor.run {
                        alarms = Array(results.prefix(10))
                        isLoadingEvents = false
                    }
                } catch {
                    await MainActor.run {
                        isLoadingEvents = false
                    }
                }
            }
        }
    }

    private func alternativeAlarmSeverity(_ alarm: AlarmEvent) -> AlertSeverity {
        let key = alarm.alarmKey.lowercased()
        if key.contains("gf_") || key.contains("geofence") { return .green }
        if key.contains("t_towing") || key.contains("sos") { return .red }
        if key.contains("t_movement") { return .amber }
        return .blue
    }

    private func costCategoryColor(_ category: String) -> Color {
        switch category {
        case "Yakıt": return .orange
        case "Bakım": return .blue
        case "Sigorta": return .purple
        default: return AppTheme.textMuted
        }
    }

    private func costCategoryIcon(_ category: String) -> String {
        switch category {
        case "Yakıt": return "fuelpump.fill"
        case "Bakım": return "wrench.fill"
        case "Sigorta": return "shield.fill"
        default: return "ellipsis"
        }
    }

    private func openMapsDirections(lat: Double, lng: Double, label: String) {
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = label
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    private func formattedVoltage(_ value: Double?) -> String {
        guard let value = value, value > 0 else { return "—" }
        return String(format: "%.2f V", value)
    }

    private func formattedBattery(_ value: Double?) -> String {
        guard let value = value, value > 0 else { return "—" }
        return value <= 100 ? "%\(Int(value))" : String(format: "%.2f V", value)
    }
}

struct VehicleDetailThirdView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var observer: VehicleDetailObserver
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @State private var selectedTab: PremiumDetailTab = .overview
    @State private var showEditSheet = false
    @State private var showBlockageModal = false
    @State private var blockageLoading = false
    @State private var blockageError: String?
    @State private var blockageSuccess: String?
    @State private var showDriverAssign = false
    @State private var fleetMaintenances: [FleetMaintenance] = []
    @State private var fleetDocuments: [FleetDocument] = []
    @State private var fleetCosts: [FleetCost] = []
    @State private var alarms: [AlarmEvent] = []
    @State private var isLoadingMaintenance = false
    @State private var isLoadingCosts = false
    @State private var isLoadingEvents = false

    var onNavigateToRouteHistory: ((Vehicle) -> Void)?
    var onNavigateToAlarms: ((String) -> Void)?
    var onNavigateToAddAlarm: ((String) -> Void)?
    var onSwitchAppTab: ((AppTab) -> Void)?

    private var vehicle: Vehicle { observer.vehicle }
    private let pageBackground = Color(UIColor.systemGroupedBackground)
    private let cardBorder = Color(red: 208/255, green: 216/255, blue: 232/255)
    private let navy = Color(red: 10/255, green: 22/255, blue: 56/255)
    private let brightBlue = Color(red: 33/255, green: 111/255, blue: 237/255)
    private let mint = Color(red: 20/255, green: 165/255, blue: 130/255)
    private let alertRed = Color(red: 219/255, green: 56/255, blue: 74/255)

    enum PremiumDetailTab: String, CaseIterable {
        case overview = "Genel"
        case maintenance = "Bakım"
        case costs = "Masraf"
        case events = "Olaylar"
    }

    enum PremiumMaintenanceStatus {
        case completed, upcoming, overdue

        var color: Color {
            switch self {
            case .completed: return AppTheme.online
            case .upcoming: return .orange
            case .overdue: return .red
            }
        }

        var label: String {
            switch self {
            case .completed: return "Tamamlandı"
            case .upcoming: return "Yaklaşıyor"
            case .overdue: return "Gecikmiş"
            }
        }
    }

    enum PremiumDocumentStatus {
        case normal, warning, critical

        var color: Color {
            switch self {
            case .normal: return AppTheme.online
            case .warning: return .orange
            case .critical: return .red
            }
        }
    }

    init(
        vehicle: Vehicle,
        onNavigateToRouteHistory: ((Vehicle) -> Void)? = nil,
        onNavigateToAlarms: ((String) -> Void)? = nil,
        onNavigateToAddAlarm: ((String) -> Void)? = nil,
        onSwitchAppTab: ((AppTab) -> Void)? = nil
    ) {
        _observer = StateObject(wrappedValue: VehicleDetailObserver(vehicle: vehicle))
        self.onNavigateToRouteHistory = onNavigateToRouteHistory
        self.onNavigateToAlarms = onNavigateToAlarms
        self.onNavigateToAddAlarm = onNavigateToAddAlarm
        self.onSwitchAppTab = onSwitchAppTab
    }

    var body: some View {
        ZStack(alignment: .top) {
            pageBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection

                    VStack(spacing: 18) {
                        quickActionsRow
                        segmentedTabs
                        tabContent
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 120)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Araçlar")
                            .font(.system(size: 16, weight: .regular))
                    }
                    .foregroundStyle(AppTheme.textPrimary)
                }
            }

            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(vehicle.plate)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(vehicleTypeText)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.secondary)
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(vehicle.kontakOn ? mint : alertRed)
                        .frame(width: 8, height: 8)
                    Text(vehicle.kontakLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(vehicle.kontakOn ? mint : alertRed)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background((vehicle.kontakOn ? mint : alertRed).opacity(0.12))
                .clipShape(Capsule())
            }
        }
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.white.opacity(0.92), for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            premiumBottomShell
        }
        .onAppear {
            mapCameraPosition = .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: vehicle.lat, longitude: vehicle.lng),
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
            )
            loadSupplementaryData()
        }
    }

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            Map(position: $mapCameraPosition) {
                Annotation(vehicle.plate, coordinate: CLLocationCoordinate2D(latitude: vehicle.lat, longitude: vehicle.lng)) {
                    ZStack {
                        Circle()
                            .fill((vehicle.kontakOn ? brightBlue : alertRed).opacity(0.28))
                            .frame(width: 54, height: 54)
                            .blur(radius: 10)

                        Circle()
                            .fill(vehicle.kontakOn ? brightBlue : alertRed)
                            .frame(width: 18, height: 18)
                            .overlay(Circle().stroke(Color.white, lineWidth: 4))
                    }
                }
            }
            .frame(height: 290)
            .ignoresSafeArea(edges: .top)

            premiumSummaryCard
                .padding(.horizontal, 16)
                .offset(y: 72)
        }
        .padding(.bottom, 78)
    }

    private var premiumSummaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Hızlı Özet")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(primaryVehicleName)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                }

                Spacer()

                Text(vehicle.formattedDeviceTime)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                premiumMetricCell(title: "Anlık Hız", value: vehicle.formattedSpeed, note: vehicle.livenessLabel, emphasized: true)
                premiumMetricCell(title: "Bugün KM", value: vehicle.formattedTodayKm, note: "Günlük hareket")
                premiumMetricCell(title: "Toplam KM", value: vehicle.formattedTotalKm + " km", note: "Odometer")
                premiumMetricCell(title: "Son Veri", value: vehicle.formattedLastPacketAt, note: vehicle.city.isEmpty ? "Canlı veri" : vehicle.city)
            }
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        )
        .shadow(color: navy.opacity(0.18), radius: 24, x: 0, y: 14)
    }

    private func premiumMetricCell(title: String, value: String, note: String, emphasized: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: emphasized ? 32 : 17, weight: emphasized ? .bold : .medium, design: emphasized ? .rounded : .default))
                .foregroundStyle(emphasized ? navy : AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(note)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.34), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var quickActionsRow: some View {
        HStack(spacing: 10) {
            premiumActionButton(title: "Yol Tarifi", icon: "location.fill", tint: brightBlue) {
                openMapsDirections(lat: vehicle.lat, lng: vehicle.lng, label: vehicle.plate)
            }
            premiumActionButton(title: "Rota", icon: "clock.arrow.trianglehead.counterclockwise.rotate.90", tint: navy) {
                onNavigateToRouteHistory?(vehicle)
            }
            premiumActionButton(title: "Düzenle", icon: "pencil", tint: mint) {
                showEditSheet = true
            }
            premiumActionButton(title: "Blokaj", icon: "lock.fill", tint: alertRed) {
                blockageError = nil
                blockageSuccess = nil
                showBlockageModal = true
            }
        }
        .sheet(isPresented: $showEditSheet) {
            VehicleEditSheet(vehicle: vehicle) { updatedVehicle in
                observer.vehicle.plate = updatedVehicle.plate
                if !updatedVehicle.name.isEmpty { observer.vehicle.name = updatedVehicle.name }
            }
        }
        .sheet(isPresented: $showBlockageModal) {
            BlockageSheet(
                vehicle: vehicle,
                isLoading: $blockageLoading,
                errorMessage: $blockageError,
                successMessage: $blockageSuccess
            )
        }
    }

    private func premiumActionButton(title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 54, height: 54)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(tint.opacity(0.18), lineWidth: 1)
                    )
                    .shadow(color: tint.opacity(0.14), radius: 10, x: 0, y: 6)

                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var segmentedTabs: some View {
        Picker("Detay Sekmeleri", selection: $selectedTab) {
            ForEach(PremiumDetailTab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .overview:
            premiumOverviewContent
        case .maintenance:
            premiumMaintenanceContent
        case .costs:
            premiumCostsContent
        case .events:
            premiumEventsContent
        }
    }

    private var premiumOverviewContent: some View {
        VStack(spacing: 14) {
            premiumInsetSection(title: "Araç ve Konum", subtitle: "Canlı görünüm ve adres bilgisi") {
                premiumInfoRow(icon: "car.fill", label: "Araç", value: primaryVehicleName)
                premiumDivider
                premiumInfoRow(icon: "mappin.and.ellipse", label: "Konum", value: vehicleLocationText)
                premiumDivider
                premiumInfoRow(icon: "clock.fill", label: "Son Güncelleme", value: vehicle.formattedDeviceTime)
                premiumDivider
                premiumInfoRow(icon: "arrow.clockwise", label: "Son Veri", value: vehicle.formattedLastPacketAt)
            }

            premiumInsetSection(title: "Kontak ve Güç", subtitle: "Araç enerji ve kontak zamanları") {
                premiumInfoRow(icon: "power", label: "Kontak", value: vehicle.kontakLabel, valueColor: vehicle.kontakOn ? mint : alertRed)
                premiumDivider
                premiumInfoRow(icon: "sunrise.fill", label: "İlk Kontak", value: vehicle.formattedFirstIgnitionToday)
                premiumDivider
                premiumInfoRow(icon: "play.circle.fill", label: "Son Kontak Açma", value: vehicle.formattedLastIgnitionOn)
                premiumDivider
                premiumInfoRow(icon: "pause.circle.fill", label: "Son Kontak Kapama", value: vehicle.formattedLastIgnitionOff)
                premiumDivider
                premiumInfoRow(icon: "bolt.fill", label: "Harici Voltaj", value: formattedVoltage(vehicle.externalVoltage))
                premiumDivider
                premiumInfoRow(icon: "battery.75", label: "Akü Voltajı", value: formattedVoltage(vehicle.batteryVoltage))
                premiumDivider
                premiumInfoRow(icon: "iphone.gen3", label: "Cihaz Bataryası", value: formattedBattery(vehicle.deviceBattery))
            }

            premiumInsetSection(title: "Yakıt ve Maliyet", subtitle: "Tüketim ve günlük özet") {
                premiumInfoRow(icon: "fuelpump.fill", label: "Yakıt Tipi", value: vehicle.fuelType.isEmpty ? "Tanımsız" : vehicle.fuelType)
                premiumDivider
                premiumInfoRow(icon: "gauge.open.with.lines.needle.33percent", label: "Tüketim", value: fuelConsumptionText)
                premiumDivider
                premiumInfoRow(icon: "drop.fill", label: "Bugün Tahmini Yakıt", value: vehicle.formattedDailyFuelLiters)
                premiumDivider
                premiumInfoRow(icon: "turkishlirasign.circle.fill", label: "Bugün Tahmini Maliyet", value: vehicle.formattedDailyFuelCost)
            }

            if vehicle.temperatureC != nil || vehicle.humidityPct != nil {
                premiumInsetSection(title: "Sensör Verileri", subtitle: "Çevresel ölçümler") {
                    if let temp = vehicle.temperatureC {
                        premiumInfoRow(icon: "thermometer.medium", label: "Sıcaklık", value: String(format: "%.1f°C", temp))
                    }
                    if vehicle.temperatureC != nil && vehicle.humidityPct != nil {
                        premiumDivider
                    }
                    if let humidity = vehicle.humidityPct {
                        premiumInfoRow(icon: "humidity.fill", label: "Nem", value: "%\(Int(humidity))")
                    }
                }
            }

            premiumDriverSection
        }
    }

    private var premiumDriverSection: some View {
        premiumInsetSection(title: "Sürücü Bilgisi", subtitle: "Atama ve iletişim bilgileri") {
            HStack(spacing: 12) {
                Circle()
                    .fill(brightBlue.opacity(0.14))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(currentDriverName.isEmpty ? "?" : String(currentDriverName.prefix(1)))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(brightBlue)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(currentDriverName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(observer.driverPhone.isEmpty ? "Telefon bilgisi yok" : observer.driverPhone)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Değiştir") {
                    showDriverAssign = true
                }
                .buttonStyle(.bordered)
                .tint(brightBlue)
                .font(.system(size: 14, weight: .semibold))
            }
        }
        .sheet(isPresented: $showDriverAssign) {
            VehicleDriverAssignSheet(
                vehicleId: vehicle.deviceId,
                currentDriverName: currentDriverName == "Sürücü Atanmamış" ? "" : currentDriverName,
                onAssigned: {
                    observer.fetchDriverInfo()
                }
            )
        }
    }

    private var premiumMaintenanceContent: some View {
        VStack(spacing: 14) {
            premiumInsetSection(title: "Bakım Takvimi", subtitle: "Planlı bakım ve servis kayıtları") {
                if isLoadingMaintenance {
                    premiumProgressRow
                } else if fleetMaintenances.isEmpty {
                    premiumEmptyRow("Bu araç için bakım kaydı bulunmuyor")
                } else {
                    ForEach(Array(fleetMaintenances.enumerated()), id: \.element.id) { index, item in
                        let status: PremiumMaintenanceStatus = item.status == "completed" ? .completed : (item.status == "overdue" ? .overdue : .upcoming)
                        premiumTimelineRow(
                            icon: item.maintenanceType == "oil_change" ? "drop.fill" : (item.maintenanceType == "tire_change" ? "circle.circle.fill" : "wrench.fill"),
                            title: item.title,
                            subtitle: "\(item.scheduledDate) • \(item.currentKm > 0 ? "\(item.currentKm) km" : "—")",
                            badge: status.label,
                            badgeColor: status.color
                        )
                        if index < fleetMaintenances.count - 1 {
                            premiumDivider
                        }
                    }
                }
            }

            premiumInsetSection(title: "Belgeler", subtitle: "Geçerlilik ve süre bilgileri") {
                if isLoadingMaintenance {
                    premiumProgressRow
                } else if fleetDocuments.isEmpty {
                    premiumEmptyRow("Bu araç için belge kaydı bulunmuyor")
                } else {
                    ForEach(Array(fleetDocuments.enumerated()), id: \.element.id) { index, doc in
                        let status: PremiumDocumentStatus = doc.status == "expired" ? .critical : (doc.status == "expiring_soon" ? .warning : .normal)
                        premiumTimelineRow(
                            icon: "doc.text.fill",
                            title: doc.docTypeLabel,
                            subtitle: "Bitiş: \(doc.expiryDate ?? "—")",
                            badge: "\(doc.daysUntilExpiry) gün",
                            badgeColor: status.color
                        )
                        if index < fleetDocuments.count - 1 {
                            premiumDivider
                        }
                    }
                }
            }
        }
    }

    private var premiumCostsContent: some View {
        VStack(spacing: 14) {
            premiumInsetSection(title: "Masraf Özeti", subtitle: "Kategori bazlı maliyet görünümü") {
                if isLoadingCosts {
                    premiumProgressRow
                } else if fleetCosts.isEmpty {
                    premiumEmptyRow("Bu araç için masraf kaydı bulunmuyor")
                } else {
                    let categoryTotals = Dictionary(grouping: fleetCosts, by: { $0.category })
                        .mapValues { $0.reduce(0.0) { $0 + $1.amount } }
                    let total = fleetCosts.reduce(0.0) { $0 + $1.amount }
                    let currency = fleetCosts.first?.currency ?? "TRY"

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(categoryTotals.sorted(by: { $0.value > $1.value }), id: \.key) { key, amount in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: costCategoryIcon(key))
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(costCategoryColor(key))
                                    Spacer()
                                    Text(total > 0 ? "%\(Int((amount / total) * 100))" : "%0")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(costCategoryColor(key))
                                }
                                Text(key.capitalized)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Text(FleetCost.formatAmount(amount, currency: currency))
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(pageBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                    }
                }
            }

            premiumInsetSection(title: "Son Masraflar", subtitle: "Güncel harcama satırları") {
                if isLoadingCosts {
                    premiumProgressRow
                } else if fleetCosts.isEmpty {
                    premiumEmptyRow("Masraf listesi boş")
                } else {
                    ForEach(Array(fleetCosts.enumerated()), id: \.element.id) { index, cost in
                        premiumTimelineRow(
                            icon: costCategoryIcon(cost.category),
                            title: cost.category.capitalized,
                            subtitle: cost.costDate,
                            badge: cost.formattedAmount,
                            badgeColor: costCategoryColor(cost.category)
                        )
                        if index < fleetCosts.count - 1 {
                            premiumDivider
                        }
                    }
                }
            }
        }
    }

    private var premiumEventsContent: some View {
        premiumInsetSection(title: "Olaylar", subtitle: "Son alarm ve hareket kayıtları") {
            if isLoadingEvents {
                premiumProgressRow
            } else if alarms.isEmpty {
                premiumEmptyRow("Bu araç için olay kaydı bulunmuyor")
            } else {
                ForEach(Array(alarms.enumerated()), id: \.element.id) { index, alarm in
                    premiumTimelineRow(
                        icon: alarm.icon,
                        title: alarm.typeLabel,
                        subtitle: alarm.description.isEmpty ? alarm.plate : alarm.description,
                        badge: alarm.formattedDate,
                        badgeColor: premiumAlarmSeverity(alarm).color
                    )
                    if index < alarms.count - 1 {
                        premiumDivider
                    }
                }

                if let onNavigateToAlarms {
                    Button("Tüm Alarmları Gör") {
                        onNavigateToAlarms(vehicle.plate)
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(brightBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                }

                if let onNavigateToAddAlarm {
                    Button("Yeni Alarm Oluştur") {
                        onNavigateToAddAlarm(vehicle.plate)
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .buttonStyle(.bordered)
                    .tint(brightBlue)
                    .padding(.top, 4)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }

    private func premiumInsetSection(title: String, subtitle: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 10)

            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(cardBorder, lineWidth: 1)
        )
        .shadow(color: navy.opacity(0.05), radius: 14, x: 0, y: 8)
    }

    private func premiumInfoRow(icon: String, label: String, value: String, valueColor: Color? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(brightBlue)
                .frame(width: 22)

            Text(label)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)

            Spacer()

            Text(value)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(valueColor ?? AppTheme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 13)
    }

    private func premiumTimelineRow(icon: String, title: String, subtitle: String, badge: String, badgeColor: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(badgeColor)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(badge)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(badgeColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(badgeColor.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.vertical, 13)
    }

    private var premiumDivider: some View {
        Divider()
            .padding(.leading, 34)
    }

    private var premiumProgressRow: some View {
        HStack {
            Spacer()
            ProgressView()
                .padding(.vertical, 20)
            Spacer()
        }
    }

    private func premiumEmptyRow(_ text: String) -> some View {
        HStack {
            Spacer()
            Text(text)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.secondary)
                .padding(.vertical, 18)
            Spacer()
        }
    }

    private var premiumBottomShell: some View {
        HStack(spacing: 0) {
            premiumBottomTab(title: "Özet", icon: "square.grid.2x2.fill", tab: .dashboard)
            premiumBottomTab(title: "Alarmlar", icon: "bell.fill", tab: .alarms)
            premiumMapTab
            premiumBottomTab(title: "Filo", icon: "wrench.and.screwdriver.fill", tab: .fleet)
            premiumBottomTab(title: "Hub", icon: "circle.grid.2x2.fill", tab: .hub)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(navy, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .shadow(color: navy.opacity(0.28), radius: 20, x: 0, y: 8)
    }

    private func premiumBottomTab(title: String, icon: String, tab: AppTab) -> some View {
        Button {
            onSwitchAppTab?(tab)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.92))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private var premiumMapTab: some View {
        Button {
            onSwitchAppTab?(.liveMap)
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [brightBlue, mint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .shadow(color: brightBlue.opacity(0.35), radius: 14, x: 0, y: 8)

                    Image(systemName: "location.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }
                .offset(y: -16)

                Text("Harita")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.96))
                    .offset(y: -16)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
        }
        .buttonStyle(.plain)
    }

    private var primaryVehicleName: String {
        if !vehicle.vehicleBrand.isEmpty || !vehicle.vehicleModel.isEmpty {
            return [vehicle.vehicleBrand, vehicle.vehicleModel].filter { !$0.isEmpty }.joined(separator: " ")
        }
        return vehicle.model
    }

    private var vehicleTypeText: String {
        let value = [vehicle.vehicleModel, vehicle.vehicleBrand, vehicle.model]
            .first(where: { !$0.isEmpty && $0 != "<null>" }) ?? "Araç Detayı"
        return value.uppercased()
    }

    private var vehicleLocationText: String {
        if !vehicle.address.isEmpty { return vehicle.address }
        if !vehicle.city.isEmpty { return vehicle.city }
        return "Konum bilgisi bekleniyor"
    }

    private var currentDriverName: String {
        let name = !observer.driverName.isEmpty ? observer.driverName : (!vehicle.driverName.isEmpty ? vehicle.driverName : vehicle.driver)
        return name.isEmpty ? "Sürücü Atanmamış" : name
    }

    private var fuelConsumptionText: String {
        let rate = vehicle.dailyFuelPer100km > 0 ? vehicle.dailyFuelPer100km : vehicle.fuelPer100km
        return rate > 0 ? String(format: "%.1f L/100km", rate) : "—"
    }

    private func premiumAlarmSeverity(_ alarm: AlarmEvent) -> AlertSeverity {
        let key = alarm.alarmKey.lowercased()
        if key.contains("gf_") || key.contains("geofence") { return .green }
        if key.contains("t_towing") || key.contains("sos") { return .red }
        if key.contains("t_movement") { return .amber }
        return .blue
    }

    private func loadSupplementaryData() {
        if !isLoadingMaintenance && fleetMaintenances.isEmpty && fleetDocuments.isEmpty {
            isLoadingMaintenance = true
            Task {
                do {
                    let (maintenances, _) = try await APIService.shared.fetchFleetMaintenance(imei: vehicle.imei)
                    let (documents, _) = try await APIService.shared.fetchFleetDocuments(imei: vehicle.imei)
                    await MainActor.run {
                        fleetMaintenances = maintenances
                        fleetDocuments = documents
                        isLoadingMaintenance = false
                    }
                } catch {
                    await MainActor.run {
                        isLoadingMaintenance = false
                    }
                }
            }
        }

        if !isLoadingCosts && fleetCosts.isEmpty {
            isLoadingCosts = true
            Task {
                do {
                    let (costs, _) = try await APIService.shared.fetchFleetCosts(imei: vehicle.imei)
                    await MainActor.run {
                        fleetCosts = costs
                        isLoadingCosts = false
                    }
                } catch {
                    await MainActor.run {
                        isLoadingCosts = false
                    }
                }
            }
        }

        if !isLoadingEvents && alarms.isEmpty {
            isLoadingEvents = true
            Task {
                do {
                    let json = try await APIService.shared.get("/api/mobile/alarms?page=1&per_page=20&imei=\(vehicle.imei)")
                    let dataArr = json["data"] as? [[String: Any]] ?? []
                    let results = dataArr.enumerated().compactMap { index, dict -> AlarmEvent? in
                        let alarm = AlarmEvent.from(json: dict, index: index)
                        guard alarm.imei == vehicle.imei || alarm.plate == vehicle.plate else { return nil }
                        return alarm
                    }
                    await MainActor.run {
                        alarms = Array(results.prefix(10))
                        isLoadingEvents = false
                    }
                } catch {
                    await MainActor.run {
                        isLoadingEvents = false
                    }
                }
            }
        }
    }

    private func openMapsDirections(lat: Double, lng: Double, label: String) {
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = label
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    private func formattedVoltage(_ value: Double?) -> String {
        guard let value = value, value > 0 else { return "—" }
        return String(format: "%.2f V", value)
    }

    private func formattedBattery(_ value: Double?) -> String {
        guard let value = value, value > 0 else { return "—" }
        return value <= 100 ? "%\(Int(value))" : String(format: "%.2f V", value)
    }

    private func costCategoryColor(_ category: String) -> Color {
        switch category {
        case "Yakıt": return .orange
        case "Bakım": return .blue
        case "Sigorta": return .purple
        default: return AppTheme.textMuted
        }
    }

    private func costCategoryIcon(_ category: String) -> String {
        switch category {
        case "Yakıt": return "fuelpump.fill"
        case "Bakım": return "wrench.fill"
        case "Sigorta": return "shield.fill"
        default: return "ellipsis"
        }
    }
}

struct VehicleDetailFourthView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var observer: VehicleDetailObserver
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @State private var selectedTab: FourthDetailTab = .overview
    @State private var showEditSheet = false
    @State private var showBlockageModal = false
    @State private var blockageLoading = false
    @State private var blockageError: String?
    @State private var blockageSuccess: String?
    @State private var showDriverAssign = false
    @State private var fleetMaintenances: [FleetMaintenance] = []
    @State private var fleetDocuments: [FleetDocument] = []
    @State private var fleetCosts: [FleetCost] = []
    @State private var alarms: [AlarmEvent] = []
    @State private var isLoadingMaintenance = false
    @State private var isLoadingCosts = false
    @State private var isLoadingEvents = false

    var onNavigateToRouteHistory: ((Vehicle) -> Void)?
    var onNavigateToAlarms: ((String) -> Void)?
    var onNavigateToAddAlarm: ((String) -> Void)?
    var onSwitchAppTab: ((AppTab) -> Void)?

    private var vehicle: Vehicle { observer.vehicle }
    private let base = Color(red: 10/255, green: 13/255, blue: 24/255)
    private let panel = Color(red: 20/255, green: 24/255, blue: 37/255)
    private let panelSoft = Color(red: 29/255, green: 34/255, blue: 52/255)
    private let stroke = Color.white.opacity(0.08)
    private let accent = Color(red: 71/255, green: 136/255, blue: 255/255)
    private let mint = Color(red: 27/255, green: 190/255, blue: 155/255)
    private let warning = Color(red: 242/255, green: 166/255, blue: 58/255)
    private let danger = Color(red: 237/255, green: 87/255, blue: 104/255)

    enum FourthDetailTab: String, CaseIterable {
        case overview = "Genel"
        case maintenance = "Bakım"
        case costs = "Masraf"
        case events = "Olaylar"
    }

    init(
        vehicle: Vehicle,
        onNavigateToRouteHistory: ((Vehicle) -> Void)? = nil,
        onNavigateToAlarms: ((String) -> Void)? = nil,
        onNavigateToAddAlarm: ((String) -> Void)? = nil,
        onSwitchAppTab: ((AppTab) -> Void)? = nil
    ) {
        _observer = StateObject(wrappedValue: VehicleDetailObserver(vehicle: vehicle))
        self.onNavigateToRouteHistory = onNavigateToRouteHistory
        self.onNavigateToAlarms = onNavigateToAlarms
        self.onNavigateToAddAlarm = onNavigateToAddAlarm
        self.onSwitchAppTab = onSwitchAppTab
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [base, panelSoft], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    topPanel
                    commandStrip
                    segmentedTabs
                    fourthTabContent
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 120)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Araçlar")
                            .font(.system(size: 16, weight: .regular))
                    }
                    .foregroundStyle(.white)
                }
            }

            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(vehicle.plate)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(fourthVehicleType)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.white.opacity(0.66))
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(vehicle.kontakOn ? mint : danger)
                        .frame(width: 8, height: 8)
                    Text(vehicle.kontakLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(vehicle.kontakOn ? mint : danger)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
            }
        }
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(base.opacity(0.96), for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            fourthBottomBar
        }
        .onAppear {
            mapCameraPosition = .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: vehicle.lat, longitude: vehicle.lng),
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
            )
            loadFourthData()
        }
    }

    private var topPanel: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .bottomLeading) {
                Map(position: $mapCameraPosition) {
                    Annotation(vehicle.plate, coordinate: CLLocationCoordinate2D(latitude: vehicle.lat, longitude: vehicle.lng)) {
                        ZStack {
                            Circle()
                                .fill((vehicle.kontakOn ? accent : danger).opacity(0.30))
                                .frame(width: 46, height: 46)
                                .blur(radius: 10)
                            Image(systemName: vehicle.mapIcon)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(vehicle.kontakOn ? accent : danger)
                                .clipShape(Circle())
                        }
                    }
                }
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(stroke, lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text("Operasyon Paneli")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.72))
                    Text(fourthVehicleName)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white)
                    Text(fourthLocationText)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(2)
                }
                .padding(16)
            }

            HStack(spacing: 12) {
                fourthHeroMetric(title: "Anlık Hız", value: vehicle.formattedSpeed, note: vehicle.livenessLabel, emphasized: true)
                VStack(spacing: 12) {
                    fourthHeroMetric(title: "Bugün KM", value: vehicle.formattedTodayKm, note: "Günlük")
                    fourthHeroMetric(title: "Toplam KM", value: vehicle.formattedTotalKm + " km", note: "Odometer")
                }
            }

            fourthHeroMetric(title: "Son Veri", value: vehicle.formattedLastPacketAt, note: vehicle.formattedDeviceTime)
        }
    }

    private func fourthHeroMetric(title: String, value: String, note: String, emphasized: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.64))
            Text(value)
                .font(.system(size: emphasized ? 32 : 17, weight: emphasized ? .bold : .medium, design: emphasized ? .rounded : .default))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(note)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.white.opacity(0.64))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(panel, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(stroke, lineWidth: 1)
        )
    }

    private var commandStrip: some View {
        HStack(spacing: 10) {
            fourthActionButton(title: "Yol Tarifi", icon: "location.fill", tint: accent) {
                openMapsDirections(lat: vehicle.lat, lng: vehicle.lng, label: vehicle.plate)
            }
            fourthActionButton(title: "Rota", icon: "point.topleft.down.curvedto.point.bottomright.up", tint: mint) {
                onNavigateToRouteHistory?(vehicle)
            }
            fourthActionButton(title: "Düzenle", icon: "pencil", tint: warning) {
                showEditSheet = true
            }
            fourthActionButton(title: "Blokaj", icon: "lock.fill", tint: danger) {
                blockageError = nil
                blockageSuccess = nil
                showBlockageModal = true
            }
        }
        .sheet(isPresented: $showEditSheet) {
            VehicleEditSheet(vehicle: vehicle) { updatedVehicle in
                observer.vehicle.plate = updatedVehicle.plate
                if !updatedVehicle.name.isEmpty { observer.vehicle.name = updatedVehicle.name }
            }
        }
        .sheet(isPresented: $showBlockageModal) {
            BlockageSheet(
                vehicle: vehicle,
                isLoading: $blockageLoading,
                errorMessage: $blockageError,
                successMessage: $blockageSuccess
            )
        }
    }

    private func fourthActionButton(title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(tint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.88))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var segmentedTabs: some View {
        Picker("Detay Sekmeleri", selection: $selectedTab) {
            ForEach(FourthDetailTab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var fourthTabContent: some View {
        switch selectedTab {
        case .overview:
            fourthOverviewContent
        case .maintenance:
            fourthMaintenanceContent
        case .costs:
            fourthCostsContent
        case .events:
            fourthEventsContent
        }
    }

    private var fourthOverviewContent: some View {
        VStack(spacing: 14) {
            fourthSection(title: "Araç ve Konum") {
                fourthRow(icon: "mappin.circle.fill", label: "Konum", value: fourthLocationText)
                fourthDivider
                fourthRow(icon: "clock.fill", label: "Son Güncelleme", value: vehicle.formattedDeviceTime)
                fourthDivider
                fourthRow(icon: "arrow.clockwise", label: "Son Paket", value: vehicle.formattedLastPacketAt)
            }
            fourthSection(title: "Kontak ve Güç") {
                fourthRow(icon: "power", label: "Kontak", value: vehicle.kontakLabel, valueColor: vehicle.kontakOn ? mint : danger)
                fourthDivider
                fourthRow(icon: "sunrise.fill", label: "İlk Kontak", value: vehicle.formattedFirstIgnitionToday)
                fourthDivider
                fourthRow(icon: "play.circle.fill", label: "Son Kontak Açma", value: vehicle.formattedLastIgnitionOn)
                fourthDivider
                fourthRow(icon: "pause.circle.fill", label: "Son Kontak Kapama", value: vehicle.formattedLastIgnitionOff)
                fourthDivider
                fourthRow(icon: "bolt.fill", label: "Harici Voltaj", value: fourthVoltage(vehicle.externalVoltage))
                fourthDivider
                fourthRow(icon: "battery.75", label: "Akü Voltajı", value: fourthVoltage(vehicle.batteryVoltage))
            }
            fourthSection(title: "Yakıt ve Maliyet") {
                fourthRow(icon: "fuelpump.fill", label: "Yakıt Tipi", value: vehicle.fuelType.isEmpty ? "Tanımsız" : vehicle.fuelType)
                fourthDivider
                fourthRow(icon: "gauge.open.with.lines.needle.33percent", label: "Tüketim", value: fourthConsumptionText)
                fourthDivider
                fourthRow(icon: "drop.fill", label: "Bugün Tahmini Yakıt", value: vehicle.formattedDailyFuelLiters)
                fourthDivider
                fourthRow(icon: "turkishlirasign.circle.fill", label: "Bugün Tahmini Maliyet", value: vehicle.formattedDailyFuelCost)
            }
            fourthDriverSection
            if vehicle.temperatureC != nil || vehicle.humidityPct != nil {
                fourthSection(title: "Sensör Verileri") {
                    if let temp = vehicle.temperatureC {
                        fourthRow(icon: "thermometer.medium", label: "Sıcaklık", value: String(format: "%.1f°C", temp))
                    }
                    if vehicle.temperatureC != nil && vehicle.humidityPct != nil {
                        fourthDivider
                    }
                    if let humidity = vehicle.humidityPct {
                        fourthRow(icon: "humidity.fill", label: "Nem", value: "%\(Int(humidity))")
                    }
                }
            }
        }
    }

    private var fourthDriverSection: some View {
        fourthSection(title: "Sürücü Bilgisi") {
            HStack(spacing: 12) {
                Circle()
                    .fill(accent.opacity(0.18))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(fourthDriverName.prefix(1)))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(fourthDriverName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(observer.driverPhone.isEmpty ? "Telefon bilgisi yok" : observer.driverPhone)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.white.opacity(0.66))
                }

                Spacer()

                Button("Değiştir") {
                    showDriverAssign = true
                }
                .buttonStyle(.bordered)
                .tint(accent)
                .font(.system(size: 14, weight: .semibold))
            }
        }
        .sheet(isPresented: $showDriverAssign) {
            VehicleDriverAssignSheet(
                vehicleId: vehicle.deviceId,
                currentDriverName: fourthDriverName == "Sürücü Atanmamış" ? "" : fourthDriverName,
                onAssigned: {
                    observer.fetchDriverInfo()
                }
            )
        }
    }

    private var fourthMaintenanceContent: some View {
        VStack(spacing: 14) {
            fourthSection(title: "Bakım Takvimi") {
                if isLoadingMaintenance {
                    fourthProgress
                } else if fleetMaintenances.isEmpty {
                    fourthEmpty("Bu araç için bakım kaydı bulunmuyor")
                } else {
                    ForEach(Array(fleetMaintenances.enumerated()), id: \.element.id) { index, item in
                        fourthEventRow(
                            icon: item.maintenanceType == "oil_change" ? "drop.fill" : (item.maintenanceType == "tire_change" ? "circle.circle.fill" : "wrench.fill"),
                            title: item.title,
                            subtitle: "\(item.scheduledDate) • \(item.currentKm > 0 ? "\(item.currentKm) km" : "—")",
                            badge: item.status == "completed" ? "Tamamlandı" : (item.status == "overdue" ? "Gecikmiş" : "Yaklaşıyor"),
                            color: item.status == "completed" ? mint : (item.status == "overdue" ? danger : warning)
                        )
                        if index < fleetMaintenances.count - 1 { fourthDivider }
                    }
                }
            }
            fourthSection(title: "Belgeler") {
                if isLoadingMaintenance {
                    fourthProgress
                } else if fleetDocuments.isEmpty {
                    fourthEmpty("Bu araç için belge kaydı bulunmuyor")
                } else {
                    ForEach(Array(fleetDocuments.enumerated()), id: \.element.id) { index, doc in
                        let color = doc.status == "expired" ? danger : (doc.status == "expiring_soon" ? warning : mint)
                        fourthEventRow(
                            icon: "doc.text.fill",
                            title: doc.docTypeLabel,
                            subtitle: "Bitiş: \(doc.expiryDate ?? "—")",
                            badge: "\(doc.daysUntilExpiry) gün",
                            color: color
                        )
                        if index < fleetDocuments.count - 1 { fourthDivider }
                    }
                }
            }
        }
    }

    private var fourthCostsContent: some View {
        VStack(spacing: 14) {
            fourthSection(title: "Masraf Özeti") {
                if isLoadingCosts {
                    fourthProgress
                } else if fleetCosts.isEmpty {
                    fourthEmpty("Bu araç için masraf kaydı bulunmuyor")
                } else {
                    let totals = Dictionary(grouping: fleetCosts, by: { $0.category })
                        .mapValues { $0.reduce(0.0) { $0 + $1.amount } }
                    let currency = fleetCosts.first?.currency ?? "TRY"
                    ForEach(totals.sorted(by: { $0.value > $1.value }), id: \.key) { key, amount in
                        fourthEventRow(
                            icon: fourthCostIcon(key),
                            title: key.capitalized,
                            subtitle: "Kategori toplamı",
                            badge: FleetCost.formatAmount(amount, currency: currency),
                            color: fourthCostColor(key)
                        )
                    }
                }
            }
            fourthSection(title: "Son Masraflar") {
                if isLoadingCosts {
                    fourthProgress
                } else if fleetCosts.isEmpty {
                    fourthEmpty("Masraf listesi boş")
                } else {
                    ForEach(Array(fleetCosts.enumerated()), id: \.element.id) { index, item in
                        fourthEventRow(
                            icon: fourthCostIcon(item.category),
                            title: item.category.capitalized,
                            subtitle: item.costDate,
                            badge: item.formattedAmount,
                            color: fourthCostColor(item.category)
                        )
                        if index < fleetCosts.count - 1 { fourthDivider }
                    }
                }
            }
        }
    }

    private var fourthEventsContent: some View {
        fourthSection(title: "Son Olaylar") {
            if isLoadingEvents {
                fourthProgress
            } else if alarms.isEmpty {
                fourthEmpty("Bu araç için olay kaydı bulunmuyor")
            } else {
                ForEach(Array(alarms.enumerated()), id: \.element.id) { index, alarm in
                    fourthEventRow(
                        icon: alarm.icon,
                        title: alarm.typeLabel,
                        subtitle: alarm.description.isEmpty ? alarm.plate : alarm.description,
                        badge: alarm.formattedDate,
                        color: fourthAlarmSeverity(alarm).color
                    )
                    if index < alarms.count - 1 { fourthDivider }
                }

                if let onNavigateToAlarms {
                    Button("Tüm Alarmları Aç") {
                        onNavigateToAlarms(vehicle.plate)
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accent)
                    .padding(.top, 10)
                }
            }
        }
    }

    private func fourthSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .background(panel, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(stroke, lineWidth: 1)
        )
    }

    private func fourthRow(icon: String, label: String, value: String, valueColor: Color? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 22)
            Text(label)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white)
            Spacer()
            Text(value)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(valueColor ?? .white)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 13)
    }

    private func fourthEventRow(icon: String, title: String, subtitle: String, badge: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white.opacity(0.68))
            }
            Spacer()
            Text(badge)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(color.opacity(0.14))
                .clipShape(Capsule())
        }
        .padding(.vertical, 13)
    }

    private var fourthDivider: some View {
        Divider()
            .overlay(Color.white.opacity(0.08))
            .padding(.leading, 34)
    }

    private var fourthProgress: some View {
        HStack {
            Spacer()
            ProgressView()
                .tint(.white)
                .padding(.vertical, 18)
            Spacer()
        }
    }

    private func fourthEmpty(_ text: String) -> some View {
        HStack {
            Spacer()
            Text(text)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.white.opacity(0.66))
                .padding(.vertical, 18)
            Spacer()
        }
    }

    private var fourthBottomBar: some View {
        HStack(spacing: 0) {
            fourthTabButton(title: "Özet", icon: "square.grid.2x2.fill", tab: .dashboard)
            fourthTabButton(title: "Alarmlar", icon: "bell.fill", tab: .alarms)
            fourthCenterMapButton
            fourthTabButton(title: "Filo", icon: "wrench.and.screwdriver.fill", tab: .fleet)
            fourthTabButton(title: "Hub", icon: "circle.grid.2x2.fill", tab: .hub)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(panelSoft, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(stroke, lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }

    private func fourthTabButton(title: String, icon: String, tab: AppTab) -> some View {
        Button {
            onSwitchAppTab?(tab)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.9))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private var fourthCenterMapButton: some View {
        Button {
            onSwitchAppTab?(.liveMap)
        } label: {
            VStack(spacing: 3) {
                Circle()
                    .fill(
                        LinearGradient(colors: [accent, mint], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "location.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                    )
                    .offset(y: -16)
                Text("Harita")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .offset(y: -16)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
        }
        .buttonStyle(.plain)
    }

    private var fourthVehicleName: String {
        if !vehicle.vehicleBrand.isEmpty || !vehicle.vehicleModel.isEmpty {
            return [vehicle.vehicleBrand, vehicle.vehicleModel].filter { !$0.isEmpty }.joined(separator: " ")
        }
        return vehicle.model
    }

    private var fourthVehicleType: String {
        ([vehicle.vehicleModel, vehicle.vehicleBrand, vehicle.model].first { !$0.isEmpty } ?? "ARAÇ DETAYI").uppercased()
    }

    private var fourthLocationText: String {
        if !vehicle.address.isEmpty { return vehicle.address }
        if !vehicle.city.isEmpty { return vehicle.city }
        return "Konum bilgisi bekleniyor"
    }

    private var fourthDriverName: String {
        let name = !observer.driverName.isEmpty ? observer.driverName : (!vehicle.driverName.isEmpty ? vehicle.driverName : vehicle.driver)
        return name.isEmpty ? "Sürücü Atanmamış" : name
    }

    private var fourthConsumptionText: String {
        let rate = vehicle.dailyFuelPer100km > 0 ? vehicle.dailyFuelPer100km : vehicle.fuelPer100km
        return rate > 0 ? String(format: "%.1f L/100km", rate) : "—"
    }

    private func fourthVoltage(_ value: Double?) -> String {
        guard let value, value > 0 else { return "—" }
        return String(format: "%.2f V", value)
    }

    private func fourthAlarmSeverity(_ alarm: AlarmEvent) -> AlertSeverity {
        let key = alarm.alarmKey.lowercased()
        if key.contains("gf_") || key.contains("geofence") { return .green }
        if key.contains("t_towing") || key.contains("sos") { return .red }
        if key.contains("t_movement") { return .amber }
        return .blue
    }

    private func fourthCostColor(_ category: String) -> Color {
        switch category {
        case "Yakıt": return warning
        case "Bakım": return accent
        case "Sigorta": return mint
        default: return .white.opacity(0.7)
        }
    }

    private func fourthCostIcon(_ category: String) -> String {
        switch category {
        case "Yakıt": return "fuelpump.fill"
        case "Bakım": return "wrench.fill"
        case "Sigorta": return "shield.fill"
        default: return "ellipsis"
        }
    }

    private func loadFourthData() {
        if !isLoadingMaintenance && fleetMaintenances.isEmpty && fleetDocuments.isEmpty {
            isLoadingMaintenance = true
            Task {
                do {
                    let (maintenances, _) = try await APIService.shared.fetchFleetMaintenance(imei: vehicle.imei)
                    let (documents, _) = try await APIService.shared.fetchFleetDocuments(imei: vehicle.imei)
                    await MainActor.run {
                        fleetMaintenances = maintenances
                        fleetDocuments = documents
                        isLoadingMaintenance = false
                    }
                } catch {
                    await MainActor.run {
                        isLoadingMaintenance = false
                    }
                }
            }
        }

        if !isLoadingCosts && fleetCosts.isEmpty {
            isLoadingCosts = true
            Task {
                do {
                    let (costs, _) = try await APIService.shared.fetchFleetCosts(imei: vehicle.imei)
                    await MainActor.run {
                        fleetCosts = costs
                        isLoadingCosts = false
                    }
                } catch {
                    await MainActor.run {
                        isLoadingCosts = false
                    }
                }
            }
        }

        if !isLoadingEvents && alarms.isEmpty {
            isLoadingEvents = true
            Task {
                do {
                    let json = try await APIService.shared.get("/api/mobile/alarms?page=1&per_page=20&imei=\(vehicle.imei)")
                    let dataArr = json["data"] as? [[String: Any]] ?? []
                    let results = dataArr.enumerated().compactMap { index, dict -> AlarmEvent? in
                        let alarm = AlarmEvent.from(json: dict, index: index)
                        guard alarm.imei == vehicle.imei || alarm.plate == vehicle.plate else { return nil }
                        return alarm
                    }
                    await MainActor.run {
                        alarms = Array(results.prefix(10))
                        isLoadingEvents = false
                    }
                } catch {
                    await MainActor.run {
                        isLoadingEvents = false
                    }
                }
            }
        }
    }

    private func openMapsDirections(lat: Double, lng: Double, label: String) {
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = label
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}

struct VehicleDetailFifthView: View {
    enum PresentationMode {
        case push
        case modal
    }

    private struct FifthCombinedRecordSummary {
        let summary: String
        let accent: Color
        let date: Date
        let isFuture: Bool
        let priority: Int
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var observer: VehicleDetailObserver
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @State private var showEditSheet = false
    @State private var showBlockageModal = false
    @State private var blockageLoading = false
    @State private var blockageError: String?
    @State private var blockageSuccess: String?
    @State private var showDriverAssign = false
    @State private var fleetMaintenances: [FleetMaintenance] = []
    @State private var fleetCosts: [FleetCost] = []
    @State private var alarms: [AlarmEvent] = []
    @State private var isLoadingMaintenance = false
    @State private var isLoadingCosts = false
    @State private var isLoadingEvents = false

    private let presentationMode: PresentationMode
    var onNavigateToRouteHistory: ((Vehicle) -> Void)?
    var onNavigateToAlarms: ((String) -> Void)?
    var onNavigateToAddAlarm: ((String) -> Void)?

    private var vehicle: Vehicle { observer.vehicle }
    private var isDark: Bool { colorScheme == .dark }
    private var pageBackground: Color {
        isDark ? Color(red: 14/255, green: 19/255, blue: 34/255) : Color(UIColor.systemGroupedBackground)
    }
    private var navigationBackground: Color {
        isDark ? Color(red: 18/255, green: 24/255, blue: 41/255) : Color(UIColor.systemBackground)
    }
    private var surface: Color {
        isDark ? Color(red: 21/255, green: 28/255, blue: 48/255) : Color(UIColor.secondarySystemGroupedBackground)
    }
    private var elevatedSurface: Color {
        isDark ? Color(red: 27/255, green: 37/255, blue: 61/255) : .white
    }
    private var primaryText: Color { Color(UIColor.label) }
    private var secondaryText: Color { Color(UIColor.secondaryLabel) }
    private var stroke: Color { isDark ? .white.opacity(0.10) : Color.black.opacity(0.08) }
    private let brandBlue = Color(red: 37/255, green: 99/255, blue: 235/255)
    private let brandGreen = Color(red: 16/255, green: 185/255, blue: 129/255)
    private let brandRed = Color(red: 239/255, green: 68/255, blue: 68/255)
    private let brandOrange = Color(red: 249/255, green: 115/255, blue: 22/255)
    private let brandBlack = Color.black

    init(
        vehicle: Vehicle,
        presentationMode: PresentationMode = .push,
        onNavigateToRouteHistory: ((Vehicle) -> Void)? = nil,
        onNavigateToAlarms: ((String) -> Void)? = nil,
        onNavigateToAddAlarm: ((String) -> Void)? = nil
    ) {
        _observer = StateObject(wrappedValue: VehicleDetailObserver(vehicle: vehicle))
        self.presentationMode = presentationMode
        self.onNavigateToRouteHistory = onNavigateToRouteHistory
        self.onNavigateToAlarms = onNavigateToAlarms
        self.onNavigateToAddAlarm = onNavigateToAddAlarm
    }

    var body: some View {
        ZStack(alignment: .top) {
            pageBackground.ignoresSafeArea()

            navigationBackground
                .frame(height: 180)
                .ignoresSafeArea(edges: .top)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    fifthMapSection

                    VStack(spacing: 14) {
                        fifthActionsRow

                        if vehicle.temperatureC != nil || vehicle.humidityPct != nil {
                            fifthSensorRow
                        }

                        fifthDetailsGrid
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 22)
                    .padding(.bottom, 28)
                }
            }
        }
        .navigationBarBackButtonHidden(presentationMode == .modal)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if presentationMode == .modal {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(primaryText)
                            .frame(width: 34, height: 34)
                            .background(surface.opacity(isDark ? 0.85 : 1.0), in: Circle())
                            .overlay(
                                Circle()
                                    .stroke(stroke, lineWidth: 1)
                            )
                    }
                    .accessibilityLabel("Kapat")
                }
            }

            ToolbarItem(placement: .principal) {
                Text(vehicle.plate)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(primaryText)
            }

            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    showEditSheet = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(primaryText)
                        .frame(width: 34, height: 34)
                        .background(surface.opacity(isDark ? 0.85 : 1.0), in: Circle())
                        .overlay(
                            Circle()
                                .stroke(stroke, lineWidth: 1)
                        )
                }
                .accessibilityLabel("Araç düzenle")

                NavigationLink {
                    VehicleSettingsView(vehicle: vehicle)
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(primaryText)
                        .frame(width: 34, height: 34)
                        .background(surface.opacity(isDark ? 0.85 : 1.0), in: Circle())
                        .overlay(
                            Circle()
                                .stroke(stroke, lineWidth: 1)
                        )
                }
                .accessibilityLabel("Araç ayarları")
            }
        }
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(navigationBackground, for: .navigationBar)
        .toolbarColorScheme(isDark ? .dark : .light, for: .navigationBar)
        .sheet(isPresented: $showEditSheet) {
            VehicleEditSheet(vehicle: vehicle) { updatedVehicle in
                observer.vehicle.plate = updatedVehicle.plate
                if !updatedVehicle.name.isEmpty { observer.vehicle.name = updatedVehicle.name }
            }
        }
        .sheet(isPresented: $showBlockageModal) {
            BlockageSheet(
                vehicle: vehicle,
                isLoading: $blockageLoading,
                errorMessage: $blockageError,
                successMessage: $blockageSuccess
            )
        }
        .sheet(isPresented: $showDriverAssign) {
            VehicleDriverAssignSheet(
                vehicleId: vehicle.deviceId,
                currentDriverName: fifthDriverName == "Sürücü Atanmamış" ? "" : fifthDriverName,
                onAssigned: {
                    observer.fetchDriverInfo()
                }
            )
        }
        .onAppear {
            mapCameraPosition = .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: vehicle.lat, longitude: vehicle.lng),
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
            )
            loadFifthData()
        }
    }

    private var fifthMapSection: some View {
        ZStack(alignment: .bottom) {
            Map(position: $mapCameraPosition, interactionModes: .all) {
                Annotation(vehicle.plate, coordinate: CLLocationCoordinate2D(latitude: vehicle.lat, longitude: vehicle.lng)) {
                    VStack(spacing: 0) {
                        ZStack {
                            Circle()
                                .fill(fifthMapPinColor)
                                .frame(width: 38, height: 38)
                                .shadow(color: fifthMapPinColor.opacity(0.35), radius: 8, y: 3)

                            Circle()
                                .strokeBorder(Color.white, lineWidth: 2.5)
                                .frame(width: 38, height: 38)

                            if vehicle.isMotorcycle {
                                Image(systemName: "bicycle")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                                    .rotationEffect(.degrees(vehicle.direction))
                            } else {
                                DirectionArrow()
                                    .fill(.white)
                                    .frame(width: 18, height: 22)
                                    .rotationEffect(.degrees(vehicle.direction))
                            }
                        }
                        Image(systemName: "triangle.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(fifthMapPinColor)
                            .rotationEffect(.degrees(180))
                            .offset(y: -3)
                    }
                }
            }
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 0, style: .continuous))
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(fifthVehicleName)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white)
                    if !vehicle.address.isEmpty || !vehicle.city.isEmpty {
                        Text(fifthLocationText)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(2)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [.black.opacity(0.45), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }

            fifthFloatingSummary
                .offset(y: 44)
        }
        .padding(.bottom, 42)
    }

    private var fifthFloatingSummary: some View {
        HStack(spacing: 0) {
            fifthSpeedMetric

            Divider()
                .frame(height: 48)

            fifthEllipseMetric(
                icon: "gauge.with.needle",
                title: "Odometer",
                value: vehicle.formattedTotalKm + " km",
                accent: brandGreen
            )

            Divider()
                .frame(height: 48)

            fifthEllipseMetric(
                icon: "road.lanes",
                title: "Bugün KM",
                value: vehicle.formattedTodayKm,
                accent: brandOrange
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(.white.opacity(isDark ? 0.16 : 0.55), lineWidth: 1)
        )
        .shadow(color: .black.opacity(isDark ? 0.25 : 0.10), radius: 16, x: 0, y: 10)
        .padding(.horizontal, 16)
    }

    private var fifthSpeedMetric: some View {
        VStack(spacing: 6) {
            Image(systemName: "speedometer")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(brandBlue)
            Text("Anlık Hız")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(secondaryText)
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(fifthSpeedValue)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if !fifthSpeedUnit.isEmpty {
                    Text(fifthSpeedUnit)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(secondaryText)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private func fifthEllipseMetric(icon: String, title: String, value: String, accent: Color, rounded: Bool = false) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(accent)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(secondaryText)
            Text(value)
                .font(.system(size: rounded ? 32 : 17, weight: rounded ? .bold : .medium, design: rounded ? .rounded : .default))
                .foregroundStyle(primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private var fifthActionsRow: some View {
        HStack(spacing: 10) {
            fifthActionButton(title: "Yol Tarifi", icon: "location.fill", tint: brandBlue) {
                openMapsDirections(lat: vehicle.lat, lng: vehicle.lng, label: vehicle.plate)
            }
            fifthActionButton(title: "Rota", icon: "point.topleft.down.curvedto.point.bottomright.up", tint: brandGreen) {
                onNavigateToRouteHistory?(vehicle)
            }
            fifthActionButton(title: "Blokaj", icon: "lock.fill", tint: brandRed) {
                blockageError = nil
                blockageSuccess = nil
                showBlockageModal = true
            }
            fifthActionButton(title: "Alarmlar", icon: "bell.fill", tint: brandOrange) {
                onNavigateToAlarms?(vehicle.plate)
            }
        }
    }

    private func fifthActionButton(title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 48, height: 48)
                    .background(elevatedSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(stroke, lineWidth: 1)
                    )
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(primaryText)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var fifthSensorRow: some View {
        HStack(spacing: 12) {
            if let temperature = vehicle.temperatureC {
                fifthSensorCard(
                    title: "Sıcaklık",
                    value: String(format: "%.1f°C", temperature),
                    icon: "thermometer.medium",
                    tint: brandOrange
                )
            }

            if let humidity = vehicle.humidityPct {
                fifthSensorCard(
                    title: "Nem",
                    value: "%\(Int(humidity))",
                    icon: "humidity.fill",
                    tint: brandBlue
                )
            }
        }
    }

    private func fifthSensorCard(title: String, value: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(secondaryText)
                Text(value)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(primaryText)
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(elevatedSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(stroke, lineWidth: 1)
        )
    }

    private var fifthDetailsGrid: some View {
        VStack(spacing: 12) {
            fifthInfoCard(title: "Operasyon Özeti", icon: "square.grid.2x2") {
                fifthMetaInfoRow(label: "Son Bilgi", value: vehicle.formattedLastPacketAtFull)
                fifthInfoRow(label: "Konum", value: fifthLocationText, multiline: true)
                fifthInfoRow(label: "Kontak", value: vehicle.kontakLabel, valueColor: vehicle.kontakOn ? brandGreen : brandRed)
                fifthInfoRow(label: "Yakıt Tipi", value: vehicle.fuelType.isEmpty ? "Tanımsız" : vehicle.fuelType)
                fifthInfoRow(label: "Tüketim", value: fifthConsumptionText, drawsDivider: false)
            }

            fifthInfoCard(title: "Enerji ve Kullanım", icon: "bolt.car") {
                fifthInfoRow(label: "Harici Voltaj", value: fifthVoltage(vehicle.externalVoltage))
                fifthInfoRow(label: "Cihaz Bataryası", value: fifthDeviceBatteryText)
                fifthInfoRow(label: "Bugün Yakıt", value: vehicle.formattedDailyFuelLiters)
                fifthInfoRow(label: "Bugün Maliyet", value: vehicle.formattedDailyFuelCost, drawsDivider: false)
            }

            fifthInfoCard(title: "Sürücü ve Kayıtlar", icon: "person.text.rectangle") {
                fifthDriverBlock
                Divider().padding(.vertical, 8)
                fifthRecordSummaryRow(
                    title: "Bakım ve Masraf",
                    summary: fifthCombinedRecordSummaryText,
                    accent: fifthCombinedRecordSummary?.accent ?? brandBlue
                )
                Divider().padding(.vertical, 8)
                fifthRecordSummaryRow(title: "Olaylar", summary: fifthAlarmSummaryText, accent: brandRed) {
                    onNavigateToAlarms?(vehicle.plate)
                }
            }

            fifthInfoCard(title: "Teknik Zaman Bilgileri", icon: "clock.badge") {
                fifthCompactInfoRow(label: "Son Veri", value: vehicle.formattedLastPacketAtFull)
                if shouldShowFirstIgnitionRow {
                    fifthCompactInfoRow(label: "İlk Kontak", value: vehicle.formattedFirstIgnitionTodayFull)
                }
                fifthCompactInfoRow(label: "Son Kontak Açılma", value: vehicle.formattedLastIgnitionOnFull)
                fifthCompactInfoRow(label: "Kontak Kapanma", value: vehicle.formattedLastIgnitionOffFull, drawsDivider: false)
            }
        }
    }

    private func fifthInfoCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(brandBlue)
                    .frame(width: 30, height: 30)
                    .background(brandBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(primaryText)
            }

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(elevatedSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(stroke, lineWidth: 1)
        )
    }

    private func fifthInfoRow(label: String, value: String, valueColor: Color? = nil, multiline: Bool = false, drawsDivider: Bool = true) -> some View {
        VStack(spacing: 8) {
            if multiline {
                VStack(alignment: .leading, spacing: 6) {
                    Text(label)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(secondaryText)
                    Text(value)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(valueColor ?? primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                HStack(spacing: 10) {
                    Text(label)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(secondaryText)
                    Spacer(minLength: 8)
                    Text(value)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(valueColor ?? primaryText)
                        .multilineTextAlignment(.trailing)
                }
            }

            if drawsDivider {
                Divider()
            }
        }
    }

    private func fifthCompactInfoRow(label: String, value: String, drawsDivider: Bool = true) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(secondaryText)
                Spacer(minLength: 8)
                Text(value)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(secondaryText)
                    .multilineTextAlignment(.trailing)
            }

            if drawsDivider {
                Divider()
            }
        }
    }

    private func fifthMetaInfoRow(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "clock")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(secondaryText)
            Text(label + ":")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(secondaryText)
            Text(value)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
        .padding(.bottom, 2)
    }

    private var fifthDriverBlock: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(brandBlue.opacity(0.14))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(fifthDriverName.prefix(1)))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(brandBlue)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(fifthDriverName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(primaryText)
                    .lineLimit(2)
                Text(observer.driverPhone.isEmpty ? "Telefon bilgisi yok" : observer.driverPhone)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(secondaryText)
            }

            Spacer()

            Button("Değiştir") {
                showDriverAssign = true
            }
            .buttonStyle(.bordered)
            .tint(brandBlue)
            .font(.system(size: 14, weight: .semibold))
        }
    }

    @ViewBuilder
    private func fifthRecordSummaryRow(
        title: String,
        summary: String,
        accent: Color,
        action: (() -> Void)? = nil
    ) -> some View {
        let row = HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(accent.opacity(0.12))
                .frame(width: 36, height: 36)
                .overlay(
                    Circle()
                        .fill(accent)
                        .frame(width: 8, height: 8)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(secondaryText)
                Text(summary)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if action != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(secondaryText.opacity(0.7))
                    .padding(.top, 2)
            }
        }

        if let action {
            Button(action: action) {
                row
            }
            .buttonStyle(.plain)
        } else {
            row
        }
    }

    private var fifthCombinedRecordSummaryText: String {
        if let summary = fifthCombinedRecordSummary {
            return summary.summary
        }
        if isLoadingMaintenance || isLoadingCosts {
            return "Kayıt verileri yükleniyor"
        }
        return "Kayıt bulunmuyor"
    }

    private var fifthAlarmSummaryText: String {
        if isLoadingEvents { return "Olay verileri yükleniyor" }
        if let alarm = alarms.first { return "\(alarm.typeLabel) • \(alarm.formattedDate)" }
        return "Olay kaydı bulunmuyor"
    }

    private var fifthVehicleName: String {
        if !vehicle.vehicleBrand.isEmpty || !vehicle.vehicleModel.isEmpty {
            return [vehicle.vehicleBrand, vehicle.vehicleModel].filter { !$0.isEmpty }.joined(separator: " ")
        }
        return vehicle.model
    }

    private var fifthLocationText: String {
        if !vehicle.address.isEmpty { return vehicle.address }
        if !vehicle.city.isEmpty { return vehicle.city }
        return "Konum bilgisi bekleniyor"
    }

    private var fifthDriverName: String {
        let name = !observer.driverName.isEmpty ? observer.driverName : (!vehicle.driverName.isEmpty ? vehicle.driverName : vehicle.driver)
        return name.isEmpty ? "Sürücü Atanmamış" : name
    }

    private var fifthConsumptionText: String {
        let rate = vehicle.dailyFuelPer100km > 0 ? vehicle.dailyFuelPer100km : vehicle.fuelPer100km
        return rate > 0 ? String(format: "%.1f L/100km", rate) : "—"
    }

    private var fifthDeviceBatteryText: String {
        guard let pct = vehicle.deviceBattery, pct >= 0 else { return "—" }
        let normalized = min(max(pct, 0), 100)
        return "%\(Int(normalized.rounded()))"
    }

    private var fifthCombinedRecordSummary: FifthCombinedRecordSummary? {
        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: now)

        let maintenanceCandidates = fleetMaintenances.compactMap { item -> FifthCombinedRecordSummary? in
            let raw = item.nextServiceDate ?? item.serviceDate
            guard let raw, let date = parseFleetDate(raw) else { return nil }
            let isFuture = date >= startOfToday
            return FifthCombinedRecordSummary(
                summary: "Bakım • \(item.title) • \(formattedFleetDate(date))",
                accent: brandBlue,
                date: date,
                isFuture: isFuture,
                priority: 0
            )
        }

        let costCandidates = fleetCosts.compactMap { item -> FifthCombinedRecordSummary? in
            guard let date = parseFleetDate(item.costDate) else { return nil }
            let isFuture = date >= startOfToday
            return FifthCombinedRecordSummary(
                summary: "Masraf • \(item.category.capitalized) • \(formattedFleetDate(date))",
                accent: brandOrange,
                date: date,
                isFuture: isFuture,
                priority: 1
            )
        }

        let candidates = maintenanceCandidates + costCandidates
        return candidates.min { lhs, rhs in
            let lhsDistance = abs(lhs.date.timeIntervalSince(now))
            let rhsDistance = abs(rhs.date.timeIntervalSince(now))
            if abs(lhsDistance - rhsDistance) >= 1 {
                return lhsDistance < rhsDistance
            }
            if lhs.isFuture != rhs.isFuture {
                return lhs.isFuture && !rhs.isFuture
            }
            if lhs.priority != rhs.priority {
                return lhs.priority < rhs.priority
            }
            return lhs.date < rhs.date
        }
    }

    private var shouldShowFirstIgnitionRow: Bool {
        guard let firstRaw = vehicle.firstIgnitionOnAtToday, !firstRaw.isEmpty else { return false }
        guard let lastRaw = vehicle.lastIgnitionOnAt, !lastRaw.isEmpty else { return true }

        if let firstDate = vehicle.parseTimestamp(firstRaw),
           let lastDate = vehicle.parseTimestamp(lastRaw) {
            return abs(firstDate.timeIntervalSince(lastDate)) >= 60
        }

        return vehicle.formattedFirstIgnitionTodayFull != vehicle.formattedLastIgnitionOnFull
    }

    private var fifthSpeedComponents: (value: String, unit: String) {
        let text = vehicle.formattedSpeed.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = text.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        if parts.count == 2 {
            return (String(parts[0]), String(parts[1]))
        }
        return (text, "")
    }

    private var fifthSpeedValue: String { fifthSpeedComponents.value }
    private var fifthSpeedUnit: String { fifthSpeedComponents.unit }

    private var fifthMapPinColor: Color {
        if vehicle.status == .noData || !vehicle.isOnline {
            return brandBlack
        }
        if vehicle.speed > 0 {
            return brandGreen
        }
        if vehicle.ignition || vehicle.status == .sleeping {
            return brandOrange
        }
        return brandRed
    }

    private func fifthVoltage(_ value: Double?) -> String {
        guard let value, value > 0 else { return "—" }
        return String(format: "%.2f V", value)
    }

    private func parseFleetDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        if let parsed = vehicle.parseTimestamp(raw) {
            return parsed
        }

        let dateOnly = DateFormatter()
        dateOnly.locale = Locale(identifier: "tr_TR")
        dateOnly.timeZone = TimeZone(identifier: "Europe/Istanbul")
        dateOnly.dateFormat = "yyyy-MM-dd"
        if let parsed = dateOnly.date(from: raw) {
            return parsed
        }

        dateOnly.dateFormat = "dd.MM.yyyy"
        return dateOnly.date(from: raw)
    }

    private func formattedFleetDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.timeZone = TimeZone(identifier: "Europe/Istanbul")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }

    private func loadFifthData() {
        if !isLoadingMaintenance && fleetMaintenances.isEmpty {
            isLoadingMaintenance = true
            Task {
                do {
                    let (maintenances, _) = try await APIService.shared.fetchFleetMaintenance(imei: vehicle.imei)
                    await MainActor.run {
                        fleetMaintenances = maintenances
                        isLoadingMaintenance = false
                    }
                } catch {
                    await MainActor.run {
                        isLoadingMaintenance = false
                    }
                }
            }
        }

        if !isLoadingCosts && fleetCosts.isEmpty {
            isLoadingCosts = true
            Task {
                do {
                    let (costs, _) = try await APIService.shared.fetchFleetCosts(imei: vehicle.imei)
                    await MainActor.run {
                        fleetCosts = costs
                        isLoadingCosts = false
                    }
                } catch {
                    await MainActor.run {
                        isLoadingCosts = false
                    }
                }
            }
        }

        if !isLoadingEvents && alarms.isEmpty {
            isLoadingEvents = true
            Task {
                do {
                    let json = try await APIService.shared.get("/api/mobile/alarms?page=1&per_page=20&imei=\(vehicle.imei)")
                    let dataArr = json["data"] as? [[String: Any]] ?? []
                    let results = dataArr.enumerated().compactMap { index, dict -> AlarmEvent? in
                        let alarm = AlarmEvent.from(json: dict, index: index)
                        guard alarm.imei == vehicle.imei || alarm.plate == vehicle.plate else { return nil }
                        return alarm
                    }
                    await MainActor.run {
                        alarms = Array(results.prefix(10))
                        isLoadingEvents = false
                    }
                } catch {
                    await MainActor.run {
                        isLoadingEvents = false
                    }
                }
            }
        }
    }

    private func openMapsDirections(lat: Double, lng: Double, label: String) {
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = label
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}

#Preview {
    VehicleDetailView(vehicle: Vehicle(
        id: "1", plate: "34 ABC 123", model: "Ford Transit",
        status: .ignitionOn, kontakOn: true, totalKm: 48320, todayKm: 312,
        driver: "Ahmet Yılmaz", city: "İstanbul", lat: 41.0082, lng: 28.9784
    ))
}
